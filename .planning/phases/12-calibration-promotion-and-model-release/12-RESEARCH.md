# Phase 12: Calibration, Promotion, and Model Release - Research

**Researched:** 2026-08-10
**Domain:** Leakage-safe 1X2 calibration, sealed holdout governance, model promotion, and release contracts in an R/targets football benchmark
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

Source: `.planning/phases/12-calibration-promotion-and-model-release/12-CONTEXT.md` [VERIFIED: user-provided locked context]

### Locked Decisions

### Calibration

- **D-01:** Calibrate derived 1X2 probabilities first. Preserve the fitted goal distribution and derive the calibrated match-outcome probabilities from it; do not introduce full score-distribution calibration in this phase.
- **D-02:** Fit calibration separately for every candidate and track, using that model's own inner out-of-fold predictions.
- **D-03:** Use expanding prior-tournament inner-OOF history, preserving chronology and preventing future-tournament leakage.
- **D-04:** Use calibrated output as primary only when it improves calibration and triggers none of the frozen RPS, Brier, log-loss, fold-stability, or coverage vetoes. Otherwise retain raw output as primary.

### Candidate Freeze

- **D-05:** Freeze all nine registered Phase 11 candidates, including inactive xG/context/structural candidates. Inactive candidates must remain explicit no-score rows rather than disappearing from the registry.
- **D-06:** Freeze candidate code, features, settings, panels, seeds, calibration recipes, and promotion thresholds before fitting any calibration recipe.
- **D-07:** No candidate activation or specification change is allowed after the freeze. New evidence or a new candidate requires a new reviewed benchmark phase.
- **D-08:** One aggregate Phase 12 freeze manifest is authoritative. It must identify the candidate registry, code commit, feature/settings/panel/seed/calibration/threshold hashes, and parent-graph identities.

### One-Shot Holdout Gate

- **D-09:** Any preflight failure aborts before WC2026 labels are opened. Repair requires a new reviewed freeze and rerun.
- **D-10:** Once opened, WC2026 labels are copied into an immutable final-evaluation artifact used only by scoring and reporting. They never enter fitting, calibration, or selection.
- **D-11:** Run every frozen candidate that passes its admissibility gate; retain inactive candidates as explicit no-score rows in the final registry and report.
- **D-12:** Publish an append-only final-evaluation manifest linking the freeze hash, label hash, run timestamp, candidate/prediction/score hashes, coverage, and promotion decision.

### Release Fallback

- **D-13:** If no challenger clears every promotion gate, use the incumbent version that passes the same raw-versus-calibrated development gate. Publish alternatives as audit-only.
- **D-14:** Publish a versioned complete release bundle containing the approved model object, model contract, freeze and final-evaluation manifests, benchmark report, model card, provenance, limitations, and reproducibility metadata.
- **D-15:** Dashboard and export consumers may load a model only through the approved release manifest and model contract. They must fail closed on missing or mismatched hashes.
- **D-16:** A no-promotion outcome must publish a versioned release explicitly stating `incumbent retained`, together with challenger results and gate failures. The release contract remains usable.

### Existing Protocol Constraints

The Phase 9 promotion protocol remains authoritative. The core challenger gate is challenger-minus-incumbent RPS <= -0.003 with a confidence-interval upper bound below zero, at least 8 of 12 improving folds, at least 2 World Cup and 2 Euro wins, and maximum fold regression <= 0.015. Supporting Brier/log-loss and calibration-change vetoes, plus probability, distribution, fixture, coverage, provenance, license, seed, checksum, reproducibility, code, feature, settings, panel, and `wc2026` sealing vetoes remain in force. Phase 12 plans must implement these existing values rather than restate or alter them.

### the agent's Discretion

No `the agent's Discretion` section is present in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)

None. Discussion stayed within the Phase 12 boundary.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAL-01 | The analyst can train probability calibration using inner out-of-fold predictions without using the outer assessment tournament. | Add a candidate/track-specific expanding inner-OOF service and chronology manifest; reuse Phase 9 cutoff and holdout guards. |
| CAL-02 | The benchmark compares raw and calibrated probabilities with the same proper scores and reports any discrimination or calibration regression. | Preserve raw and calibrated 1X2 columns, score both through `score_benchmark_fixtures()`, aggregate with the existing equal-tournament services, and persist veto evidence. |
| PROMO-01 | Candidate models, settings, feature sets, and promotion thresholds are frozen before the final 2026 World Cup evaluation is opened. | Build one aggregate freeze manifest over the nine Phase 11 rows and all parent hashes; preflight it before any label-bearing read. |
| PROMO-02 | The analyst can execute the final 2026 comparison once and retain the incumbent unless a challenger satisfies the promotion rule. | Add a fail-closed one-shot evaluation boundary, append-only final manifest, and Phase 9 evaluator-backed decision path. |
| PROMO-03 | The approved model is published as a versioned artifact with a model card, benchmark report, and dashboard regression tests. | Package model/calibrator/contract/manifests/reports as one release and replace raw dashboard model-path selection with approved-manifest resolution. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Use R as the implementation language and `targets` as the orchestration boundary; preserve the existing project-local package/runtime approach. [VERIFIED: AGENTS.md]
- Keep xG and Elo separated until the Integration Layer; Phase 12 must consume the established feature/benchmark contracts rather than recomputing cross-layer features in release code. [VERIFIED: AGENTS.md]
- Preserve deterministic execution with explicit `set.seed()` usage, reproducible artifacts, and the project’s `testthat::test_dir("tests/testthat")` validation convention. [VERIFIED: AGENTS.md]
- Do not automate restricted FotMob access or introduce network-dependent execution; use committed/manual caches and local artifacts. [VERIFIED: AGENTS.md]
- Commit planning artifacts, verify plans before execution, run tests frequently, and avoid changing unrelated production files. [VERIFIED: AGENTS.md; user scope]

