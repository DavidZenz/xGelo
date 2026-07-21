---
phase: 09-rolling-tournament-benchmark-harness
verified: 2026-07-21T20:08:50Z
status: passed
score: 25/25 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 16/25
  gaps_closed:
    - "Every prediction now resolves to producer-captured, pre-imputation point-in-time feature evidence."
    - "Every evaluation consumer now enforces the exact frozen 630-fixture open and 609-fixture rich panels."
    - "Every canonical decision now reconstructs through evaluate_promotion() with complete ordered gate evidence."
  gaps_remaining: []
  regressions: []
---

# Phase 09: Rolling Tournament Benchmark Harness Verification Report

**Phase Goal:** Create the common, leakage-safe evaluation contract under which every baseline and challenger will be compared.
**Verified:** 2026-07-21T20:08:50Z
**Status:** passed
**Re-verification:** Yes — after closure of the three prior end-to-end gaps

## Verdict

Phase 09 is goal-complete. The former feature-provenance, frozen-panel, and promotion-wiring blockers are closed in source code and in the durable canonical bundle. Independent read-back validation reproduced bundle SHA-256 `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069` exactly.

The verifier did not accept the summaries or the orchestrator's full-suite claim as proof. Evidence below comes from source inspection, focused failure-propagating tests, direct invariant assertions, evaluator reconstruction, external file hashes, streamed row counts, target-DAG inspection, and the canonical persisted artifacts.

## Goal Achievement

### Roadmap Success Criteria

| # | Truth | Status | Evidence |
|---|---|---|---|
| R1 | Deterministic complete-tournament folds cover available World Cups/Euros and exclude WC2026 outcomes from development. | VERIFIED | Registry validation returns 12 editions and 630 fixtures; 12 frozen plus 272 updating boundaries use strict exclusive cutoffs. All non-empty manifest fit/result/feature maxima are before their boundary cutoff. Focused cutoff and WC2026 seal files passed with true failure exits. |
| R2 | All models emit one schema and retain point-in-time feature contracts, manifests, cutoffs, and feature-coverage audits. | VERIFIED | The bundle has 6,300 common-schema predictions, 1,420 model manifests, and 78,120 feature rows. All 6,300 unique `feature_coverage_id` groups resolve exactly and `validate_benchmark_feature_evidence()` passes. |
| R3 | Naive, Elo-only, and incumbent NB baselines run on common fixtures/shared seeds and reproduce registered outputs. | VERIFIED | Five registered models, both tracks, 6,300 predictions, complete G=40 grids, stable model/settings hashes, and model-independent seed IDs validate. Bundle identity matches the supplied expected SHA. |
| R4 | The harness reports proper scores, calibration, paired per-fold deltas, and uncertainty. | VERIFIED | 87,612 panel-exact fixture-score rows, 1,970 summaries, and 250 paired rows validate. Focused scoring tests passed equal-tournament aggregation, fixed calibration bins, exact pairing, 12-fold deltas, LOTO, and 10,000-replicate tournament bootstrap behavior. |
| R5 | A checksum-backed promotion protocol predefines practical thresholds and tie-breaks. | VERIFIED | Protocol SHA `5535217768e395990c7717e2c607904635ce373f6cd4730ecac2f4bbe72aa08d` validates exact D-16–D-20 operators, thresholds, and tie-break order. Five durable decisions reconstruct byte-identically through `evaluate_promotion()` and contain 159 value/pass columns plus non-empty reasons for every non-eligible result. |

**Roadmap score:** 5/5 verified.

### Locked Decisions D-01 Through D-20

