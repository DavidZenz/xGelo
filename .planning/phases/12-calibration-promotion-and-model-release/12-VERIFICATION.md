---
phase: 12-calibration-promotion-and-model-release
verified: 2026-08-13T08:30:44Z
status: passed
score: "5/5 must-haves verified"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "4/5 roadmap success criteria verified"
  gaps_closed:
    - "Trusted release topology, canonical artifact identities, and refreshed-hash path-swap rejection"
    - "Exact embedded promotion decision-token/evidence/selected-ID hashing"
    - "Freeze/final-evaluation cross-links, loaded identities, and calibrated dashboard consumer propagation"
  gaps_remaining: []
  regressions: []
---

# Phase 12: Calibration, Promotion, and Model Release Verification Report

**Phase Goal:** Freeze the candidate set, calibrate without outer-fold leakage, open the 2026 holdout once, and release only a challenger that clears the promotion rule.
**Verified:** 2026-08-13T08:30:44Z
**Status:** passed
**Re-verification:** Yes — fresh independent verification after plan 12-10

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Calibration is learned from inner out-of-fold predictions only, and raw versus calibrated probabilities are compared with identical proper scores. | ✓ VERIFIED | `R/calibration/inner_oof.R`, `R/calibration/probability_calibration.R`, and `R/calibration/calibration_selection.R` enforce freeze-gated prior-only calibration, explicit raw fallback, unchanged scoreline distributions, and shared scoring. The full suite passed `phase12_calibration` with 76 assertions and zero failures/warnings. |
| 2 | Candidate implementations, settings, feature sets, calibration recipes, and promotion thresholds are frozen and checksummed before 2026 results are opened. | ✓ VERIFIED | The durable freeze has 9 candidates, `selected_g=40`, `sealed_before_final_labels=TRUE`, recipe/protocol/parent/code/component hashes, and a freeze self-hash. `phase12_freeze` passed 29 assertions with zero failures/warnings. |
| 3 | The final 2026 comparison is executed once; the incumbent remains production default unless a challenger satisfies every predeclared promotion condition. | ✓ VERIFIED | The durable final manifest has 9 rows, one active scored candidate with 104 observed fixtures, all rows `labels_consumed=TRUE` and `holdout_state=consumed`, and the release decision is exactly `incumbent retained` with selected identity `open_nb_incumbent`. Final-evaluation and promotion suites passed 58 and 16 assertions. |
| 4 | The selected model is published as a versioned artifact with its model card, benchmark report, data provenance, limitations, and reproducibility metadata. | ✓ VERIFIED | `outputs/releases/phase12-wc2026-incumbent-retained-v1` contains the two model artifacts, contract, release/freeze/final manifests, provenance, benchmark report, model card, limitations, and reproducibility metadata. Fresh metadata-only and full validation passed; the loaded model/calibrator identities are both `open_nb_incumbent`. |
| 5 | Dashboard and export code consume only the approved model contract, and model, pipeline, and presentation regression tests pass. | ✓ VERIFIED | Release preflight/resolver and exported dashboard guards are wired in `R/release/release_contract.R` and `R/visualization/worldcup_dashboard.R`; `_targets.R:1065` and `scripts/update_worldcup_dashboard.R:358` retain direct resolver calls. Release and dashboard focused suites passed 44 and 473 assertions; the full suite passed 2,592 assertions, 0 failures, 0 warnings. |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified)

## PROMO-03 Boundary Verification