## Summary

Phase 12 should be implemented as a new, downstream release-governance layer over the accepted Phase 9 benchmark and the Phase 11 research bundle, not as a modification of the Phase 11 runner. Phase 11 has exactly nine registered candidates; local artifact inspection found one active scored candidate and eight explicit inactive/no-score candidates. Its run manifest is reproducible, WC2026-sealed, network-free, research-only, and explicitly sets `phase12_decision_authority = FALSE`. [VERIFIED: codebase grep and local artifact audit]

The strongest reusable seams already exist: `R/evaluation/benchmark_scores.R` validates shared 1X2 and G=40 score contracts, computes RPS/Brier/log loss and fixed-bin calibration, and performs equal-tournament aggregation; `R/evaluation/promotion.R` is the sole frozen Phase 9 gate evaluator; and the Phase 9/10/11 runners already publish parent graphs, checksums, exact 630/609 panel evidence, and fail-closed holdout guards. [VERIFIED: codebase grep; `09-VERIFICATION.md`; current focused tests]

The missing work is substantial but bounded: an inner-OOF calibration artifact and calibrator object per candidate/track, a single pre-label freeze manifest, a one-shot WC2026 label-opening and immutable evaluation artifact, a final decision report that routes through `evaluate_promotion()`, a release bundle containing a contract and model object, and consumer adapters that refuse raw model paths. The existing dashboard still chooses baseline versus hybrid from file existence in `_targets.R` and reads `.rds` model paths directly, so PROMO-03 cannot be satisfied without a new approved-manifest resolution seam. [VERIFIED: codebase grep]

**Primary recommendation:** Preserve the existing score/distribution/promotion contracts, add a Phase 12 file-oriented chain with explicit `preflight -> freeze -> inner-OOF calibration -> development raw/calibrated gate -> final label opening -> final evaluation -> promotion -> release`, and make every consumer resolve and hash-validate the resulting release contract.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Candidate/track inner-OOF calibration | API / Backend | Database / Storage | Calibration is benchmark business logic over prior tournament predictions; durable OOF rows and calibrator objects must be persisted for audit. [VERIFIED: locked context; existing benchmark architecture] |
| Raw-versus-calibrated scoring and vetoes | API / Backend | Database / Storage | The shared scorer and Phase 9 promotion evaluator own proper-score and gate semantics; persisted CSV views remain the durable authority. [VERIFIED: `R/evaluation/benchmark_scores.R`; `R/evaluation/promotion.R`] |
| Candidate freeze and checksum graph | Database / Storage | API / Backend | The manifest is the authoritative immutable identity of code, registries, panels, seeds, recipes, thresholds, and parents. [VERIFIED: locked context; Phase 9 checksum patterns] |
| WC2026 one-shot evaluation | API / Backend | Database / Storage | A guarded evaluation service may open labels only after validated preflight, then writes immutable labels/predictions/scores and an append-only manifest. [VERIFIED: `R/benchmark/cutoffs.R`; locked context] |
| Promotion decision | API / Backend | Database / Storage | `evaluate_promotion()` must remain the single policy authority, with durable gate values, booleans, and ordered reasons. [VERIFIED: `R/evaluation/promotion.R`] |
| Release model and contract | Database / Storage | API / Backend | The model, calibrator, contract, manifests, reports, and hashes form one versioned release identity. [VERIFIED: locked context; existing bundle publication patterns] |
| Dashboard/export model loading | Frontend Server / SSR | Database / Storage | Existing presentation code loads raw paths; Phase 12 must put manifest validation between presentation and model artifacts. [VERIFIED: `_targets.R`; `R/visualization/worldcup_dashboard.R`] |

## Standard Stack

