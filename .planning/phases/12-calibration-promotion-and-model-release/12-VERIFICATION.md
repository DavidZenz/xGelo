---
phase: 12-calibration-promotion-and-model-release
verified: 2026-08-12T07:57:05Z
status: gaps_found
score: "4/5 roadmap success criteria verified"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Dashboard and export code consume only the approved model contract, and model, pipeline, and presentation regression tests pass."
    status: partial
    reason: "Official targets and scripts are release-gated, but the exported dashboard build path can still run with release_root = NULL and raw home_model_path/away_model_path, so approved-release resolution is not the only dashboard/export authority."
    artifacts:
      - path: "R/visualization/worldcup_dashboard.R"
        issue: "dashboard_resolve_approved_release() returns NULL when release_root is NULL; build_worldcup_dashboard_data() then continues and passes raw model paths into forecast generation."
      - path: "tests/testthat/test_worldcup_dashboard.R"
        issue: "The dashboard export regression builds with temporary raw model RDS paths and no release_root/approved_release, proving the bypass remains accepted."
    missing:
      - "Require build_worldcup_dashboard_data()/build_worldcup_dashboard() production entry points to resolve a Phase 12 approved or incumbent-retained release before model loading, or split the legacy raw-model path into an explicitly non-production helper."
      - "Add a regression that missing, ambiguous, or unapproved release state fails before model loading or forecast generation."
---

# Phase 12: Calibration, Promotion, and Model Release Verification Report

**Phase Goal:** Freeze the candidate set, calibrate without outer-fold leakage, open the 2026 holdout once, and release only a challenger that clears the promotion rule.
**Verified:** 2026-08-12T07:57:05Z
**Status:** gaps_found
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Calibration is learned from inner out-of-fold predictions only, and raw versus calibrated probabilities are compared with identical proper scores. | VERIFIED | `R/calibration/inner_oof.R` rejects WC2026, future, mixed-identity, duplicate, and non-strict evidence rows. `R/calibration/probability_calibration.R` validates the freeze and recipe before `stats::optim`. `R/calibration/calibration_selection.R` scores raw/calibrated views on identical fixture/distribution identity. Focused Phase 12 tests passed. |
| 2 | Candidate implementations, settings, feature sets, calibration recipes, and promotion thresholds are frozen and checksummed before 2026 results are opened. | VERIFIED | `data/benchmark/phase12/freeze_manifest.csv` has 9 candidate rows, `G=40`, `sealed_before_final_labels`, and self/parent/threshold/recipe hashes. `calibration_recipe.json` locks `phase12_multiclass_temperature`, `stats::optim-L-BFGS-B`, support floors 60/10, seed 920012, and `G=40`. Fresh validation passed. |
| 3 | The final 2026 comparison is executed once; the incumbent remains production default unless a challenger satisfies every predeclared promotion condition. | VERIFIED | `R/release/final_evaluation.R` enforces a passed unopened preflight, exact label path/hash, `approved` state, immutable writes, and one opener state. Durable artifacts contain 104 copied labels, 104 predictions, 104/104 active coverage, 9 final manifest rows, and `labels_consumed = TRUE`. `promotion_report.csv` has 9 `evaluate_promotion` rows and selects `open_nb_incumbent` with `incumbent retained`. |
| 4 | The selected model is published as a versioned artifact with model card, benchmark report, data provenance, limitations, and reproducibility metadata. | VERIFIED | `outputs/releases/phase12-wc2026-incumbent-retained-v1` contains `model_contract.json`, model/calibrator RDS, freeze/final manifests, provenance, benchmark report, model card, `limitations.md`, `reproducibility.json`, and a hash-bearing 11-row release manifest. Fresh resolver returned `incumbent retained`, `open_nb_incumbent`, `raw_1x2`, `G=40`. Tempdir spot-check rejected a tampered contract and restored the accepted release after forced post-install validation failure. |
| 5 | Dashboard and export code consume only the approved model contract, and model, pipeline, and presentation regression tests pass. | FAILED | Official `_targets.R` and `scripts/update_worldcup_dashboard.R` are release-gated, and focused dashboard tests passed. However `build_worldcup_dashboard_data()` still defaults `release_root = NULL`, allows raw `home_model_path`/`away_model_path`, and the dashboard regression at `tests/testthat/test_worldcup_dashboard.R` builds with raw temporary RDS models and no approved release. The "only approved model contract" claim is therefore false for the exported dashboard/export API. |

