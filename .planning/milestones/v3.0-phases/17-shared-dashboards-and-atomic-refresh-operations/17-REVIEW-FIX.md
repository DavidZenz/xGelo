---
phase: 17-shared-dashboards-and-atomic-refresh-operations
fixed_at: 2026-08-25T00:00:00Z
review_path: .planning/phases/17-shared-dashboards-and-atomic-refresh-operations/17-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 17: Code Review Fix Report

**Fixed at:** 2026-08-25T00:00:00Z  
**Source review:** `.planning/phases/17-shared-dashboards-and-atomic-refresh-operations/17-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 9
- Fixed: 9
- Skipped: 0

## Fixed Issues

### CR-01: Production refresh publishes fixture data instead of accepted competition outputs

**Files modified:** `scripts/refresh_competition_dashboards.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `6cf143f`  
**Applied fix:** Fixture bundles require explicit dry-run `--fixture-mode`; normal refresh requires a validated provider and rejects missing/untrusted provider output. **Status:** fixed: requires human verification of the production provider integration.

### CR-02: Regression gate always invokes the replay script with the wrong arguments

**Files modified:** `scripts/refresh_competition_dashboards.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `6cf143f`  
**Applied fix:** Child replay invocation now passes script path, scalar `--edition-id`, and `--replay-check` as separate arguments; an injectable runner test asserts propagation.

### CR-03: Read-back failure leaves the new publication live

**Files modified:** `R/dashboard/publication.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `a8c411d`  
**Applied fix:** Promotion keeps the incumbent backup until read-back commits, and restores incumbent bytes or absence after any post-promotion failure. **Status:** fixed: requires human verification of filesystem rollback behavior.

### CR-04: Hourly launchd job bypasses Git publication

**Files modified:** `scripts/com.xgelo.competition-dashboards.plist`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `6cf143f`  
**Applied fix:** The installed LaunchAgent now invokes the absolute Git publication wrapper, with a focused plist assertion.

### CR-05: Callback gates are observational, not fail-closed validation gates

**Files modified:** `scripts/refresh_competition_dashboards.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `6cf143f`  
**Applied fix:** Gate callbacks have a typed `list(valid=TRUE/FALSE)` contract, exactly one alias/label implementation is dispatched, and false/invalid/error results fail closed. **Status:** fixed: requires human verification of real Phase 13-16 callback wiring.

### WR-01: Browser gate does not perform browser or viewport testing

**Files modified:** `scripts/refresh_competition_dashboards.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `6cf143f`  
**Applied fix:** The gate requires an automated WebDriver runner, executes both routes at both declared viewports, validates typed runner results, and fails closed when unavailable. **Status:** fixed: requires human verification with Safari/WebDriver.

### WR-02: First publication fails when the public root is an empty directory

**Files modified:** `R/dashboard/publication.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `a8c411d`  
**Applied fix:** Empty owned destinations are removed before candidate rename; first publish and envelope validation are covered.

### WR-03: Disabling the legacy plist does not unload an already loaded LaunchAgent

**Files modified:** `scripts/install_competition_dashboards.sh`, `README.md`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `1d48f5f`  
**Applied fix:** Installation bootouts the legacy label, disables it, bootstraps the new label, and verifies launchd state.

### WR-04: Payload validator accepts a vector-valued edition identifier

**Files modified:** `R/dashboard/payload_contract.R`, `tests/testthat/test_phase17_dashboards.R`  
**Commit:** `a8c411d`  
**Applied fix:** Payload validation requires one non-empty registered scalar `edition_id`.

## Skipped Issues

None.

---

_Fixed: 2026-08-25T00:00:00Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