| Decision | Status | Actual evidence |
|---|---|---|
| D-01 | VERIFIED | Exact World Cups 2002–2022 and Euros 2004–2024; 630 unique official fixtures. |
| D-02 | VERIFIED | Chronological complete-date blocks and strict prior-only manifest dates. |
| D-03 | VERIFIED | Frozen and updating tracks both present; same-date cutoff tests pass. |
| D-04 | VERIFIED | Tournament means precede equal-tournament headline aggregation; pooled results remain separately labelled. |
| D-05 | VERIFIED | Open core is exactly 630 and rich panel exactly 609 throughout scoring, summaries, calibration, comparisons, and decisions. |
| D-06 | VERIFIED | Expanding supervised history uses the frozen 730-day recency schedule. |
| D-07 | VERIFIED | Elo retains recursive all-history treatment without supervised reweighting. |
| D-08 | VERIFIED | Frozen importance weights remain 1.8 finals, 1.3 qualifiers/Nations League, 0.6 friendlies, 1.0 otherwise. |
| D-09 | VERIFIED | One named supervised schedule is registered and hash-stable. |
| D-10 | VERIFIED | 272 updating refit boundaries plus 12 pre-opener states; producer and manifest evidence is strictly prior-only. |
| D-11 | VERIFIED | Uniform and expanding historical 1X2 controls are registered and emit complete outputs. |
| D-12 | VERIFIED | Elo-only uses Elo difference and venue/neutral status and emits complete score distributions/markets. |
| D-13 | VERIFIED | Open NB owns the 630 core; production hybrid NB is evaluated only on the 609 rich panel while all predictions remain audit-visible. |
| D-14 | VERIFIED | Formulas, hyperparameters, weights, registrations, and G=40 are frozen; registration/settings hashes remain stable across manifests. |
| D-15 | VERIFIED | Common identities, fixture keys, cutoffs, seeds, predictions, distributions, manifests, and exact feature evidence all validate. |
| D-16 | VERIFIED | Evaluator applies RPS delta `<= -0.003` and CI upper `< 0` from persisted full-precision evidence. |
| D-17 | VERIFIED | Evaluator applies 8/12, 2 World Cup, 2 Euro, and max-regression `<= 0.015` gates. |
| D-18 | VERIFIED | Brier/log/calibration and all common contract vetoes are serialized and reconstructed. |
| D-19 | VERIFIED | Rich-panel gate uses 609 fixtures and a mandatory 630-fixture open companion. |
| D-20 | VERIFIED | Protocol, inputs, models/settings, features, panels, seeds, G, bundle outputs, and parent graph are checksummed; WC2026 remains sealed. |

**Decision score:** 20/20 verified.  
**Combined score:** 25/25 contractual truths verified; 0 behavior-unverified.

## Former Gap Closure

### 1. Pre-imputation feature provenance — CLOSED

- `make_latest_team_evidence_lookup()` returns source-row presence/date, value presence, imputation state, and reason together before defaults are written.
- Direct checks distinguish observed numeric zero (`source_present=TRUE`, `imputed=FALSE`) from missing-value and missing-row zeros (`imputed=TRUE` with distinct reasons).
- The canonical `goal_training_features_hybrid.csv` independently validated at 49,520 unique match rows, 260 columns, and 205 evidence-companion columns.
- Adapters expand each prediction over its exact registered panel features, validate the evidence, and reject dangling or malformed links before returning.

### 2. Exact 630/609 panels with durable evidence — CLOSED

- `benchmark_panel_fixture_ids()` returns exactly 630 open and 609 rich IDs.
- All 6,300 predictions remain in the audit artifact, while no rich-ineligible fixture appears in a `production_hybrid_nb` score.
- Direct set-equality checks confirm every model/track/metric uses only its declared panel.
- Bundle read-back validates summary denominators and paired fold/headline/LOTO counts against the frozen panel registry.

### 3. Canonical evaluator-backed promotion decisions — CLOSED

- `benchmark_runner_decisions()` round-trips summaries, comparisons, coverage, and run facts through persisted CSV views, assembles candidates, then invokes `evaluate_promotion()`.
- Bundle validation reconstructs every decision and compares the canonical decision hash; tampered reasons, values, or booleans are rejected by tests.
- Every non-eligible durable row has ordered reason codes. For example, `elo_goal_nb` records `core_rps_effect_failed` and `core_ci_failed` for delta `-0.00145656614084001` and CI upper `0.000239523968796261`.