**Score:** 4/5 roadmap success criteria verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `tests/testthat/test_phase12_*.R` | Five Phase 12 validation files | VERIFIED | All five exist and parsed; focused run completed with no failures. |
| `data/benchmark/phase12/freeze_manifest.csv` and `calibration_recipe.json` | Pre-fit freeze and recipe | VERIFIED | 9 candidates, `G=40`, sealed state, recipe hash, threshold hash, parent hashes. |
| `R/calibration/inner_oof.R`, `probability_calibration.R`, `calibration_selection.R` | Leakage-safe calibration and raw/calibrated gate | VERIFIED | Source and tests validate strict prior OOF, deterministic temperature scaling, raw fallback, unchanged scorelines, and shared scoring. |
| `R/release/final_fit.R`, `final_evaluation.R`, `promotion_report.R` | Final preflight, one-shot evaluation, promotion report | VERIFIED | Durable final-fit and final-evaluation manifests validate; 104/104 active fixtures scored; inherited evaluator used. |
| `outputs/releases/phase12-wc2026-incumbent-retained-v1` | Complete versioned release root | VERIFIED | Actual concrete release root resolves template `<release_id>` paths from the plans; bundle validates fresh. |
| `R/release/release_contract.R`, `R/visualization/worldcup_dashboard.R`, `_targets.R` | Approved consumer boundary | PARTIAL | Target/script path is wired to `resolve_phase12_approved_release()`, but exported dashboard build functions still allow raw model-path operation. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `freeze_manifest.csv` | Calibration fit/apply services | Freeze and recipe validation before optimizer | VERIFIED | `fit_phase12_1x2_calibrator()` validates freeze and recipe before `stats::optim`; CAL-01 tests passed. |
| Raw/calibrated predictions | Shared proper scoring | `compare_phase12_raw_calibrated()` | VERIFIED | Tests assert identical fixture coverage, unchanged distribution identity, and shared RPS/Brier/log-loss/calibration services. |
| Final preflight | Label opener | `phase12_open_final_labels()` | VERIFIED | Preflight failure keeps provider calls at 0; one-shot synthetic and durable final artifacts validate. |
| Promotion report | Phase 9 evaluator | `evaluate_promotion()` then `select_promoted_candidate()` | VERIFIED | 9 registered candidates evaluated; active challenger vetoed; incumbent retained. |
| Release root | Dashboard/export | `resolve_phase12_approved_release()` into `_targets.R` and update script | PARTIAL | Official target/script consumers are wired, but `build_worldcup_dashboard_data()` still permits raw model paths with no release. |

