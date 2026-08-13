---
phase: 12-calibration-promotion-and-model-release
reviewed: 2026-08-13T06:35:47Z
depth: deep
files_reviewed: 6
files_reviewed_list:
  - R/release/release_contract.R
  - R/release/release_bundle.R
  - R/release/release_install.R
  - R/visualization/worldcup_dashboard.R
  - tests/testthat/test_phase12_release.R
  - tests/testthat/test_worldcup_dashboard.R
findings:
  critical: 5
  warning: 2
  info: 0
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-08-13T06:35:47Z  
**Depth:** deep  
**Files Reviewed:** 6  
**Status:** issues_found

## Summary

The gap-closure changes close the former raw-path dashboard bypass for the ordinary valid fixture, but the release boundary is not yet safe to ship. The metadata preflight can escape its trusted root through symlinks, the resolver accepts an unverified caller-supplied preflight object, and the embedded promotion identity is not recomputed with the decision status and selected model. In addition, a calibrated release is advertised in dashboard metadata while its calibrator is never applied to match or knockout probabilities. The focused tests pass, but do not cover these paths.

## Critical Issues

### CR-01: Symlinked release candidates escape the trusted root

**Classification:** BLOCKER  
**File:** `R/release/release_contract.R:21-27, 142-147`

**Issue:** Candidate discovery builds paths from immediate child directories, then line 144 calls `normalizePath()` on the candidate. A child directory or `release_manifest.csv` symlink can therefore resolve outside `trusted_root`; `release_root <- dirname(pinned)` is never checked against the normalized trusted-root prefix. A trusted root containing a symlink to an attacker-controlled valid bundle is accepted, and the resolver then loads that external bundle. This defeats the stated trusted-root release boundary.

**Fix:** Normalize each candidate and reject it unless the normalized manifest path is the trusted-root manifest or starts with `paste0(trusted_root, "/")`; also reject a normalized release directory outside the root before validation. Prefer `file.info(... )$isdir`/`Sys.readlink` checks so the candidate topology itself cannot be supplied by a symlink.

### CR-02: The supposedly internal preflight handoff is forgeable

**Classification:** BLOCKER  
**File:** `R/release/release_contract.R:182-188`

**Issue:** Any caller can pass `validated_preflight = list(release_root = ..., release_manifest_path = ...)`. The resolver only checks that those two fields exist, ignores `trusted_root`, and skips `preflight_phase12_approved_release()`. Thus `resolve_phase12_approved_release(trusted_root = safe_root, validated_preflight = forged_object)` loads a release from an arbitrary directory. The dashboard’s wrapper performs a real preflight, but the exported resolver is also used directly by `_targets.R` and `scripts/update_worldcup_dashboard.R`, and the public argument is not an actual trust token.

**Fix:** Do not trust a caller-created list. Either make the handoff an unforgeable private token/closure and verify it, or always re-run preflight in the resolver. In either case require the handoff’s normalized trusted root, release root, and manifest path to match the current `trusted_root` and the sole candidate before any full validation or `readRDS()`.

### CR-03: Embedded promotion identity is not recomputed

**Classification:** BLOCKER  
**File:** `R/release/release_contract.R:94-100, 119-121`

**Issue:** `phase12_release_contract_recompute_decision_sha256()` accepts `status` and `selected_id` but never uses them; it hashes only a temporary CSV of `evidence`. Consequently, changing the report decision or selected model leaves the “recomputed” value unchanged. The preflight then compares that evidence-only digest to `provenance$decision_evidence_sha256`, and merely compares the report’s declared decision hash to the manifest’s declared hash. A self-consistent forged bundle can therefore pass without proving the embedded decision identity described in the plan. This is directly observable: the helper returns the same digest for the live evidence with both `"incumbent retained"/open_nb_incumbent` and `"approved"/forged`.

**Fix:** Reuse the exact algorithm in `R/release/promotion_report.R`: serialize the candidate-evidence rows, append the normalized release decision and selected ID, hash that combined material, and compare the recomputed value independently with the report, release manifest, contract, and provenance decision identity. Keep the separate final-evaluation external-file hash check unchanged.

### CR-04: Calibrated releases are reported but never calibrated

**Classification:** BLOCKER  
**File:** `R/visualization/worldcup_dashboard.R:3094-3100, 3140-3151, 3173-3190`

**Issue:** The resolver returns both `model` and `calibrator`, but the dashboard integration copies only the model’s home/away components into `extra_args`. Neither `forecast_dashboard_matches()` nor the knockout route estimator receives or applies the calibrator. For a valid release whose contract says `primary_probability_view = calibrated_1x2`, the generated match, group, stage, and bracket probabilities remain raw while the payload and UI label them as calibrated. This is a release-contract correctness failure, not just missing metadata.

**Fix:** Thread the resolver-returned calibrator and primary view through match and knockout probability generation, applying calibration only to derived 1X2 probabilities while leaving the fitted score distribution unchanged. Add a calibrated fixture that asserts the exported probabilities differ from raw output according to the release calibrator; alternatively reject calibrated releases until the consumer supports them.

### CR-05: Freeze identity is not bound across the contract and evaluation evidence

**Classification:** BLOCKER  
**File:** `R/release/release_bundle.R:334-338`; `R/release/release_contract.R:126-131`

**Issue:** `freeze_id` is a release-manifest field, but it is not required or compared in the model contract identity check. Approved-candidate validation filters the freeze manifest by the manifest’s `freeze_id`, yet filters final-evaluation evidence only by candidate and track, never by `freeze_id`. A bundle can therefore carry a contract with a missing/different freeze identity or pair an eligible candidate from one freeze with scored evidence from another and still pass metadata preflight.

**Fix:** Require scalar `contract$freeze_id` and require it to equal the release manifest’s freeze ID. Require the selected freeze row and final-evaluation row to have exactly that same freeze ID (and validate the expected final-evaluation schema before filtering).

## Warnings

### WR-01: Missing model identity fields are accepted after loading

**Classification:** WARNING  
**File:** `R/release/release_bundle.R:380-386`; `R/release/release_contract.R:193-194`

**Issue:** The full resolver checks model and calibrator identity only when `$model_id` or `$candidate_id` is non-NULL. An otherwise hash-valid release containing an object without those fields is accepted and returned to the dashboard, where it can fail later during prediction or silently lose the selected-model binding.

**Fix:** Require the model object’s identity to equal `contract$selected_model_id` and require the calibrator identity when a calibrator is used. If a legacy object shape must remain supported, validate its concrete class/shape with an explicit compatibility adapter rather than treating missing identity as success.

### WR-02: Regression coverage does not match the claimed gap closure

**Classification:** WARNING  
**File:** `tests/testthat/test_phase12_release.R:135-190`; `tests/testthat/test_worldcup_dashboard.R:52-62`

**Issue:** The added tests cover one incumbent-retained fixture, topology ambiguity, three metadata mutations, invalid model bytes, and NULL-root/helper checks. They do not test symlink escape, forged `validated_preflight`, decision-hash status/selected-ID binding, approved-candidate authority, freeze cross-linking, calibrated probability application, raw-argument rejection through both exported builders, or the promised `readRDS()`/forecast call spies. The passing 21-assertion release suite therefore does not protect the main release-boundary claims in `12-09-PLAN.md`.

**Fix:** Add isolated temporary-bundle regressions for each boundary, including an approved fixture and a calibrator that changes 1X2 output. Spy on `readRDS()`, `forecast_dashboard_matches()`, and the resolver to assert ordering, and include symlink and forged-handoff cases before accepting the gap closure.

---

_Reviewed: 2026-08-13T06:35:47Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_