Phase 12 does not need a new package. Use the project’s existing R runtime and local libraries; adding a calibration package would create an unnecessary dependency and would require a new legitimacy review. [VERIFIED: package/environment audit]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R | 4.6.1 | Pipeline, fitting, serialization, and deterministic validation | Current project runtime; existing scripts and tests are R-native. [VERIFIED: installed R environment] |
| `targets` | 1.12.0 | File-oriented orchestration and dependency tracking | Already owns `_targets.R`; official docs define `tar_target(format = "file")` for durable file artifacts and target dependency tracking. [VERIFIED: installed R environment; [CITED: https://docs.ropensci.org/targets/reference/tar_target.html]] |
| `digest` | 0.6.39 | SHA-256 file/content/table hashes | Existing Phase 9–11 checksum implementation and current runtime dependency. [VERIFIED: installed R environment; codebase grep] |
| `jsonlite` | 2.0.0 | Canonical JSON protocol/contract serialization | Already loaded by the project for dashboard and protocol artifacts. [VERIFIED: installed R environment; codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `testthat` | 3.3.2 | Unit, contract, and integration regression tests | Use for every new Phase 12 service and consumer boundary. [VERIFIED: installed R environment] |
| `ranger` | 0.18.0 | Rehydrate/final-fit the active Phase 11 RF candidate when it is the approved model | Use only through the already verified project-local Phase 11 library and registry provenance; do not install a new RF package. [VERIFIED: installed project-local Phase 11 library; Phase 11 manifest] |
| Base R `stats::optim` and `saveRDS` | R 4.6.1 | Recommended low-parameter calibrator fitting and durable calibrator serialization | Avoids introducing a new calibration dependency; exact recipe must be frozen before calibration starts. [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| A new calibration package | Base R low-parameter multiclass logit/temperature calibrator | Keeps the release environment unchanged, but the exact parameterization and minimum-history rule must be locked and tested before freeze. [ASSUMED] |
| A separate score/calibration contract | `benchmark_score_*`, `fixed_benchmark_calibration()`, and `aggregate_benchmark_scores()` | Reuse preserves the Phase 9 denominators and veto semantics; duplicating them risks metric drift. [VERIFIED: codebase grep] |
| Latest model path or file mtime | Approved release manifest plus model contract | Manifest resolution is auditable and fail-closed; path discovery is explicitly forbidden by D-15. [VERIFIED: locked context; current `_targets.R`] |

**Installation:** None. Do not modify the environment or install packages for this phase. [VERIFIED: project/environment audit]

## Package Legitimacy Audit

No external package installation is proposed for Phase 12. Existing `targets`, `digest`, `jsonlite`, `testthat`, and project-local `ranger` are already present and are not new recommendations. [VERIFIED: installed environment and project files]

## Architecture Patterns

### System Architecture Diagram

The following is the recommended Phase 12 data flow; the label-opening edge is the only allowed path to WC2026 outcomes. [VERIFIED: locked context; existing Phase 9/11 boundaries]

```text
Phase 9 protocol + Phase 10 bundle + Phase 11 nine-candidate bundle
                         |
                         v
                 [preflight / admissibility]
                         |
                  pass? -- no --> stop; labels unopened
                         |
                         v
             [freeze manifest + parent/checksum graph]
                         |
                         v
        [candidate/track inner-OOF calibration, prior tournaments only]
                         |
                         v
       [development raw-vs-calibrated gate for every candidate/track]
                         |
                         v
        [final pre-label gate: freeze + calibration + contracts]
                         |
                  pass? -- no --> stop; labels unopened
                         |
                         v
             [open WC2026 labels exactly once]
                         |
                         v
      [immutable labels -> final predictions -> shared scorer]
                         |
                         v
             [Phase 9 evaluate_promotion() once]
                         |
                         v
     challenger clears every gate? -- no --> incumbent retained
                         |
                         v
       [versioned release bundle + approved model contract]
                         |
                         v
           [dashboard/export manifest-only consumers]
```

### Recommended Project Structure

```text
R/
├── calibration/
│   ├── inner_oof.R                 # chronological inner-OOF assembly
│   ├── probability_calibration.R   # fit/apply/validate 1X2 calibrators
│   └── calibration_selection.R     # raw-vs-calibrated development gate
├── release/
│   ├── freeze_manifest.R            # pre-label freeze and parent graph
│   ├── final_evaluation.R           # one-shot label gate and immutable copy
│   ├── release_contract.R           # resolve/validate approved model contract
│   └── release_bundle.R             # stage, validate, atomically publish
└── evaluation/
    └── benchmark_scores.R           # existing shared scorer; extend, do not fork

data/benchmark/phase12/
├── calibration_recipe.json
├── freeze_manifest.csv
├── final_evaluation_manifest.csv
└── model_contract_schema.json

outputs/benchmarks/rolling_tournaments/phase12-calibration-release/
├── calibration/
├── final_evaluation/
├── reports/
└── manifests/

outputs/releases/<release_id>/
├── release_manifest.csv
├── model_contract.json
├── model/
├── reports/
└── manifests/
```

The exact paths are a recommended layout, not an existing contract; lock them in the freeze manifest before implementation. [ASSUMED]

### Pattern 1: Candidate/Track Chronology-Safe Calibration

For outer tournament `T`, assemble only inner OOF rows from completed tournaments strictly earlier than `T`. Each inner row must carry the candidate ID, track ID, inner edition, fixture/boundary identity, evidence cutoff, raw derived 1X2 vector, observed class, source run/hash, and the outer edition to which the calibrator is being applied. The calibrator must never see the outer assessment tournament or WC2026 labels. [VERIFIED: locked D-02/D-03; existing strict cutoff contracts]

Recommended artifact shape:

```r
inner_oof <- data.frame(
  candidate_id = character(), track_id = character(),
  outer_edition_id = character(), inner_edition_id = character(),
  fixture_id = character(), evidence_cutoff_exclusive = as.Date(character()),
  p_home_raw = numeric(), p_draw_raw = numeric(), p_away_raw = numeric(),
  observed_class = character(), source_prediction_sha256 = character(),
  stringsAsFactors = FALSE
)

# Before fitting outer_edition_id, filter inner_edition_id to prior editions only.
# Then validate every source cutoff and call guard_benchmark_purpose(..., "calibration").
```

The exact calibrator recipe is not locked in CONTEXT.md. The recommended default is a low-parameter multiclass logit calibrator implemented with base R: class intercepts plus one temperature/sharpness parameter, fit by deterministic log loss on the inner OOF rows, with stable log-probability handling and simplex validation. Use raw output when the registered minimum-history/class-support rule is not met. [ASSUMED]

Persist both the calibrator object and a CSV manifest containing `candidate_id`, `track_id`, `outer_edition_id`, `inner_edition_ids`, row count, class counts, recipe hash, seed, fit status, source prediction hash, and maximum inner evidence date. [VERIFIED: Phase 9/11 manifest conventions; recommended contract]

### Pattern 2: Keep Raw, Calibrated, and Distribution Views Separate

The fitted G=40 joint score distribution remains unchanged. Preserve `p_home_raw`, `p_draw_raw`, and `p_away_raw`; add calibrated 1X2 fields and an explicit `primary_probability_view`. Score raw and calibrated vectors against the same fixture IDs and actual outcomes through the shared proper-score functions. Do not overwrite raw probabilities or silently regenerate the scoreline grid. [VERIFIED: locked D-01/D-04; `R/evaluation/proper_scores.R`; `R/evaluation/benchmark_scores.R`]

This creates a deliberate view distinction: the approved contract must state whether presentation-level 1X2 probabilities use the selected calibrated vector while scoreline/tournament simulation continues to use the unchanged joint distribution. That separation follows D-01 but the consumer behavior itself must be frozen and tested. [ASSUMED]

### Pattern 3: Single Aggregate Freeze Manifest

Build one authoritative manifest after all preflight checks and before any calibrator fit. It should include the normalized Phase 11 registry hash, all nine candidate registration/settings hashes, Phase 9/10/11 parent bundle hashes, code commit and clean-worktree status, feature/panel/seed hashes, calibration recipe hash, promotion protocol hash, selected G=40, `wc2026` seal status, R/package versions, and a self-hash. [VERIFIED: locked D-06/D-08; Phase 9/10/11 manifests]

The manifest is a gate input, not merely a report. Every downstream target must validate its hash and reject candidate/order/feature/setting changes. A changed calibrator recipe, inactive status, or panel must require a new freeze. [VERIFIED: locked D-07/D-09; existing fail-closed manifest validators]

### Pattern 4: Preflight, Then One-Shot Final Evaluation

The final evaluation target must be structurally downstream of the freeze and development calibration gate. It should validate the freeze, verify all admissibility rows, verify no WC2026 labels have been opened, and only then call a single label-opening function. That function copies labels into a new immutable artifact, records the label hash and timestamp, and exposes the copied data only to scoring/reporting code. [VERIFIED: locked D-09/D-12; `R/benchmark/cutoffs.R`]

Do not rely on `targets` up-to-date state as the one-shot guarantee. Official `targets` documentation describes target invalidation and file tracking, but a rerun can still be requested; the application-level append-only manifest and consumed-label hash must reject a second open or any mismatch. [CITED: https://docs.ropensci.org/targets/reference/tar_target.html; VERIFIED: locked D-09/D-10]

### Pattern 5: Stage and Atomically Install a Complete Release

Stage the entire release in a unique temporary directory, validate every file and hash from a fresh R process, then install it atomically while preserving the prior accepted release until post-install validation succeeds. This mirrors the existing Phase 9/11 staged bundle and rollback pattern. [VERIFIED: `R/benchmark/runner.R`; `R/benchmark/hybrid_runner.R`]

The release manifest must explicitly encode either `challenger approved` or exactly `incumbent retained`; no eligible challenger is not an error. Alternatives and failed gates remain audit-only rows. [VERIFIED: locked D-13/D-16]

### Pattern 6: Manifest-Only Consumer Resolution

Add one resolver used by dashboard and exports. It must locate the approved release manifest from a configured trusted root, validate release status, model contract schema, required artifact paths, every declared SHA-256, G=40, feature/panel/settings hashes, and the approved model ID, then load the referenced model/calibrator objects. Missing, stale, mismatched, or non-approved manifests must `stop()` before any forecast is generated. [VERIFIED: locked D-15; existing `stop()`-style validators]

The current dashboard’s `hybrid_available` logic and default `.rds` paths are the closest consumer analog, but they are not safe for Phase 12 because file existence selects the model and no release-manifest hash is checked. [VERIFIED: `_targets.R` lines 449–478; `R/visualization/worldcup_dashboard.R` lines 2977–3025]

### Anti-Patterns to Avoid

- **Calibrating on outer-fold or WC2026 rows:** This leaks assessment information into the transformation and invalidates CAL-01. [VERIFIED: locked D-02/D-03/D-10]
- **Dropping inactive Phase 11 candidates:** This changes the frozen candidate set and makes no-score status indistinguishable from omission. [VERIFIED: locked D-05/D-11; Phase 11 artifact audit]
- **Reusing the Phase 11 shortlist as a winner:** The shortlist is explicitly non-exclusive, research-only, and has no Phase 12 decision authority. [VERIFIED: Phase 11 run manifest and shortlist]
- **Calling `evaluate_promotion()` before the final evaluation:** Phase 9 development gates decide admissibility; the final comparison still needs the one-shot holdout evidence and the same frozen protocol. [VERIFIED: `R/evaluation/promotion.R`; locked D-12/D-13]
- **Selecting the latest file or a model based on path existence:** This bypasses D-15 and can silently load an unapproved artifact. [VERIFIED: current `_targets.R`; locked D-15]
- **Mutating an accepted release in place:** A partial write can leave dashboard consumers with an invalid model/contract pair. [VERIFIED: Phase 9 staged-install pattern]
- **Treating a Brier improvement as calibration proof by itself:** Proper scores combine reliability and discrimination; retain explicit calibration-error and fold-stability diagnostics alongside RPS/Brier/log loss. [CITED: https://scikit-learn.org/stable/modules/calibration.html; VERIFIED: existing Phase 9 supporting vetoes]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 1X2 and scoreline scoring | A Phase 12 metric implementation | `score_benchmark_fixtures()`, `aggregate_benchmark_scores()`, `fixed_benchmark_calibration()` | Existing validators enforce exact fixture identity, G=40 distributions, proper scores, and equal-tournament aggregation. [VERIFIED: `R/evaluation/benchmark_scores.R`] |
| Promotion policy | A new threshold table or direct `if` tree | `load_promotion_protocol()`, `validate_promotion_protocol()`, `evaluate_promotion()`, `select_promoted_candidate()` | Phase 9 is the locked policy authority and persists complete gate evidence/reason codes. [VERIFIED: `R/evaluation/promotion.R`] |
| Checksums | A second hash/serialization convention | Existing `digest` SHA-256 and canonical table/file hash helpers | Phase 9–11 parent graphs and self-hashes already depend on stable normalization. [VERIFIED: codebase grep] |
| Holdout protection | A caller convention such as “do not pass labels” | `guard_benchmark_purpose()` plus an application-level one-shot label gate | The existing guard rejects WC2026 outcome columns for development purposes and prevents adapter invocation. [VERIFIED: `R/benchmark/cutoffs.R`; `test_benchmark_seal.R`] |
| Panel membership | Filtering by non-missing prediction rows | `benchmark_panel_fixture_ids()` and exact registered panel checks | Phase 9 separates output coverage from frozen panel membership; silent denominator changes are a known failure mode. [VERIFIED: Phase 9 verification] |
| Release resolution | Consumer-specific model path logic | One approved release-contract resolver | Dashboard/export must have identical fail-closed behavior and hash checks. [VERIFIED: locked D-15]

**Key insight:** The difficult part is not fitting one more probability transform; it is preserving a single auditable identity across calibration, promotion, final labels, model objects, and presentation consumers. Reusing the existing contracts keeps the new release layer small and prevents a second governance path. [VERIFIED: Phase 9–11 architecture; recommendation]

## Common Pitfalls

### Pitfall 1: Inner OOF Rows Are Chronological in Name Only

**What goes wrong:** A calibrator is fit on an outer tournament’s own predictions, or an inner prediction was generated using a feature/result at or after its exclusive cutoff. [VERIFIED: locked D-02/D-03; existing cutoff tests]
**Why it happens:** The Phase 11 durable predictions are already out-of-fold-looking rows, but the calibration layer must preserve the nested outer/inner relationship explicitly. [VERIFIED: Phase 9/10 runner contracts]
**How to avoid:** Persist inner and outer edition IDs, source cutoff dates, source prediction hashes, and a strict `inner_edition < outer_edition` assertion for every fit. Run `guard_benchmark_purpose(..., purpose = "calibration")` before fitting. [VERIFIED: `R/benchmark/cutoffs.R`; recommended contract]
**Warning signs:** The first outer edition receives a fitted calibrator despite no prior tournament, `max_inner_evidence_date` reaches an outer opener, or calibration row counts change when outer rows are removed. [ASSUMED]

### Pitfall 2: Calibrated 1X2 No Longer Matches the Score Distribution

**What goes wrong:** The code overwrites derived markets or edits the G=40 grid to force calibrated 1X2 values, violating D-01 and making scoreline and match-outcome views inconsistent. [VERIFIED: locked D-01; existing distribution contract]
**Why it happens:** Existing APIs naturally derive markets from scoreline distributions, while Phase 12 deliberately calibrates only the derived 1X2 vector. [VERIFIED: `R/evaluation/proper_scores.R`]
**How to avoid:** Keep raw distribution and raw 1X2 immutable; store calibrated 1X2 as a separate view with a primary-view flag and test both views against the same fixtures. [VERIFIED: locked D-01/D-04; recommended contract]
**Warning signs:** `p_home + p_draw + p_away` passes but recalculating 1X2 from the stored grid gives different values without an explicit `probability_view` label. [ASSUMED]

### Pitfall 3: Inactive Candidates Become Missing Rows

**What goes wrong:** Context, xG, or structural candidates disappear because they have no score rows, so the final registry falsely looks like a smaller candidate set. [VERIFIED: Phase 11 candidate evidence and outcome amendment]
**Why it happens:** The current Phase 11 runner emits no predictions/distributions for inactive adapters but separately persists candidate evidence. [VERIFIED: `R/benchmark/hybrid_runner.R`]
**How to avoid:** Carry all nine frozen registry rows into calibration, final evaluation, and release reports; use explicit `active_status`, `score_status`, `no_score_reason`, and zero score/prediction counts. Never fabricate rows or impute unavailable evidence. [VERIFIED: locked D-05/D-11; Phase 11 amendment]
**Warning signs:** Final candidate count is less than nine, inactive rows have numeric metrics, or a missing candidate is absent from the freeze hash. [VERIFIED: locked context; recommended assertions]

### Pitfall 4: Preflight Is Not Actually Before Label Opening

**What goes wrong:** An evaluation target reads a label-bearing file while checking inputs, then later claims the holdout was sealed. [VERIFIED: locked D-09/D-10]
**Why it happens:** File-oriented targets can observe paths and metadata, and the current project contains retrospective WC2026 artifacts; a generic “load all inputs” helper can accidentally cross the boundary. [VERIFIED: current target/file inventory]
**How to avoid:** Keep label-free fixture identities and label-bearing outcomes in separate functions/files; make the one-shot opener the only function allowed to read outcome columns, and test source ordering statically plus runtime with a recording adapter. [VERIFIED: `test_benchmark_seal.R`; recommendation]
**Warning signs:** A preflight helper accepts `regulation_home_goals`, final-evaluation target can run twice, or the final manifest lacks a unique consumed-label hash. [ASSUMED]

### Pitfall 5: Development Promotion and Final Promotion Are Conflated

**What goes wrong:** A candidate with good historical gates is promoted automatically, or WC2026 is used to tune a calibration recipe after labels open. [VERIFIED: locked D-04/D-09/D-10/D-13]
**Why it happens:** Phase 9 already has a promotion evaluator, but Phase 12 adds a final holdout decision and an incumbent fallback. [VERIFIED: existing code and context]
**How to avoid:** Use a distinct development decision (`eligible_for_final_holdout`), then a one-time final decision with the same protocol and a release decision that can be `incumbent retained`. Calibrator fitting and selection must be complete before the one-shot boundary. [VERIFIED: `R/evaluation/promotion.R`; locked context]
**Warning signs:** `evaluate_promotion()` is called from Phase 11 targets, final report contains tuning actions after label read, or “best historical candidate” is copied directly into production. [VERIFIED: Phase 11 target tests; locked context]

### Pitfall 6: Release Artifact Is Complete but Consumer Resolution Is Weak

**What goes wrong:** The release folder contains a model card and hashes, but dashboard code continues to load `models/home_goal_model*.rds` by path. [VERIFIED: current `_targets.R` and dashboard code]
**Why it happens:** Existing presentation tests validate output shape and simulation behavior, not approved-manifest selection. [VERIFIED: current dashboard test scope]
**How to avoid:** Add consumer tests for missing manifest, status `incumbent retained`, mismatched model hash, mismatched contract hash, wrong G, wrong candidate ID, and stale/ambiguous release roots. [VERIFIED: locked D-15; recommended tests]
**Warning signs:** A model can be swapped without changing release metadata, `model_version` is only a free-form string, or exports and dashboard use different resolution code. [ASSUMED]

## Code Examples

Verified existing composition points:

### Shared scoring of raw and calibrated views

```r
# Existing scorer contract: exact predictions, fixtures, distributions, and panel IDs.
# Source: R/evaluation/benchmark_scores.R [VERIFIED: codebase grep]
raw_scores <- score_benchmark_fixtures(
  predictions = raw_predictions,
  fixtures = development_fixtures,
  distributions = score_distributions,
  expected_fixture_ids = expected_fixture_ids
)

calibrated_scores <- score_benchmark_fixtures(
  predictions = calibrated_predictions,
  fixtures = development_fixtures,
  distributions = score_distributions,
  expected_fixture_ids = expected_fixture_ids
)
```

### Reuse the frozen policy evaluator

```r
# Existing Phase 9 authority; do not replace with a Phase 12 threshold fork.
# Source: R/evaluation/promotion.R [VERIFIED: codebase grep]
protocol <- load_promotion_protocol("data/benchmark/phase09/promotion_protocol.json")
validate_promotion_protocol(protocol, registry_dir = "data/benchmark/phase09")
decision <- evaluate_promotion(candidate, protocol)
selected <- select_promoted_candidate(evaluations, incumbent_id = "open_nb_incumbent")
```

### Durable target output

```r
# Existing project pattern: return paths for durable artifacts.
# Source: _targets.R and official targets reference [VERIFIED: codebase grep; [CITED: https://docs.ropensci.org/targets/reference/tar_target.html]]
tar_target(
  phase12_release_files,
  write_phase12_release_bundle(phase12_release_candidate),
  format = "file"
)
```

### Proposed calibration boundary

```r
# Proposed Phase 12 API; exact recipe/minimum-history rule is not yet verified.
fit <- fit_phase12_calibrator(
  candidate_id = candidate_id,
  track_id = track_id,
  outer_edition_id = outer_edition_id,
  inner_oof = inner_oof[inner_oof$inner_edition_id < outer_edition_id, , drop = FALSE],
  recipe = frozen_calibration_recipe
)
calibrated <- apply_phase12_calibrator(fit, raw_probability_view)
validate_probability_vector(calibrated, name = "calibrated_1x2")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legacy `calibrate_model()` simulates a small sample and reports draw Brier/plot output | Phase 12 candidate/track calibrators trained from chronology-safe inner OOF and scored on the shared benchmark contract | Phase 12 design | Legacy calibration is not a promotion input; do not reuse it for CAL-01/CAL-02. [VERIFIED: `R/forecast/calibration.R`; locked context] |
| Phase 11 shortlist is research-only and non-exclusive | Phase 12 freeze and final decision become authoritative only after preflight and one-shot evaluation | Phase 12 design | Keeps discovery closed and makes release status explicit. [VERIFIED: Phase 11 manifest; locked context] |
| Dashboard selects baseline/hybrid from model-file availability | Dashboard resolves the approved versioned model contract | Phase 12 design | Prevents stale or unapproved artifacts from reaching presentation/export. [VERIFIED: current `_targets.R`; locked D-15] |
| Phase 9 bundle protects development from WC2026 labels | Phase 12 adds an application-level immutable label artifact and append-only final-evaluation manifest | Phase 12 design | Enables exactly-once final scoring while retaining auditability. [VERIFIED: Phase 9 seal; locked D-09–D-12] |

**Deprecated/outdated:**

- `R/forecast/calibration.R::calibrate_model()` is an MVP diagnostic around simulated forecasts and a draw-only Brier score, not the Phase 12 multicandidate inner-OOF calibration contract. [VERIFIED: codebase grep]
- Direct `home_model_path`/`away_model_path` selection in dashboard orchestration is not an approved release resolver. [VERIFIED: `_targets.R`; locked D-15]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A low-parameter base-R vector-scaling/temperature calibrator is the preferred recipe. | Standard Stack; Architecture Pattern 1 | The exact calibration object/API changes, or a reviewed existing recipe is required before freeze. |
| A2 | A minimum prior-tournament/class-support rule should disable calibration and retain raw output when history is insufficient. | Architecture Pattern 1 | Early folds could be overfit or an alternate fallback policy could be required. |
| A3 | The suggested Phase 12 source/output directory names are acceptable. | Recommended Project Structure | Plan file paths and target contracts would need adjustment. |
| A4 | Presentation can expose calibrated 1X2 while retaining the raw joint distribution for scoreline/tournament simulation, provided the contract labels both views. | Architecture Pattern 2 | Dashboard/API semantics could be inconsistent unless the consumer policy is explicitly changed. |
| A5 | A final approved Phase 11 RF or incumbent model object must be fit/serialized separately from Phase 11’s research predictions. | Summary; Architecture Pattern 5 | The release may instead consume an existing incumbent object or a different final-fit adapter. |

## Open Questions

1. **Which exact calibration recipe and minimum history rule should be frozen?**
   - What we know: D-02/D-03 require candidate/track-specific expanding prior-tournament inner OOF; D-04 requires calibration, RPS, Brier, log-loss, stability, and coverage gates. [VERIFIED: locked context]
   - What's unclear: CONTEXT.md does not lock the parametric form, regularization, minimum prior tournaments, class-support floor, or first-fold behavior. [VERIFIED: CONTEXT.md inspection]
   - Recommendation: Lock one deterministic low-parameter recipe, support fallback-to-raw, and hash the recipe before fitting any calibrator. [ASSUMED]

2. **What is the final-fit adapter for each admissible candidate, especially the active Phase 11 RF?**
   - What we know: Phase 11 adapters fit fold-local research models and publish predictions/manifests; the Phase 11 runner deliberately rejects promotion/release behavior. [VERIFIED: `R/benchmark/hybrid_runner.R`; Phase 11 target tests]
   - What's unclear: No existing `fit_final_release_model()` or release model contract was found; current dashboard model objects are legacy baseline/hybrid `.rds` files. [VERIFIED: codebase grep]
   - Recommendation: Add an allowlisted final-fit service that consumes frozen registry/settings and pre-2026 data only, then records model-object hashes in the release contract. [VERIFIED: existing allowlist patterns; recommendation]

3. **How should calibrated 1X2 probabilities be exposed to dashboard/export consumers?**
   - What we know: D-01 preserves the joint score distribution while calibrating derived 1X2; current dashboard derives forecasts from model simulations and raw model paths. [VERIFIED: locked context; dashboard code]
   - What's unclear: Whether dashboard match cards, CSV exports, and tournament simulation should use calibrated 1X2, raw distribution-derived 1X2, or both. [VERIFIED: codebase/context inspection]
   - Recommendation: Make `primary_probability_view` explicit in the contract and test the chosen behavior in both dashboard and export regression suites; never silently mix views. [ASSUMED]

4. **What file is the authoritative WC2026 label source at execution time?**
   - What we know: The guard and benchmark registries identify WC2026 as a sealed holdout, and current development targets are required to keep labels inaccessible. [VERIFIED: `R/benchmark/cutoffs.R`; `test_benchmark_seal.R`]
   - What's unclear: Phase 12 must not discover or read the label-bearing source during research; the plan needs a reviewed opener that names the source only inside the final-evaluation boundary. [VERIFIED: scope and lock inspection]
   - Recommendation: Keep label source resolution behind the one-shot opener and add a human-reviewed checkpoint immediately before opening. [VERIFIED: locked D-09; recommendation]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| R | All Phase 12 code/tests | ✓ | 4.6.1 | — [VERIFIED: installed environment] |
| `targets` | `_targets.R` orchestration | ✓ | 1.12.0 | — [VERIFIED: installed environment] |
| `digest` | SHA-256 manifests and release validation | ✓ | 0.6.39 | — [VERIFIED: installed environment] |
| `jsonlite` | JSON protocol/contract serialization | ✓ | 2.0.0 | — [VERIFIED: installed environment] |
| `testthat` | Validation architecture | ✓ | 3.3.2 | — [VERIFIED: installed environment] |
| Project-local `ranger` | Active Phase 11 RF final fit/replay | ✓ | 0.18.0 | Incumbent-only release if RF final-fit admissibility fails; [VERIFIED: project-local environment and Phase 11 manifest] |
| Network/external service | None; sources are committed/local by project convention | Not required | — | Keep the Phase 12 execution network-free. [VERIFIED: Phase 9/10/11 run manifests; AGENTS.md] |

**Missing dependencies with no fallback:** None identified. [VERIFIED: environment audit]

**Missing dependencies with fallback:** `tarchetypes` is not installed, but the existing `_targets.R` uses core `targets` constructs; no fallback work is needed. [VERIFIED: installed environment and target script]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 [VERIFIED: installed environment] |
| Config file | None detected; tests source project modules directly. [VERIFIED: file inventory] |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase12_calibration_release.R", stop_on_failure=TRUE)'` [RECOMMENDED] |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", stop_on_failure=TRUE, stop_on_warning=TRUE)'` [VERIFIED: AGENTS.md project instruction] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | Inner OOF rows are prior-tournament-only, cutoff-safe, candidate/track-specific, and never include WC2026 labels. | unit + integration | `testthat::test_file("tests/testthat/test_phase12_calibration_release.R")` | ❌ Wave 0 |
| CAL-02 | Raw and calibrated 1X2 vectors use identical fixture IDs and score through RPS/Brier/log loss plus calibration diagnostics; regression/veto evidence is persisted. | unit + integration | same focused Phase 12 test file | ❌ Wave 0 |
| PROMO-01 | Freeze manifest includes all nine candidates, inactive rows, code/settings/features/panels/seeds/recipe/threshold hashes, and rejects post-freeze drift. | contract | `testthat::test_file("tests/testthat/test_phase12_freeze.R")` | ❌ Wave 0 |
| PROMO-02 | Preflight aborts before labels, final evaluation opens once, final manifest is append-only, and incumbent fallback is explicit. | integration + negative-path | `testthat::test_file("tests/testthat/test_phase12_final_evaluation.R")` | ❌ Wave 0 |
| PROMO-03 | Release bundle validates from a fresh R process; dashboard/export reject missing/mismatched contracts and load only the approved model. | integration + presentation regression | `testthat::test_file("tests/testthat/test_phase12_release_consumers.R")` | ❌ Wave 0 |

Existing inherited tests passed during research: Phase 9 promotion 169 assertions, shared scoring 47 assertions, WC2026 seal 18 assertions, Phase 11 target contracts 35 assertions, and dashboard regression 451 assertions. [VERIFIED: test execution in this session]

### Sampling Rate

- **Per task commit:** Phase 12 focused test file(s), under the quick command above. [RECOMMENDED]
- **Per wave merge:** Phase 9 promotion, scoring, seal, Phase 11 targets, and release-consumer focused suites. [RECOMMENDED]
- **Phase gate:** Full testthat suite green, fresh-process release validation green, and target-DAG ancestry confirms no label-bearing source precedes freeze/calibration. [VERIFIED: project testing conventions; locked D-09]

### Wave 0 Gaps

- [ ] `tests/testthat/test_phase12_calibration_release.R` — calibrator fit/apply, simplex, raw-vs-calibrated scoring, and chronology invariants. [RECOMMENDED]
- [ ] `tests/testthat/test_phase12_freeze.R` — nine-row freeze, hashes, inactive/no-score preservation, and drift rejection. [RECOMMENDED]
- [ ] `tests/testthat/test_phase12_final_evaluation.R` — preflight abort, one-shot opener, immutable label copy, append-only manifest, and incumbent-retained path. [RECOMMENDED]
- [ ] `tests/testthat/test_phase12_release_consumers.R` — release resolver, model-contract hash checks, dashboard/export routing, and fail-closed regressions. [RECOMMENDED]
- [ ] A synthetic label-free/final-evaluation fixture set that cannot read the real WC2026 outcome source during ordinary tests. [RECOMMENDED]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`. OWASP describes ASVS as a testable application-security control standard and lists validation, stored cryptography, files/resources, business logic, and configuration as relevant categories. [CITED: https://owasp.org/www-project-application-security-verification-standard/; [CITED: https://devguide.owasp.org/en/06-verification/01-guides/03-asvs/]]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No user/session authentication surface is introduced by this local R pipeline; do not invent auth work. [VERIFIED: codebase scope audit] |
| V3 Session Management | no | No session or token state is introduced; release identity is hash/manifest based. [VERIFIED: codebase scope audit] |
| V4 Access Control | yes, artifact authority | Treat `approved` release status, trusted release root, and manifest-only resolution as the access-control boundary for model consumption. [VERIFIED: locked D-15; recommended control] |
| V5 Input Validation | yes | Reject malformed probabilities, candidate IDs, statuses, paths, hashes, panel counts, G=40 drift, duplicate/second final-evaluation manifests, and label-bearing inputs before processing. [VERIFIED: existing validators; locked D-09/D-15] |
| V6 Stored Cryptography | yes, integrity only | Use the existing library-backed SHA-256 implementation for artifact integrity; do not hand-roll cryptography or imply that a checksum provides confidentiality/authentication. [VERIFIED: `digest` usage; [CITED: https://cornucopia.owasp.org/taxonomy/asvs-5.0/11-cryptography/02-secure-cryptography-implementation]] |

### Known Threat Patterns for R/targets Release Pipeline

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Model file replaced while manifest remains unchanged | Tampering | Hash every model/calibrator/contract/report file and validate from a fresh process before consumer load. [VERIFIED: Phase 9/11 checksum patterns] |
| Candidate or calibration recipe changes after freeze | Tampering / Elevation of privilege | Self-hash freeze manifest, compare all parent identities, and abort before label opening. [VERIFIED: locked D-06–D-09] |
| WC2026 labels enter calibration or selection | Information disclosure / Tampering | Separate label-free and label-bearing APIs; use `guard_benchmark_purpose()` and one-shot opener. [VERIFIED: `R/benchmark/cutoffs.R`; locked D-09/D-10] |
| Dashboard loads stale/latest path instead of approved release | Tampering / Spoofing | Resolve only the approved manifest, validate status and hashes, and fail closed on mismatch. [VERIFIED: locked D-15; current consumer gap] |
| Partial release directory is observed | Denial of service / Tampering | Stage, validate, atomically install, retain rollback, and validate post-install. [VERIFIED: `benchmark_runner_install_staged_bundle()`] |
| Path traversal or arbitrary artifact path in manifest | Tampering | Normalize paths under the trusted release root and reject absolute/escaping paths before read. [RECOMMENDED; security control]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/12-calibration-promotion-and-model-release/12-CONTEXT.md` — locked calibration, freeze, one-shot holdout, fallback, and consumer rules. [VERIFIED: user-provided project contract]
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `AGENTS.md` — phase requirements, success criteria, project constraints, and current state. [VERIFIED: codebase read]
- `R/evaluation/benchmark_scores.R` and `R/evaluation/proper_scores.R` — exact score, calibration-bin, panel, and distribution services. [VERIFIED: codebase read]
- `R/evaluation/promotion.R` and `data/benchmark/phase09/promotion_protocol.json` — frozen evaluator and promotion values. [VERIFIED: codebase read]
- `R/benchmark/cutoffs.R`, `R/benchmark/runner.R`, `R/benchmark/hybrid_runner.R` — holdout guard, manifests, staged publication, and Phase 11 research-only boundary. [VERIFIED: codebase read]
- Phase 9–11 durable manifests, verification reports, summaries, and focused tests — accepted lineage, exact panels, nine-candidate registry, and inherited regressions. [VERIFIED: local artifact audit]

### Secondary (MEDIUM confidence)

- [targets `tar_target` reference](https://docs.ropensci.org/targets/reference/tar_target.html) — file targets, target dependencies, reproducible target seeds, and storage behavior. [CITED: official documentation]
- [targets user manual](https://books.ropensci.org/targets/targets.html) — durable target design, hashable returns, file targets, and side-effect guidance. [CITED: official documentation]
- [scikit-learn probability calibration guide](https://scikit-learn.org/stable/modules/calibration.html) — calibration-curve interpretation and the warning that proper scores combine calibration and discrimination. [CITED: official documentation; cross-ecosystem conceptual reference]
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) — security verification categories and current ASVS framing. [CITED: official documentation]

### Tertiary (LOW confidence)

- None used for locked decisions. The exact Phase 12 calibrator parameterization, minimum-history rule, and consumer-view policy remain assumptions requiring a pre-freeze decision. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing runtime/package audit and official `targets` documentation confirm the orchestration seam; no new package is required. [VERIFIED: environment audit; cited docs]
- Architecture: MEDIUM — inherited contracts are strongly verified, but the final-fit/release/consumer seams do not yet exist and require implementation choices. [VERIFIED: codebase audit]
- Pitfalls: HIGH — derived from explicit Phase 9/11 verification findings, existing fail-closed tests, and locked Phase 12 constraints. [VERIFIED: codebase and artifact audit]

**Research date:** 2026-08-10
**Valid until:** 2026-09-09 for the stable R/project contract; recheck sooner if the Phase 12 recipe or release consumer architecture changes. [ASSUMED]
