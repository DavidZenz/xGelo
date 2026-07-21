---
phase: 09-rolling-tournament-benchmark-harness
verified: 2026-07-21T06:45:34Z
status: gaps_found
score: 16/25 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Every prediction is linked to a complete point-in-time feature-coverage and provenance audit."
    status: failed
    reason: "The canonical feature_coverage.csv is a 60-row model/edition output-coverage summary, not the required model/boundary/fixture/feature audit; none of the 6,300 prediction feature_coverage_id values resolve to it, and the bundle validator never calls validate_feature_coverage()."
    artifacts:
      - path: "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/feature_coverage.csv"
        issue: "Missing boundary_id, fixture_id, feature_id, source_date, cutoff, imputation, active-feature, coverage-status, and license fields; all prediction references are dangling."
      - path: "R/benchmark/runner.R"
        issue: "Builds aggregate output coverage, validates only six aggregate columns, and hard-codes feature_coverage_valid = TRUE."
      - path: "R/benchmark/baselines.R"
        issue: "Emits fixture-level feature_coverage_id references but no corresponding feature-level coverage rows."
    missing:
      - "Emit one feature-coverage row per registered model/boundary/fixture/feature with source date, strict-cutoff status, imputation reason, active status, and license."
      - "Make every prediction feature_coverage_id resolve to generated coverage evidence."
      - "Call validate_feature_coverage() during bundle construction and validation; derive feature_coverage_valid from that result instead of a constant."
  - truth: "Feature-rich models are scored and compared only on their frozen predeclared eligible panel while open_core remains all 630 fixtures."
    status: failed
    reason: "feature_rich declares 609 eligible fixtures, but production_hybrid_nb predicts and is scored on all 630; 21 ineligible fixtures enter its scores, and paired comparisons use the global 630-fixture set rather than panel_fixtures.csv."
    artifacts:
      - path: "data/benchmark/phase09/panel_fixtures.csv"
        issue: "Correctly declares 609 eligible feature_rich fixtures, but the declaration is not enforced downstream."
      - path: "R/evaluation/benchmark_scores.R"
        issue: "score_benchmark_fixtures() requires the complete global fixture set for every model, preventing panel-specific scoring."
      - path: "R/benchmark/runner.R"
        issue: "benchmark_runner_comparisons() passes all score-eligible fixture IDs to every model comparison and never consults panel_fixtures.csv."
      - path: "R/benchmark/contracts.R"
        issue: "validate_panel_prediction_coverage() rejects missing required rows but does not reject extra out-of-panel rows."
    missing:
      - "Make prediction validation, scoring, calibration, and paired comparisons panel-aware."
      - "Reject extra out-of-panel rows for feature_rich comparisons and use the exact 609 declared eligible fixture IDs."
      - "Regenerate and reconcile the canonical bundle after fixing panel enforcement."
  - truth: "Canonical promotion decisions are produced by the checksum-frozen D-16 through D-20 gate with complete ordered reasons and gate values."
    status: failed
    reason: "The pure gate exists and its tests pass, but runner.R never calls evaluate_promotion(); benchmark_runner_decisions() hard-codes retain_incumbent and emits only coverage/provenance reasons. Canonical rows that fail the RPS and CI gates have blank/NA reason_codes and no Brier, log-loss, calibration, breadth, regression, optional-panel, or common-veto evidence."
    artifacts:
      - path: "R/evaluation/promotion.R"
        issue: "Substantive and tested, including commit 5f4c013's empty-reason fix, but orphaned from canonical runner decisions."
      - path: "R/benchmark/runner.R"
        issue: "benchmark_runner_decisions() sets decision = retain_incumbent without invoking evaluate_promotion() or serializing its result."
      - path: "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/comparisons/promotion_decisions.csv"
        issue: "All five rows have retain_incumbent and blank reasons; elo_goal_nb misses both the -0.003 effect and strict CI gates but has no reason code."
    missing:
      - "Build complete candidate gate inputs from proper-score, calibration, fold-breadth, regression, coverage, provenance, checksum, and reproducibility artifacts."
      - "Invoke evaluate_promotion() for every canonical decision and persist ordered reason codes, gate values, and gate booleans."
      - "Add pipeline/bundle tests that fail when a statistically ineligible candidate has no reason or when the runner bypasses the frozen protocol."
      - "Regenerate and revalidate promotion_decisions.csv and the enclosing checksum graph."
---

# Phase 09: Rolling Tournament Benchmark Harness Verification Report