| Required boundary | Status | Evidence |
|---|---|---|
| Trusted-root topology and fresh metadata-only preflight | ✓ VERIFIED | `phase12_release_contract_manifest_candidates()` rejects symlink roots, root manifests, immediate-child release directories, and child manifests; candidate paths are normalized and contained before `validate_phase12_complete_release_bundle(..., load_models = FALSE)`. Fresh preflight returned no `model` or `calibrator` members. Independent temporary-fixture probes rejected a symlink root and symlink child. |
| Fresh resolver ordering and forged-handoff rejection | ✓ VERIFIED | `resolve_phase12_approved_release()` calls `preflight_phase12_approved_release()` on every invocation, compares trusted root/release root/pinned manifest and identity fields, then invokes full validation. An independent alternate-root handoff probe failed before loading; the focused release suite also passed the ordering regression. |
| Exact embedded decision hash semantics | ✓ VERIFIED | `phase12_release_contract_recompute_decision_sha256()` serializes candidate evidence with `utils::write.csv(..., row.names=FALSE, na="", quote=TRUE)` and hashes the exact raw decision token plus selected ID. A fresh process produced four distinct hashes for evidence, token, and selected-ID changes; invalid normalized token `approved` was rejected. The external final-evaluation `promotion_decision_sha256` remains separately validated as a uniform 64-hex provenance field. |
| Contract artifact identities and refreshed-hash path-swap rejection | ✓ VERIFIED | `R/release/release_bundle.R` requires canonical `model/approved_model.rds` and `model/calibrator.rds` identities, distinct one-to-one manifest rows, byte hashes, and `artifact_role = model` before any RDS load. The focused refreshed-hash swap regression passed. |
| Freeze/final-evaluation evidence links | ✓ VERIFIED | Complete-bundle validation requires `freeze_id`, freeze self-hash, G=40, final-evaluation `freeze_id`/freeze self-hash/track links, and uniform external promotion provenance. The retained fixture’s absent contract freeze self-hash is accepted only through its explicit raw-only compatibility branch; drift mutations fail in the focused release suite. |
| Loaded model/calibrator identities | ✓ VERIFIED | `phase12_release_validate_loaded_identity()` requires model identity and calibrator candidate/track/schema/status/distribution fields; the resolver repeats model/calibrator identity checks after loading. Fresh resolution loaded `model_id=open_nb_incumbent` and `candidate_id=open_nb_incumbent`; wrong identities fail in focused tests. |
| Calibrated match-to-group/stage/knockout flow with unchanged scorelines | ✓ VERIFIED | `forecast_dashboard_matches()` emits the calibrated per-match outcome view; `simulate_group_stage_dashboard()` uses it for calibrated points/ranking while retaining raw scoreline rows for goals; knockout routing applies calibrated regulation/tiebreak probabilities while retaining scoreline summaries; `build_worldcup_dashboard_data()` passes the view/calibrator through all consumers. The dashboard suite’s calibrated fixtures passed 473 assertions and explicitly checked changed 1X2/advancement values with unchanged scoreline/auxiliary fields. |
| Direct caller preservation and raw-authority rejection | ✓ VERIFIED | `_targets.R` and `scripts/update_worldcup_dashboard.R` still call `resolve_phase12_approved_release()` and contain no direct raw model-path assignment. Exported builders reject NULL release roots and caller-supplied raw/baseline authority before setup. |
| Durable output immutability | ✓ VERIFIED | Independent before/after SHA-256 inventories were identical: 289 `outputs/` files and 211 `data/` files, with `cmp` exit code 0 for both. Temporary adversarial fixtures were outside the accepted release root. |

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/release/release_contract.R` | Trusted topology, fresh preflight, exact decision identity, evidence authority, resolver identity checks | ✓ VERIFIED | Substantive implementation; fresh preflight and resolver probes passed. |
| `R/release/release_bundle.R` | Canonical contract paths, freeze/evaluation links, and loaded identity validation | ✓ VERIFIED | Metadata-only path is fail-closed; RDS reads occur only after metadata/hash checks. |
| `R/visualization/worldcup_dashboard.R` | Release-calibrator wiring across match/group/stage/knockout outputs | ✓ VERIFIED | Calibrated fixture changed derived outcome surfaces while preserving scoreline evidence. |
| `tests/testthat/test_phase12_release.R` | Temporary topology, handoff, hash, path, link, identity, and ordering regressions | ✓ VERIFIED | 44 focused assertions passed with warnings treated as failures. |
| `tests/testthat/test_worldcup_dashboard.R` | Calibrated consumer and retained-release/UI regressions | ✓ VERIFIED | 473 focused assertions passed with warnings treated as failures. |
| `outputs/releases/phase12-wc2026-incumbent-retained-v1` | Complete versioned release bundle | ✓ VERIFIED | 11-row release manifest and all required model, contract, evidence, report, provenance, limitations, and reproducibility files present and fresh-validated. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Trusted root/candidate paths | `preflight_phase12_approved_release()` | Symlink rejection plus normalized containment before metadata-only bundle validation | ✓ WIRED | `release_contract.R` topology functions and independent symlink probes. |
| `resolve_phase12_approved_release()` | `preflight_phase12_approved_release()` | Fresh preflight on each resolver call plus supplied-handoff comparison | ✓ WIRED | Source order and forged-handoff probe verified. |
| `model_contract.json` | Release manifest and `readRDS()` | Canonical paths, one-to-one rows, byte hashes, then loaded identity checks | ✓ WIRED | `release_bundle.R` validates metadata first and reads RDS only at lines 425–426. |
| Benchmark candidate evidence | Embedded decision identity | Canonical CSV bytes + exact raw decision token + selected ID | ✓ WIRED | Fresh hash sensitivity probe produced four distinct SHA-256 values. |
| Contract freeze identity | Freeze/final-evaluation manifests | `freeze_id`, `freeze_self_sha256`, track, and G=40 cross-links | ✓ WIRED | Valid retained fixture and drift regressions passed. |
| Resolver calibrator/primary view | Match/group/stage/knockout consumers | Explicit calibrated outcome view; raw scoreline distribution retained | ✓ WIRED | Dashboard source trace and calibrated match/group/knockout regressions passed. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Calibration gate | Raw/calibrated candidate-track metrics and primary view | Inner-OOF calibrator plus shared proper-score services | Yes; durable 9-row gate | ✓ FLOWING |
| Final-evaluation manifest | Labels, predictions, scores, coverage, promotion provenance | One-shot copied-label scorer and promotion evaluator | Yes; 9 rows, 104/104 active coverage | ✓ FLOWING |
| Release bundle | Model/calibrator, contract, evidence, reports, provenance | Versioned release publisher/installer | Yes; 11 manifest rows | ✓ FLOWING |
| Dashboard match payload | Per-match 1X2, outcome view, scoreline distributions | Resolver-returned models/calibrator and `forecast_dashboard_matches()` | Yes; 72 fixtures in valid dashboard payload tests | ✓ FLOWING |
| Group/stage/knockout payload | Points/ranking, advancement, bracket routes | Explicit outcome view plus unchanged raw scoreline evidence | Yes; 48 group rows and bracket regressions pass | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Release focused regressions | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase12_release.R", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | 44 pass, 0 fail, 0 warn | ✓ PASS |
| Dashboard focused regressions | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_dashboard.R", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | 473 pass, 0 fail, 0 warn | ✓ PASS |
| Full repository suite | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", stop_on_failure=TRUE, stop_on_warning=TRUE)'` | 2,592 pass, 0 fail, 0 warn | ✓ PASS |
| Fresh metadata-only/full release validation | Fresh R process calling preflight, `validate_phase12_complete_release_bundle(..., load_models=FALSE/TRUE)`, and resolver | No model members in metadata preflight; retained release resolved; loaded identities match | ✓ PASS |
| Decision identity sensitivity | Fresh R process with evidence, raw decision token, and selected-ID mutations | Four distinct valid 64-hex hashes; invalid token rejected | ✓ PASS |
| Symlink topology and forged handoff | Fresh temporary release roots with symlink root/child and alternate preflight handoff | All rejected before resolver model loading | ✓ PASS |
| Durable immutability | SHA-256 inventory of `outputs/` and `data/` before/after verification | 289/289 and 211/211 entries byte-identical | ✓ PASS |

