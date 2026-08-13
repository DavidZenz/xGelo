---
phase: 10-statistical-goal-model-challengers
verified: 2026-08-08T14:09:11Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 10: Statistical Goal-Model Challengers Verification Report

**Phase Goal:** Test interpretable score-model alternatives and simplify the incumbent where correlated or inactive predictors do not add out-of-sample value.
**Verified:** 2026-08-08T14:09:11Z
**Status:** passed
**Re-verification:** No — initial formal verification

## Verdict

Phase 10 is goal-complete. The accepted historical challenger bundle is valid,
reproducible, parent-complete, research-only, and sealed against WC2026 outcomes.
All five roadmap success criteria and STAT-01 through STAT-04 are supported by
source inspection, focused behavioral tests, persisted-bundle read-back, the
complete test suite, and measured per-file coverage.

The long canonical benchmark was not rerun during verification. The verifier
validated the already-published bundle and its persisted evidence.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | A team-specific regularized Poisson candidate is registered and evaluated under the common benchmark contract. | VERIFIED | The Phase 10 registry contains seven candidates; the accepted run manifest records seven candidates, two tracks, twelve editions, exact 630/609 panels, and 8,820 fixture predictions. Penalized-Poisson design/tuning, adapter, selection, bundle, and full-suite tests passed. |
| 2 | Dynamic attack and defence ratings update strictly from prior matches and pass point-in-time leakage tests. | VERIFIED | Dynamic state/tuning tests passed; persisted model manifests carry strict exclusive evidence cutoffs and prior-only result/feature dates. The complete bundle validator and benchmark cutoff/seal regressions passed. |
| 3 | Dixon-Coles and bivariate-Poisson corrections produce valid score distributions; a representative dependence model is selected from pre-2026 folds only. | VERIFIED | Dependence PMF/parameter tests passed; the persisted G=40 score grid contains 14,826,420 rows; the shortlist records `poisson_team_ridge_elo_dc` as the registered dependence representative and all persisted evidence is pre-2026. |
| 4 | Controlled ablations report active feature manifests and explicitly diagnose zero-coverage xG and form signals. | VERIFIED | Ablation hierarchy/selection tests passed. Model manifests record active predictors and dropped xG/form predictors with explicit missing-or-zero-variance reasons; the accepted shortlist and feature-coverage evidence validate the controlled hierarchy. |
| 5 | Paired fold-level comparisons cover every baseline without making a final 2026 promotion decision. | VERIFIED | The bundle contains all-baseline paired comparisons, a three-slot research shortlist, `research_only=TRUE`, `wc2026_sealed=TRUE`, and no Phase 10 promotion evaluator path. Full bundle, target-ancestry, and complete-suite tests passed. |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/forecast/penalized_poisson.R` | Team-specific regularized Poisson candidates | VERIFIED | Exists, substantive, wired through focused design/tuning and adapter tests; measured coverage 90.59%. |
| `R/forecast/dynamic_goal_ability.R` | Chronology-safe dynamic attack/defence candidates | VERIFIED | Exists, substantive, wired through state/tuning tests; measured coverage 89.53%. |
| `R/forecast/score_dependence.R` | Dixon-Coles and bivariate-Poisson PMFs/parameters | VERIFIED | Exists, substantive, wired through PMF/parameter tests; measured coverage 86.35%. |
| `R/benchmark/challengers.R` | Common adapters and incumbent ablation | VERIFIED | Exists, substantive, wired through adapter/ablation tests; measured coverage 90.99%. |
| `R/evaluation/challenger_selection.R` | All-baseline comparisons and research shortlist | VERIFIED | Exists, substantive, wired through selection tests; measured coverage 85.71%. |
| `data/benchmark/phase10/` | Frozen registries, grids, selection protocol, storage and dependency provenance | VERIFIED | All plan-declared registry/protocol artifacts passed artifact checks and protocol tests. |
| `outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/` | Accepted canonical research bundle | VERIFIED | Deep read-back validation returned `valid=TRUE`, `reproducible=TRUE`, `parents_valid=TRUE`, open panel 630, rich panel 609, G=40, and exact Phase 9 parent SHA `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069`. |
| `tests/testthat/` and `tests/testthat/phase10_core_coverage.R` | Regression, contract, integration, and coverage gates | VERIFIED | Complete test suite and coverage gate exited 0 with warnings treated as failures; all five core files cleared 80% without exceptions. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Phase 9 frozen bundle | Phase 10 registries and runner | Parent SHA, checksum self-hash, and parent graph | WIRED | Deep validation and `test_statistical_registry_protocol.R` passed; exact parent bundle SHA was reconstructed. |
| Frozen registries and prior boundaries | Candidate fit/state/dependence services | Exclusive outer-to-inner chronology and persisted fold settings | WIRED | Dynamic, tuning, dependence, cutoff, and registry tests passed; manifests retain cutoff and source-date evidence. |
| Candidate adapters | Common benchmark contract | Shared score-distribution, market, feature-evidence, and scoring validators | WIRED | Adapter, bundle, benchmark, and full-suite tests passed; persisted predictions and distributions validate against the common schema. |
| Predictions and feature evidence | Scores and paired comparisons | Exact feature-coverage keys and 630/609 panel projection | WIRED | Deep validator passed exact panel and persisted read-back checks; paired comparison and shortlist artifacts are present. |
| Paired comparisons | Research shortlist | Frozen selection protocol | WIRED | Three non-exclusive slots are persisted with evidence and protocol hashes; no release or promotion decision is emitted. |

The generic path-oriented key-link query reported false negatives for several
symbol-shaped `from` values such as `fit_fold_dependence_parameters`. Those are
not missing files: direct source inspection plus their named passing tests and
the deep persisted-bundle validator establish the links above.

## Data-Flow Trace

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Fixture predictions | Candidate/track/edition predictions | Frozen Phase 9 panels and point-in-time adapters | Yes; 8,820 persisted rows | FLOWING |
| Feature coverage | Provenance and active/inactive feature evidence | Prior-only feature companions and adapter output | Yes; persisted evidence validates | FLOWING |
| Score distributions | Normalized home/away goal PMFs | Candidate means plus registered dependence corrections | Yes; 14,826,420 G=40 rows | FLOWING |
| Benchmark comparisons | Fold-level proper scores and paired deltas | Shared scorer over exact panel projections | Yes; persisted comparison file validates | FLOWING |
| Research shortlist | Three evidence-linked representative slots | Frozen selection protocol | Yes; three non-exclusive rows | FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Prior-phase regression safety | Eight Phase 8/9 focused test files with `testthat::test_file()` | Exit 0; all tests passed | PASS |
| Phase 10 and workspace regression safety | Complete `testthat::test_dir("tests/testthat", stop_on_failure=TRUE, stop_on_warning=TRUE)` | Exit 0; no failures or warnings | PASS |
| Persisted canonical bundle acceptance | `validate_statistical_challenger_bundle()` plus exact parent/panel/G=40 assertions | Exit 0; valid, reproducible, parent-complete, 630/609 | PASS |
| Core modelling coverage | `run_phase10_core_coverage()` | Exit 0; 90.59%, 89.53%, 86.35%, 90.99%, 85.71% | PASS |
| Research-only / WC2026 boundary | Bundle flags and static boundary tests | `research_only=TRUE`, `wc2026_sealed=TRUE`; forbidden paths rejected | PASS |

## Probe Execution

No `scripts/*/tests/probe-*.sh` files were declared or found. Probe execution
is not applicable to this R benchmark phase.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| STAT-01 | 10-01, 10-03, 10-06, 10-07, 10-08, 10-11 | Benchmark a team-specific penalized Poisson model against registered baselines | SATISFIED | Registry, adapter, selection, bundle, full-suite, and exact-panel evidence. |
| STAT-02 | 10-04, 10-06, 10-07, 10-08, 10-10 | Benchmark dynamic attack and defence ratings using prior matches only | SATISFIED | Dynamic state/tuning tests, strict cutoffs, prior-date manifests, and persisted bundle validation. |
| STAT-03 | 10-05, 10-07, 10-08, 10-09, 10-10, 10-11 | Compare Dixon-Coles and bivariate-Poisson corrections under the common contract | SATISFIED | Shared-mean dependence tests, valid G=40 grids, fold evidence, and dependence shortlist slot. |
| STAT-04 | 10-06, 10-07, 10-08, 10-09, 10-11 | Run controlled incumbent ablations and identify retained feature sets | SATISFIED | Ablation tests, active predictor manifests, zero-coverage xG/form diagnosis, and shortlist evidence. |

No orphaned Phase 10 requirements were found.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| None | - | No unreferenced `TBD`, `FIXME`, `XXX`, placeholder, or empty production implementation found in the Phase 10 source scan. | None | No blocker. |

## Human Verification Required

None. Phase 10 produces auditable R code and persisted analytical artifacts;
the declared success criteria are covered by deterministic automated checks and
read-back validation rather than visual or external-service behavior.

## Gaps Summary

No gaps remain. Phase 10 is formally verified and ready to hand off its
historical shortlist to Phase 11/12. The accepted challenger bundle remains
research-only; no candidate is promoted by this phase.

---

_Verified: 2026-08-08T14:09:11Z_  
_Verifier: the agent (gsd-verifier)_