**Phase Goal:** Create the common, leakage-safe evaluation contract under which every baseline and challenger will be compared.
**Verified:** 2026-07-21T06:45:34Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Verdict

Phase 09 is not goal-complete. The historical folds, leakage controls, five baselines, score support, scoring services, deterministic bundle, targets graph, and frozen protocol are substantive and largely correct. However, the canonical end-to-end path breaks three required links: feature provenance does not flow into the bundle, the feature-rich panel denominator is ignored during scoring, and the runner bypasses the promotion gate. These are BLOCKERs because later challengers would not actually be compared under the declared common contract.

The full repository suite passed with true failure exits, so these are coverage/wiring gaps rather than ordinary red-test failures.

## Goal Achievement

### Roadmap Success Criteria

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| R1 | Deterministic complete-tournament folds cover the available World Cups/Euros and exclude WC2026 outcomes from development. | VERIFIED | 12 editions, 630 fixtures, 12 frozen + 272 updating boundaries, strict manifest dates, no `wc2026` values in the bundle; registry/cutoff/seal tests pass. |
| R2 | All models emit one schema plus point-in-time feature contract, model manifest, cutoffs, and feature-coverage audit. | FAILED — BLOCKER | Predictions/distributions/manifests are complete, but 0/6,300 prediction `feature_coverage_id` values resolve; the 60-row coverage artifact lacks the required feature provenance schema. |
| R3 | Naive, Elo-only, and incumbent NB baselines run on shared fixtures and seeds and reproduce registered outputs. | VERIFIED | Five model registrations; 6,300 successful predictions over 630 fixtures and two tracks; 10,590,300 G=40 cells; model-independent seed registry; stable registration/settings hashes. |
| R4 | Harness reports proper scores, calibration, paired fold deltas, and uncertainty. | VERIFIED | 88,200 fixture-score rows, 1,970 summaries, 250 paired rows; tournament-first scoring, fixed bins, 12-fold deltas, LOTO, and 10,000-replicate paired bootstrap are implemented and tested. |
| R5 | A checksum-backed promotion protocol governs practical thresholds and tie-breaking before challenger selection. | FAILED — BLOCKER | Protocol JSON and pure gate are valid, but the canonical runner does not apply the gate; decision rows are hard-coded and lack gate reasons/evidence. |

**Roadmap score:** 3/5 verified.

### Locked Decisions D-01 Through D-20

| Decision | Status | Actual code/artifact evidence |
|---|---|---|
| D-01 | VERIFIED | Exact IDs: WC 2002–2022 and Euro 2004–2024; 630 unique fixtures with registered 64/31/51 edition counts. |
| D-02 | VERIFIED | `boundaries.csv` and `cutoffs.R` use chronological complete-date batches; direct manifest audit confirms all fit/result/feature maxima are strictly before the exclusive cutoff. |
| D-03 | VERIFIED | Both `frozen` and `updating` tracks exist; updating cutoffs equal fixture completion dates, frozen cutoffs equal edition openers, and same-date fixtures share one boundary. |
| D-04 | VERIFIED | `aggregate_benchmark_scores()` averages within edition before the equal-tournament headline and labels fixture-weighted pooling separately; unequal-size tests pass. |
| D-05 | FAILED — BLOCKER | Open core remains 630, but the predeclared 609-fixture rich panel is not honored in scoring: 21 ineligible fixtures enter production-hybrid scores/comparisons. |
| D-06 | VERIFIED | `weights.R` applies an expanding prior-only 730-day recency schedule to supervised fits. |
| D-07 | VERIFIED | Elo registration records `not_applied_recursive_elo`; tests cover recursive all-history treatment without supervised double weighting. |
| D-08 | VERIFIED | Frozen importance schedule is 1.8 finals, 1.3 qualifiers/Nations League, 0.6 friendlies, 1.0 otherwise. |
| D-09 | VERIFIED | One named `benchmark_supervised_730d_v1` schedule is frozen in model registrations; snapshot weights normalize to mean one. |
| D-10 | VERIFIED | 272 updating refit boundaries plus 12 pre-opener states; 1,420 manifests retain frozen settings and strict prior-only dates. |
| D-11 | VERIFIED | `uniform_1x2` and `expanding_1x2` are registered and produce coherent complete grids. |
| D-12 | VERIFIED | Elo-only formula is exactly goals on Elo difference + venue advantage; neutral symmetry and complete-grid/market reconciliation tests pass. |
| D-13 | FAILED — BLOCKER | Both NB incumbents are registered, but `production_hybrid_nb` is executed/scored on 630 fixtures instead of its 609-fixture declared rich panel. |
| D-14 | VERIFIED | `fold_specific_tuning_allowed` is false for all models; registration/settings hashes are invariant across all manifests; 8:40 support policy is frozen. |
| D-15 | FAILED — BLOCKER | Common predictions, grids, manifests, identities, and seeds exist, but the required feature-level coverage/provenance artifact is absent and its IDs are disconnected; panel identity is also not enforced. |
| D-16 | FAILED — BLOCKER | Exact `<= -0.003` and CI `< 0` logic exists in the pure gate, but canonical decisions bypass that gate. |
| D-17 | FAILED — BLOCKER | 8/12, 2 WC, 2 Euro, and max-regression logic is implemented/tested but is not applied or persisted by the runner decision path. |
| D-18 | FAILED — BLOCKER | Brier/log/calibration and common veto logic is implemented/tested but absent from canonical decisions and reason codes. |
| D-19 | FAILED — BLOCKER | Pure rich/open companion gates exist, but canonical rich comparisons use 630 rather than 609 fixtures and decisions bypass `evaluate_promotion()`. |
| D-20 | VERIFIED | Candidate inputs, thresholds, selected G, model/settings hashes, seeds, and protocol are checksummed; WC2026 remains sealed and no outcome appears in the bundle. |