## Probe Execution

No conventional `scripts/*/tests/probe-*.sh` probe was declared or found for Phase 12. The fresh-process probes above were run directly, including topology, handoff, hash, metadata-only, full-resolution, and immutability checks.

## Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
|---|---|---|---|---|
| CAL-01 | 12-02 | Train probability calibration from inner OOF without outer assessment leakage | ✓ SATISFIED | Freeze-gated chronology/holdout tests and 76 passing calibration assertions. |
| CAL-02 | 12-03 | Compare raw/calibrated probabilities with identical proper scores and report regressions | ✓ SATISFIED | Shared scoring and durable calibration gate; included in the passing full suite. |
| PROMO-01 | 12-01 | Freeze candidates/settings/features/thresholds before final evaluation | ✓ SATISFIED | 9-row self-hashed freeze, recipe/protocol/parent identities, and 29 passing freeze assertions. |
| PROMO-02 | 12-04, 12-05 | Execute final comparison once and retain incumbent unless challenger clears the rule | ✓ SATISFIED | One-shot preflight/opener contracts, consumed 9-row final manifest, 104/104 active coverage, incumbent-retained promotion, and 58+16 passing assertions. |
| PROMO-03 | 12-06, 12-07, 12-08, 12-09, 12-10 | Publish versioned approved/retained artifact with reports, provenance, limitations, reproducibility, and dashboard regressions | ✓ SATISFIED | Complete release bundle, fail-closed metadata/resolver boundary, exact decision/freeze identities, calibrated consumer flow, direct caller preservation, focused tests, full suite, and immutable-output check. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `R/visualization/worldcup_dashboard.R` | 3640, 3672, 3675, 3832, 4199 | `return null`/empty-array branches in embedded dashboard JavaScript | Info | Normal UI lookup/rendering fallbacks; not a product stub and tests exercise the UI surface. |
| Phase 12-10 source/test files | n/a | Unreferenced `TBD`, `FIXME`, or `XXX` markers | None found | No debt-marker blocker. |

## Human Verification Required

None. Visual and UI regression behavior is covered by the existing automated presentation suite; the release-integrity and calibrated data-flow claims were directly exercised with temporary fixtures and fresh-process checks. No uncertain truth remains.

## Gaps Summary

No gaps remain. The two stale pre-12-10 blockers are closed in the live code: refreshed metadata cannot swap the canonical model/calibrator identities, and the embedded decision identity binds canonical evidence, the exact raw release-decision token, and selected model ID. The accepted incumbent-retained release remains usable, calibrated consumer wiring is explicit and scoreline-preserving, direct resolver callers remain release-first, all focused/full tests pass with warnings treated as failures, and durable `outputs/`/`data/` inventories are unchanged.

---

_Verified: 2026-08-13T08:30:44Z_
_Verifier: the agent (gsd-verifier)_