### Data-Flow Trace

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `calibration_gate.csv` | `primary_probability_view` | Inner OOF/calibrator artifacts and shared scoring | Yes | 9 rows, one scored `calibrated_1x2`, eight explicit `raw_1x2` no-score rows, all `G=40`. |
| `final_evaluation_manifest.csv` | Final labels/predictions/scores hashes and coverage | One-shot copied labels plus prediction/scoring artifacts | Yes | 9 rows; active `phase11_rf_dynamic_elo_open` has 104/104 coverage and consumed labels. |
| `promotion_report.csv` | `release_decision`, `selected_id`, gate values | Inherited promotion evaluator | Yes | 9 evaluator rows; release decision `incumbent retained`; selected `open_nb_incumbent`. |
| `release_manifest.csv` | Release identity and artifact hashes | Completed release bundle | Yes | 11 artifact rows; `labels_embedded = FALSE`; status `incumbent retained`; `raw_1x2`; `G=40`. |
| Dashboard payload | Release metadata and model pair | Approved resolver or raw model path fallback | Partial | Official production path uses resolver; exported builder can still bypass it. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Durable Phase 12 validators and resolver | `Rscript --vanilla -e 'source(...); validate_phase12_*(); resolve_phase12_approved_release("outputs/releases")'` | `VALIDATION_OK phase12-wc2026-incumbent-retained-v1 incumbent retained open_nb_incumbent raw_1x2 40` | PASS |
| Focused Phase 12 and dashboard tests | `Rscript --vanilla -e 'for (path in phase12 files plus test_worldcup_dashboard.R) testthat::test_file(path, stop_on_failure=TRUE, stop_on_warning=TRUE)'` | Completed all files with no failures or warnings | PASS |
| Release tamper and rollback behavior | Tempdir copy of release root; tamper contract; force post-install validator failure | `RELEASE_SPOTCHECK_OK`; tamper rejected, rollback restored accepted release | PASS |
| Dashboard approved-contract-only boundary | Source/test inspection and existing dashboard test | Raw model-path dashboard build still passes without release resolver | FAIL |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| Phase probes | `find scripts -path '*/tests/probe-*.sh' -type f` and phase PLAN/SUMMARY probe grep | No Phase 12 probe scripts declared | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| CAL-01 | 12-02 | Train probability calibration using inner OOF predictions without outer assessment tournament | SATISFIED | Strict chronology guards, freeze-gated fit, raw fallback, durable OOF/calibrator validation, focused tests. |
| CAL-02 | 12-03 | Compare raw and calibrated probabilities with same proper scores and report regressions | SATISFIED | Shared scoring/gate code, 9-row calibration gate, strict selection/veto tests. |
| PROMO-01 | 12-01 | Freeze candidates/settings/features/thresholds before final 2026 evaluation | SATISFIED | 9-row self-hashed freeze, recipe JSON, parent/protocol hashes, unopened guard. |
| PROMO-02 | 12-04, 12-05 | Execute final 2026 comparison once and retain incumbent unless challenger clears rule | SATISFIED | One-shot label copy, immutable manifests, 104/104 scoring, 9 evaluator rows, incumbent retained. |
| PROMO-03 | 12-06, 12-08, 12-07 | Publish approved model with reports and dashboard regressions | PARTIAL | Release bundle and official target/script wiring pass, but exported dashboard/export builder still allows raw model-path operation without approved release. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `R/visualization/worldcup_dashboard.R` | 2981-3052, 3130-3131 | Raw model-path fallback when no release is resolved | BLOCKER | Violates the approved-contract-only consumer criterion. |
| Phase 12 files | n/a | Debt markers | None | No unreferenced `TBD`, `FIXME`, or `XXX` markers found in modified Phase 12 source/test files. |
| `R/visualization/worldcup_dashboard.R` | multiple | `return(NULL)` / empty data-frame paths | Info | These are existing optional/empty-state branches, not stubs. |

### UAT Coverage

`12-UAT.md` is complete with 15/15 passed and no gaps. It covered dashboard UI, validation files, sealed-boundary scan, calibration gate, final preflight, one-shot evaluation/promotion, release bundle, approved consumer boundary, release installation/rollback, and freeze identity. The UAT supports visual and operator-facing confidence, but it does not override the code-level dashboard/export bypass found above.

### Human Verification Required

None currently. The completed UAT covers the human-facing checks, and the remaining issue is a code-level gap.

### Gaps Summary

Phase 12 achieved the calibration, freeze, one-shot final evaluation, incumbent-retained promotion decision, and complete versioned release bundle. The blocking gap is in the final consumer boundary: official targets and scripts resolve the accepted release, but the exported dashboard/export API still accepts raw model paths with no approved release. That means the roadmap's approved-contract-only consumer success criterion is not fully achieved.

---

_Verified: 2026-08-12T07:57:05Z_
_Verifier: the agent (gsd-verifier)_
