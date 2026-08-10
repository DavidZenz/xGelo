---
phase: 11-hybrid-ml-and-contextual-priors
reviewed: 2026-08-10T07:35:57Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - tests/testthat/test_hybrid_context_features.R
  - .planning/phases/11-hybrid-ml-and-contextual-priors/11-OUTCOME-AMENDMENT.md
findings:
  critical: 0
  warning: 5
  info: 0
  total: 5
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-08-10T07:35:57Z  
**Depth:** standard  
**Files Reviewed:** 2  
**Status:** issues_found

## Summary

The prior two blocking findings are resolved. The amendment now records the
explicit developer approval and binds the current eligibility audit to exact
input hashes while keeping the historical performance bundle separate. The
focused context test and complete suite pass; five non-blocking test-quality
warnings remain for future maintenance.

## Resolved Blockers

### CR-01: Blocking acceptance was attributed to auto-mode instead of an explicit developer decision — RESOLVED

**Classification:** RESOLVED BLOCKER  
**File:** `/Users/davidzenz/R/xGelo/.planning/phases/11-hybrid-ml-and-contextual-priors/11-OUTCOME-AMENDMENT.md:4-20`

**Resolution:** The developer explicitly selected `accept-inactivity-with-review-pending` in this task. The amendment now records `decision_basis: explicit-developer-approval`, `approved_at`, and the research-only boundary; it does not open WC2026 or grant Phase 12 promotion authority.

### CR-02: The accepted outcome is not bound to one immutable evidence bundle — RESOLVED

**Classification:** RESOLVED BLOCKER  
**File:** `/Users/davidzenz/R/xGelo/.planning/phases/11-hybrid-ml-and-contextual-priors/11-OUTCOME-AMENDMENT.md:29-40,75-103,162-168`

**Resolution:** The amendment now identifies the historical bundle source commit and Git object identities, records SHA-256 values for every local audit input, labels current output hashes as uncommitted diagnostics, and explicitly stores the current conclusion as a separate immutable audit artifact. No regenerated output is treated as a new performance bundle.

## Warnings

### WR-01: “Verification Commands” contains no reproducible commands — RESOLVED

**Classification:** RESOLVED WARNING  
**File:** `/Users/davidzenz/R/xGelo/.planning/phases/11-hybrid-ml-and-contextual-priors/11-OUTCOME-AMENDMENT.md:162-168`

**Resolution:** The amendment now contains replayable `Rscript --vanilla` commands for panel/candidate assertions, structural cutoff reproduction, and route coverage, together with the input SHA-256 table. All three commands passed on the recorded local inputs.

### WR-02: Ablation membership is tested, but candidate-to-removed-feature mapping is not

**Classification:** WARNING  
**File:** `/Users/davidzenz/R/xGelo/tests/testthat/test_hybrid_context_features.R:82-98`

**Issue:** The test checks the ablation candidate IDs as a set and checks `removed_feature_id` as a separate positional vector. A registry row can therefore retain the expected global sets while pairing a drop-host candidate with the wrong removed feature, and this test would not detect the semantic mismatch.

**Fix:** Build an expected named mapping from every candidate ID to its removed feature and compare it after matching by `candidate_id`; also assert the corresponding feature-set/base-candidate metadata.

### WR-03: The synthetic runner test permits partial or duplicated candidate execution

**Classification:** WARNING  
**File:** `/Users/davidzenz/R/xGelo/tests/testthat/test_hybrid_context_features.R:159-175`

**Issue:** The test asserts only the aggregate prediction/distribution row counts and the set of evidence IDs. It does not require each of the six context candidates to be `active`/`scored` or to contribute exactly two predictions and `2 * 41 * 41` distributions. A regression that makes some candidates inactive while another candidate emits duplicated rows can satisfy these aggregate assertions.

**Fix:** Group predictions, distributions, and candidate evidence by candidate ID and assert per-candidate status and exact row counts, including the expected `removed_feature_id` for each ablation.

### WR-04: Context tests do not verify feature semantics or the missing-route path

**Classification:** WARNING  
**File:** `/Users/davidzenz/R/xGelo/tests/testthat/test_hybrid_context_features.R:21-45,48-64`

**Issue:** The “evidence” test checks finiteness, positivity, set membership, and chronology, but never checks the expected signed host values, neutral values, exact rest/travel values, source identifiers, parent hashes, or fixture-to-stage mapping. The rejection test removes the current venue/host/team metadata, so it does not exercise the missing prior location or missing centroid route that actually makes `travel_km` ineligible. Incorrect feature derivation or fallback behavior could remain green.

**Fix:** Assert fixture-keyed expected values and provenance companions, then independently remove a prior venue location and a centroid row and assert strict common-panel rejection with the intended travel-specific reason.

### WR-05: The claimed adapter allow-list coverage is tautological

**Classification:** WARNING  
**File:** `/Users/davidzenz/R/xGelo/tests/testthat/test_hybrid_context_features.R:8-10,79-80`

**Issue:** The comment says the registry test covers the adapter candidate allow-list, but `hybrid_phase11_candidate_ids(protocol)` simply returns `protocol$model_registry$candidate_id`. Comparing it with the same registry-derived expected set is not an independent adapter-dispatch check and will not detect an adapter acceptance/dispatch mismatch.

**Fix:** Exercise the adapter registration/dispatch boundary for every expected candidate, asserting active behavior for synthetic-eligible candidates and explicit inactive reasons for the xG and structural candidates, or validate an independently defined allow-list against the registry.

---

_Reviewed: 2026-08-10T07:35:57Z_  
_Reviewer: the agent (gsd-code-reviewer)  
_Depth: standard_