**Decision score:** 13/20 verified.

**Combined score:** 16/25 contractual truths verified.

## Required Artifacts

| Artifact group | Status | Details |
|---|---|---|
| Historical registries and cutoffs | VERIFIED | 12 tournaments, 630 fixtures, 72 teams, 3 formats, 76 routes, 72 corrections, 284 boundaries; registry loader and canonical hashes pass. |
| Registry/cutoff/seal services | VERIFIED | `registry.R` and `cutoffs.R` are substantive and wired into targets/runner; seal tests prove pre-adapter rejection. |
| Common predictions and distributions | VERIFIED | 6,300 successful prediction rows and 10,590,300 complete 41×41 grids; bundle validation and external SHA-256 checks pass. |
| Model manifests | VERIFIED | 1,420 manifests; strict dates, convergence/fallback status, and stable registration/settings hashes validate. |
| Feature coverage | FAILED — BLOCKER | Artifact exists but is an aggregate output-coverage table, not the required feature-level audit; every prediction reference is dangling. |
| Panel declarations | PARTIAL | Declarations are correct (630 open, 609 rich), but downstream scoring ignores rich eligibility. |
| Score-support audit | VERIFIED | 46,860 normalized rows across G=8:40; G=40 is the smallest global pass; all G=40 rows pass. |
| Scoring and calibration | VERIFIED | Shared proper-score formulas, equal-tournament summaries, fixed bins, paired bootstrap, breadth/regression/LOTO services and tests pass. |
| Promotion protocol and pure gate | VERIFIED at L1/L2 | Canonical JSON, exact thresholds, hashes, tie-breaks, and boundary tests pass. |
| Canonical promotion decisions | FAILED — BLOCKER | Runner does not wire the pure gate; decisions are hard-coded and incomplete. |
| Targets graph | VERIFIED | All eight Phase 09 targets load and remain separate from dashboard/download targets. |
| Canonical bundle | PARTIAL | All 11 files, row counts, SHA-256 values, parent graph, and reproducibility flags validate, but validator omissions allow the three semantic gaps above. |

## Key Link Verification

| From | To | Status | Details |
|---|---|---|---|
| Registry files | `registry.R` | WIRED | Load, foreign-key, path, cardinality, provenance, and canonical-hash checks execute. |
| `cutoffs.R` | baseline adapter path | WIRED | Purpose guard runs before adapter invocation; strict state manifests confirm prior-only evidence. |
| Baseline adapters | prediction/distribution contracts | WIRED | Complete keys and G=40 grids are validated and scored. |
| Predictions | model manifests/distributions/seeds | WIRED | All referenced manifests, grids, boundaries, and seed IDs resolve. |
| Predictions | feature coverage | NOT WIRED — BLOCKER | 0/6,300 `feature_coverage_id` references resolve to the 60 coverage rows. |
| `panel_fixtures.csv` | scoring/comparisons | NOT WIRED — BLOCKER | Runner passes the global 630 IDs; 21 rich-ineligible fixtures are scored. |
| Score-support audit | protocol/checksum/run manifest | WIRED | Hash `95cbdef...15c9` and selected G=40 reconcile through the protocol and 25-row checksum graph. |
| Scoring | paired comparisons/bootstrap | WIRED | Exact fixture pairing, 12 fold deltas, LOTO, and registered bootstrap seed are present. |
| Promotion protocol/pure gate | canonical decisions | NOT WIRED — BLOCKER | `runner.R` contains no `evaluate_promotion()` call and hard-codes the decision. |
| Phase 09 targets | dashboard/Phase 8 outputs | ISOLATED | Target manifest has no dashboard/download references; protected artifact diff is empty. |

