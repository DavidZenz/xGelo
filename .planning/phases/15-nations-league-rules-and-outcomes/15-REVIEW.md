---
phase: 15-nations-league-rules-and-outcomes
reviewed: 2026-08-22T13:59:42Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - R/competition/state_bundle.R
  - tests/testthat/test_phase14_plan18_transaction_probe.R
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-22T13:59:42Z  
**Depth:** standard  
**Files Reviewed:** 2  
**Commit:** `ad4e24c1c508f2405b59c61c790f05265371e53b`  
**Status:** issues_found

## Summary

The commit preserves the exact 11-artifact Phase 14 inventory for in-memory candidates and leaves the existing artifact hash, parent-hash, manifest, and lineage checks in place. The focused Phase 14 transaction probe passes. However, the durable validator broadens the file allowlist to every descendant under `outcomes/`, rather than the registered Phase 15 nine-file outcomes inventory, so an arbitrary unvalidated file can be admitted to the bundle.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Arbitrary files under `outcomes/` bypass the registered inventory boundary

**File:** `R/competition/state_bundle.R:1682-1684`

**Classification:** BLOCKER

**Issue:** `unexpected` excludes every path beginning with `outcomes/`, without comparing those paths against the registered Phase 15 outcomes inventory. Consequently, `outcomes/arbitrary-extra.csv` or an arbitrary nested descendant is accepted by `phase14_validate_competition_state_bundle()` even though it is not registered and is never read, hashed, or covered by a manifest. A temporary-copy reproduction with that extra file returned `TRUE`. The new regression test only places an extra at the state-bundle root (`tests/testthat/test_phase14_plan18_transaction_probe.R:197-203`), so it does not catch this compatibility-boundary regression.

**Fix:** Obtain the registered outcomes inventory from the Phase 15 registration contract and reject any `outcomes/` path outside it, for example by comparing `sort(relative[startsWith(relative, "outcomes/")])` with the registered nine-file paths using `setequal()` (or by calling the Phase 15 registered-root/inventory validator). Add a test that creates `outcomes/arbitrary-extra.csv` and an arbitrary nested descendant and expects the durable Phase 14 validator to error, while the exact registered nine-file sibling continues to pass.

## Verification

The focused test file `tests/testthat/test_phase14_plan18_transaction_probe.R` completed successfully with 2 passing tests and 0 failures. The expected Phase 14 inventory contains exactly 11 paths. Existing validation still recomputes the 11-artifact content hashes and parent hashes before accepting a durable bundle.

---

_Reviewed: 2026-08-22T13:59:42Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