### 4. Final resealed bundle provenance — VERIFIED

- Recomputed bundle SHA: `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069` (exact expected match).
- Ten output SHA-256 values, bytes, and 10,773,564 streamed manifest rows passed independently.
- Checksum self-hash: `4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309`.
- Complete 15-input parent graph: `19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584`.
- Source Git SHA `6fd618235edbc432e8c66b40c6ab3acb846900d9` exists and is the direct parent of publication commit `15ed965012bd231769d45253211ae01df327bda4`; no production source file changed between that source commit and HEAD.

## Required Artifacts

| Artifact group | Status | Details |
|---|---|---|
| Registries, boundaries, corrections | VERIFIED | 12 tournaments, 630 fixtures, 284 boundaries, 72 corrections; registry validator and source hashes pass. |
| Common prediction/distribution schema | VERIFIED | 6,300 predictions and 10,590,300 normalized 41×41 cells at G=40. |
| Model manifests | VERIFIED | 1,420 rows with strict cutoff dates and stable registration/settings hashes. |
| Runtime feature evidence | VERIFIED | 78,120 feature rows, 6,300 exact groups, complete cutoff/imputation/provenance/license schema. |
| Frozen panels | VERIFIED | 630 open and 609 rich; exact projection enforced at every evaluation entry point. |
| Proper scoring/calibration/uncertainty | VERIFIED | 87,612 fixture scores, 1,970 summaries, 250 paired diagnostic rows. |
| Promotion protocol and decisions | VERIFIED | Valid frozen protocol, pure evaluator, five reconstructable decisions, complete gate evidence. |
| Checksum/run manifests | VERIFIED | 10 outputs, 15 inputs, one self row; reproducible/sealed/network-free flags validate. |
| Targets DAG | VERIFIED | Eight Phase 09 targets, all 11 required edges, nine safe ancestors, zero forbidden dashboard/download/WC2026-retrospective ancestors. |

## Key Link Verification

| From | To | Status | Evidence |
|---|---|---|---|
| Registry/cutoffs | Adapter execution | WIRED | Runner calls the purpose guard, constructs frozen/updating fixtures, and applies strict feature cutoffs before adapters. |
| Producer features | Adapter feature evidence | WIRED | Companion columns survive history/fixture preparation and feed `build_registered_feature_coverage()`. |
| Predictions | Durable feature coverage | WIRED | Exact 6,300-group foreign-key equality; construction and read-back validators pass. |
| Panel registry | Scores/calibration/comparisons | WIRED | Explicit fixture-ID arguments and bundle denominator reconciliation enforce 630/609. |
| Scores/comparisons/coverage | Promotion evaluator | WIRED | Candidate assembly consumes persisted source tables and calls `evaluate_promotion()`; read-back reconstruction passes. |
| Inputs/outputs | Checksum manifest | WIRED | External hashes, rows, self-hash, selected G, and complete parent graph reconcile. |
| Phase 09 targets | Production publication | ISOLATED | Target ancestry scan finds no dashboard, download, refresh, WC2026 ledger, or retrospective ancestors. |

## Data-Flow Trace

| Output | Upstream source | Produces real data | Status |
|---|---|---|---|
| Fixture predictions | Frozen registry → strict boundary state → registered baseline adapter | Yes | FLOWING |
| Feature coverage | Producer evidence companions → runtime fixture evidence → exact registered feature expansion | Yes | FLOWING |
| Panel scores | Audit predictions → frozen panel selector → shared scorer/calibrator | Yes, exact 630/609 | FLOWING |
| Paired comparisons | Panel scores → exact fixture pairing → tournament deltas/bootstrap | Yes, all 12 folds | FLOWING |
| Promotion decisions | Persisted summaries/comparisons/coverage/run facts → `evaluate_promotion()` | Yes, reconstructable | FLOWING |
| Bundle identity | Ten durable output hashes + 15 frozen input parents + self hash | Yes | FLOWING |