## Data-Flow Trace

| Output | Upstream source | Produces real data | Status |
|---|---|---|---|
| Fixture predictions | Registry → strict boundary snapshot → registered adapter | Yes, 6,300 successful rows | FLOWING |
| Score distributions | Registered fits/controls → analytic full grids | Yes, 10,590,300 normalized cells | FLOWING |
| Model manifests | Per-boundary fit state | Yes, 1,420 rows with strict dates/hashes | FLOWING |
| Feature coverage | Panel declaration + prediction counts only | No per-feature runtime evidence | HOLLOW/DISCONNECTED |
| Rich-panel scores | Global score-eligible fixture set | Real scores, wrong denominator | MISROUTED |
| Promotion decisions | Comparison headline + aggregate coverage | Real deltas, but protocol gate bypassed | PARTIAL/HOLLOW |

## Behavioral Spot-Checks

| Check | Command/result | Status |
|---|---|---|
| Registry validation | `load_benchmark_registries()` returned sealed 12/630/72/3/76/72/284 inventories. | PASS |
| Strict cutoff audit | All manifest fit/result/feature dates `< evidence_cutoff_exclusive`; frozen/updating boundary reconciliation passed. | PASS |
| Full repository tests with failure propagation | `testthat::test_dir(..., stop_on_failure = TRUE, stop_on_warning = TRUE)` completed with no failures or warnings. | PASS |
| Targets manifest | Eight required `benchmark_phase09_*` targets loaded; no dashboard/download/refresh command references. | PASS |
| Bundle validation in documented source order | `validate_rolling_benchmark_bundle()` returned valid, 12 editions, 630 core fixtures, 5 models, G=40, 11 artifacts, reproducible/sealed/network-free. | PASS, but validator is semantically incomplete |
| External checksum audit | `/usr/bin/shasum -a 256` equivalents matched all ten durable output hashes, including the 981,073,624-byte distribution file. | PASS |
| Exact Plan 09-04 acceptance command | Sourcing only `registry.R`, `contracts.R`, and `runner.R` failed: `load_promotion_protocol` not found. | WARNING — command under-specifies module dependencies |
| Feature audit validator on canonical artifact | `validate_feature_coverage()` failed because 13 required feature-provenance columns are absent. | FAIL — BLOCKER |
| Rich-panel denominator | Declared 609; production-hybrid predicted/scored 630; 21 out-of-panel fixtures; fold comparisons sum to 630 per track. | FAIL — BLOCKER |
| Applied promotion reasons | `elo_goal_nb` has delta `-0.001456566` and CI upper `0.000239524`, failing both gates, but `reason_codes` reloads as `NA`. | FAIL — BLOCKER |

### Test-command propagation finding

The verifier's full-suite command used explicit failure/warning stops and returned success. However, most PLAN verification snippets call `testthat::test_file()` without `stop_on_failure = TRUE`; installed testthat 3.3.2 delegates to `test_files(..., stop_on_failure = FALSE)` by default. Those snippets can report failed expectations without a non-zero shell exit. Plan 09-04 Task 1 correctly supplied stop flags, but the combined quick-suite snippets should be hardened.

## Probe Execution

No Phase 09 `probe-*.sh` files or declared probe commands exist. Probe execution was not applicable.

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| BENCH-01 | SATISFIED | Exact 12/630 registry, 284 date-complete boundaries, strict prior-only manifests, deterministic cutoff tests. |
| BENCH-02 | SATISFIED | WC2026 purpose guard rejects labels before callbacks; no WC2026 outcome appears in the bundle/protocol. |
| BENCH-03 | BLOCKED | Common prediction/grid/manifest contracts exist, but feature-level coverage/provenance is absent and disconnected; exact rich-panel identity is not enforced. |
| BENCH-04 | SATISFIED | Five registered baseline classes, both tracks, common seeds, complete grids, stable hashes, and baseline/legacy tests pass. Rich-panel execution remains a plan-contract gap captured under BENCH-03/05. |
| BENCH-05 | BLOCKED | Shared seeds, paired deltas, uncertainty, and pure protocol exist, but canonical decisions bypass the gate and rich comparisons use the wrong fixture set. |

