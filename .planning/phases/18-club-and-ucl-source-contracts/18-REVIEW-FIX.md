---
phase: 18
fixed_at: 2026-09-20T16:55:00Z
review_path: .planning/phases/18-club-and-ucl-source-contracts/18-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Fixed at:** 2026-09-20T16:55:00Z
**Source review:** `.planning/phases/18-club-and-ucl-source-contracts/18-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope: 10
- Fixed: 10
- Skipped: 0
- Authoritative verification: `PHASE18_GATE_OK` (8 files, 142 tests, 840 assertions)

## Fixed Issues

### CR-NEW-01: Schema fingerprints do not fingerprint schema types or cardinality

**Files modified:** `R/competition/football_data_org_adapter.R`, `tests/testthat/test_phase18_football_data_adapter.R`
**Commit:** cb48d22
**Applied fix:** Canonical full-tree typed/cardinality fingerprints cover every JSON node and array element.

### CR-NEW-02: Owner terms approval accepts empty and unrelated scope

**Files modified:** `R/competition/ucl_source_acceptance.R`, `tests/testthat/test_phase18_source_acceptance.R`
**Commit:** 801228a
**Applied fix:** Required trusted provider/application scope and nonblank human authority; manifests retain fixed provider identity.

### CR-NEW-03: Real adapter output cannot be consumed by the bundle builder

**Files modified:** `R/competition/football_data_org_adapter.R`, `tests/testthat/test_phase18_football_data_adapter.R`
**Commit:** 18b05db
**Applied fix:** Adapter emits the canonical acceptance fingerprint schema and passes unchanged through bundle/candidate validation.

### CR-NEW-04: Club identity registries are not published atomically

**Files modified:** `R/club/identity.R`, `R/club/identity_bootstrap.R`, `tests/testthat/test_phase18_club_identity.R`
**Commit:** 17ed5af
**Applied fix:** Immutable registry generations are selected by one self-hashed atomic pointer; boundary faults preserve the incumbent.

### CR-NEW-05: Refresh reports failure after accepted pointer commit

**Files modified:** `R/competition/ucl_source_refresh.R`, `tests/testthat/test_phase18_refresh_failure.R`
**Commit:** 489caaf
**Applied fix:** Post-commit hooks are non-authoritative notifications and committed results always reflect durable state.

### CR-NEW-06: Provider-exit approval accepts malformed compliance evidence

**Files modified:** `R/competition/ucl_source_refresh.R`, `tests/testthat/test_phase18_refresh_failure.R`
**Commit:** 8d7eab6
**Applied fix:** Exact schema, strict booleans/time/text/hashes, and incumbent terms evidence are required before mutation.

### WR-NEW-01: Manual source review accepts invalid audit metadata

**Files modified:** `R/competition/ucl_source_acceptance.R`, `R/competition/ucl_source_bundle.R`, `R/competition/ucl_source_refresh.R`, `tests/testthat/test_phase18_source_bundle.R`, `tests/testthat/test_phase18_refresh_failure.R`
**Commit:** a7958dc
**Applied fix:** Shared human-authority validation rejects placeholder identities, malformed UTC, and future manual reviews.

### WR-NEW-02: Acceptance contains shadowed runtime definitions

**Files modified:** `R/competition/ucl_source_acceptance.R`, `tests/testthat/test_phase18_source_acceptance.R`
**Commit:** 5e3942f
**Applied fix:** Legacy v1 definitions have explicit migration names and an AST gate prevents duplicate runtime symbols.

### WR-NEW-03: Retryable transport exceptions lose retry semantics

**Files modified:** `R/competition/football_data_org_adapter.R`, `tests/testthat/test_phase18_football_data_adapter.R`
**Commit:** 850626a
**Applied fix:** Trusted transient conditions retain a sanitized retry marker with bounded backoff and attempt accounting.

### WR-NEW-04: Club overlap grouping has delimiter collisions

**Files modified:** `R/club/identity.R`, `tests/testthat/test_phase18_club_identity.R`
**Commit:** 93d7ceb
**Applied fix:** Canonical-v2 tuple hashes replace delimiter-concatenated identity keys.

## Additional Regression Fix

**Files modified:** `R/competition/ucl_source_refresh.R`, `tests/testthat/test_phase18_refresh_failure.R`
**Commit:** 4d0c86b
**Applied fix:** Preserved the established provider-exit classification for non-provider incumbents while keeping strict review validation before provider mutation.

---

_Fixed: 2026-09-20T16:55:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