## Behavioral Spot-Checks

| Behavior | Result | Status |
|---|---|---|
| Strict date-complete cutoff states | `test_benchmark_cutoffs.R` passed 11 expectations. | PASS |
| WC2026 rejection before callbacks | `test_benchmark_seal.R` passed 18 expectations. | PASS |
| Proper scoring, panel exactness, calibration, pairing, uncertainty | `test_benchmark_scoring.R` passed 47 expectations. | PASS |
| Adapter feature groups, seeds, baseline registration, G support | `test_benchmark_baselines.R` passed 75 expectations. | PASS |
| Exact promotion boundaries, vetoes, rich/open gates, tie-breaks | `test_benchmark_promotion.R` passed 169 expectations. | PASS |
| Canonical bundle semantic validation | Direct validator returned valid, 12 editions, five models, G=40, 11 artifacts, reproducible/sealed/network-free. | PASS |
| Canonical producer evidence | 49,520-row validator plus observed-zero/missing-zero direct assertions passed. | PASS |

The orchestrator separately reported a full `tests/testthat` run with failure/warning stops. This verdict does not depend on that report; the focused tests and direct checks above were executed by this verifier.

## Probe Execution

No Phase 09 `probe-*.sh` files or declared probe commands exist. Probe execution is not applicable.

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| BENCH-01 | SATISFIED | Exact 12/630 registry, date-complete boundaries, prior-only manifest dates, and focused cutoff tests. |
| BENCH-02 | SATISFIED | Purpose guard and focused seal tests reject WC2026 outcomes before model callbacks; bundle remains sealed. |
| BENCH-03 | SATISFIED | Common predictions/distributions/manifests plus 78,120 linked pre-imputation feature rows and complete checksum parents. |
| BENCH-04 | SATISFIED | Five registered baseline classes, both tracks, shared seeds, stable hashes, exact panels, reproducible bundle identity. |
| BENCH-05 | SATISFIED | Proper scores, fixed calibration, paired fold uncertainty, complete gate evidence, frozen protocol, deterministic tie-breaks. |

No orphaned Phase 09 requirements exist; BENCH-01 through BENCH-05 are mapped to Phase 09 and claimed by its plans.

## Anti-Patterns and Disconfirmation Pass

No unreferenced `TBD`, `FIXME`, or `XXX` markers, placeholder implementations, network/refresh calls, or hard-coded alternate promotion decisions were found in Phase 09 production files.

| Finding | Classification | Assessment |
|---|---|---|
| `run_manifest.dirty_worktree=TRUE` causes all durable decisions to include `code_freeze_failed`. | INFO | Fail-closed and auditable, not a bypass. The source SHA exists, all Phase 09 code fixes are ancestors of it, and only planning/bundle artifacts changed afterward. No candidate is incorrectly promoted. |
| The evaluator call-count test includes a static one-call-site assertion. | INFO | Not relied on alone: actual five-row decision generation and full canonical read-back reconstruction independently prove the runtime path. |
| External source authority is represented by checked local martj42 goal/shootout artifacts. | INFO | All 72 corrections resolve to two existing local artifacts with exact SHA-256, source URLs, CC0 license, and row hashes. This satisfies the phase's declared open-data evidence contract. |

## Human Verification Required

None for Phase 09 goal achievement. The later pre-WC2026 label-opening governance approval remains an operational Phase 12 checkpoint, not an unresolved Phase 09 implementation truth.

## Gaps Summary

No gaps remain. All three prior blockers are closed without regressions, all five roadmap criteria and BENCH requirements are verified, and no later milestone phase is being used to defer missing Phase 09 work.

---

_Verified: 2026-07-21T20:08:50Z_  
_Verifier: the agent (gsd-verifier)_