No orphaned Phase 09 requirements were found: BENCH-01 through BENCH-05 are claimed across the four plans and mapped to Phase 09 in `REQUIREMENTS.md`.

## Anti-Patterns and Coverage Gaps

| File | Line/area | Finding | Severity |
|---|---|---|---|
| `R/benchmark/runner.R` | `benchmark_runner_decisions()` | Hard-coded `decision = "retain_incumbent"`; protocol argument is not consumed. | BLOCKER |
| `R/benchmark/runner.R` | run manifest assembly | Contract flags including `feature_coverage_valid`, `seed_contract_valid`, and `network_free` are assigned `TRUE` rather than derived from validators. | BLOCKER for feature coverage; warning for already independently checked seed/network facts |
| `R/benchmark/runner.R` | feature coverage builder/validator | Renames aggregate panel output coverage as feature coverage and never checks prediction coverage IDs. | BLOCKER |
| `R/evaluation/benchmark_scores.R` | fixture-set validation | Requires the global registered fixture set for every model, conflicting with the frozen rich panel. | BLOCKER |
| `R/benchmark/contracts.R` | `validate_panel_prediction_coverage()` | Checks missing required rows but allows extra out-of-panel rows. | BLOCKER |
| Phase verification snippets | multiple plans | `test_file()` commands generally omit explicit failure propagation. | WARNING |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 09 production files. No Phase 10/11 challenger implementation was found; only generic challenger interfaces are present.

## Regression and Scope Checks

- Full suite passed, including dashboard, Phase 8 World Cup ledger/scoring/retrospective, legacy Euro benchmark, Elo, pipeline, and xG tests.
- `git diff 9323851^..HEAD` shows no Phase 09 modifications under `outputs/dashboard`, `outputs/evaluation/wc2026`, legacy Euro implementation files, or the protected Phase 8/dashboard regression tests.
- No regularized Poisson, Dixon-Coles/bivariate, random forest, socioeconomic, squad, or bookmaker challenger implementation was added.
- All 20 implementation/fix commits named by the summaries exist, including `5f4c013`.

## Commit 5f4c013 Finding

Commit `5f4c013` correctly fixes `promotion_contract_reasons()` to return `character()` when every contract passes, and the updated promotion unit suite passes. The fix is not applied to the canonical decision artifact because `benchmark_runner_decisions()` bypasses `promotion_veto_reasons()`/`evaluate_promotion()` entirely. Thus the pure service is fixed, but the end-to-end promotion path remains broken.

## Human Verification Still Required

These checks remain necessary after the blockers are fixed; they do not change the current `gaps_found` precedence.

1. **Historical correction source-attribution review**
   - Review all 72 correction rows against the two cited checked-local martj42 `goalscorers.csv`/`shootouts.csv` sources and decide whether this provenance is authoritative enough for the freeze.
   - Automated validation confirms schema, local artifact SHA-256, row hashes, URL/title/license presence, and fixture linkage, but cannot judge source authority.

2. **Pre-WC2026 governance sign-off**
   - After regenerating the bundle, confirm the committed protocol, model/panel/feature/seed registries, selected G, corrected promotion decisions, and checksum parents before any WC2026 label-opening workflow.

## Deferred-Phase Filter

None of the three gaps is deferred. Phases 10 and 11 require this harness as an upstream contract, and Phase 12 consumes its promotion rule; their roadmap goals do not promise to repair Phase 09 feature provenance, panel denominators, or runner-to-gate wiring.

## Gaps Summary and Next Action

Three related end-to-end gaps block the phase goal:

1. Replace aggregate-only `feature_coverage.csv` with the registered feature-level audit and wire/validate every prediction reference.
2. Enforce `panel_fixtures.csv` in prediction validation, scoring, calibration, and paired comparisons; the rich denominator must be 609, not 630.
3. Route canonical decisions through `evaluate_promotion()` with full score, uncertainty, breadth, regression, coverage, provenance, checksum, and reproducibility inputs; then regenerate the 962 MiB bundle and checksum graph.

Use the structured frontmatter gaps as input to `$gsd-plan-phase 09 --gaps`. Re-run the full failure-propagating suite, external checksums, and this goal-backward verification after closure.

---

_Verified: 2026-07-21T06:45:34Z_
_Verifier: the agent (gsd-verifier)_
