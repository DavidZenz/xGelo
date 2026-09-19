---
phase: 17-shared-dashboards-and-atomic-refresh-operations
plan: 04
subsystem: dashboard-operations
tags: [r, bash, macos, launchd, safari, git, testthat]
requires:
  - phase: 17-03
    provides: Atomic cross-edition batch coordinator, shared routes, envelope, and read-back validation.
provides:
  - One absolute hourly competition-dashboard LaunchAgent and explicitly disabled legacy scheduler plist.
  - Automated-only Safari 26.5.2 capability and desktop/mobile DOM/ARIA gate.
  - Bash 3-compatible exact Git allowlist publication wrapper with clean/upstream preflight and no-retry push failure.
affects: [Phase 17 release operations, hourly dashboard refresh]
tech-stack:
  added: []
  patterns: [launchd user agent, pinned Safari WebDriver, provider-backed Git allowlist, bounded dry-run]
key-files:
  created:
    - scripts/com.xgelo.competition-dashboards.plist
    - scripts/auto_update_competition_dashboards.sh
  modified:
    - scripts/com.xgelo.dashboard-update.plist
    - scripts/refresh_competition_dashboards.R
    - tests/testthat/test_phase17_dashboards.R
decisions:
  - One `com.xgelo.competition-dashboards` LaunchAgent owns the hourly refresh; the legacy World Cup label is disabled and must be booted out before installation.
  - Safari automation is pinned to `/System/Cryptexes/App/usr/bin/safaridriver` and version `26.5.2`; unavailable, disabled, mismatched, DOM, or viewport checks fail closed.
  - Git publication consumes `phase17_expected_git_allowlist()` through the explicit R emission flag and performs no broad add, force push, retry, or secret-bearing logging.
metrics:
  duration: approximately 2 hours including required regressions
  completed: 2026-08-25
  tasks: 2
status: complete
requirements-completed: [OPS-01, OPS-03, OPS-04, OPS-05]
---

# Phase 17 Plan 04: Safari, Launchd, and Git Publication Summary

**The final Phase 17 operations layer now runs one bounded hourly coordinator with pinned automated Safari checks and exact allowlisted Git publication.**

## Accomplishments

- Added the absolute-path hourly `com.xgelo.competition-dashboards` LaunchAgent with explicit working directory and logs; marked the old `com.xgelo.dashboard-update` plist disabled.
- Added captured launchctl assertions for bootout, disable, bootstrap, print, and print-disabled without mutating the live user domain.
- Enforced Safari WebDriver path/version/automated-only status and generated-route DOM/ARIA checks at named desktop and mobile viewports.
- Added the exact allowlist emission and Bash 3-compatible wrapper. Dirty or diverged repositories stop before staging; staged paths, size limits, final preflight, commit, and push failure are fail-closed.
- Production coordinator traces browser status, regression status, promotion, read-back, and final Git preflight; `--dry-run --skip-git` remains bounded and non-mutating.

## Task Commits

1. **Task 1: Establish and validate the automated-only Safari and launchd capability policy** - `9bb3fea`
2. **Task 2: Add regression gate and exact allowlist Git publication** - `6e77a60`
3. **Task 2 follow-up: Bash 3 compatibility fix required by macOS launchd** - `db53068`

## Verification

- `plutil -lint` for both plists: PASS.
- Focused launchd/Safari/browser/scheduler selector: PASS.
- Focused regression/Git/allowlist/push/no-mutation selector: PASS.
- Full `tests/testthat/test_phase17_dashboards.R`: PASS; one expected temporary-repository warning for absent upstream.
- Bounded `./scripts/auto_update_competition_dashboards.sh --dry-run`: PASS; public dashboard bytes unchanged.
- Phase 13 publication transaction, integration, and refresh-failure suites: PASS.
- Phase 15 Nations League and production suites: PASS.
- Phase 16 EURO qualifying suite: PASS.
- Exact planned child replay command: BLOCKED before replay because the existing CLI requires `--edition-id`.
- Phase 13 publication hashes and manifests: BLOCKED by pre-existing 156-fixture/zero-length normalized-column fixture-seed errors.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced unsupported Bash `mapfile` usage**
- **Found during:** bounded wrapper verification
- **Issue:** macOS system Bash does not provide `mapfile`, so the wrapper exited before the refresh CLI.
- **Fix:** Used Bash 3-compatible `while read` array population for allowlist and staged paths.
- **Files modified:** `scripts/auto_update_competition_dashboards.sh`
- **Commit:** `db53068`

**2. [Rule 3 - Blocking test harness] Added named operational selectors and temporary Git/launchctl fixtures**
- **Found during:** acceptance-criteria verification
- **Issue:** The plan selectors and exact policy surfaces were not present in the earlier Wave 0 tests.
- **Fix:** Added named launchd, Safari, browser, scheduler, regression, Git, allowlist, push-failure, and no-mutation checks.
- **Files modified:** `tests/testthat/test_phase17_dashboards.R`
- **Commit:** `9bb3fea`, `6e77a60`

## Deferred Issues

- Phase 13 publication hashes/manifests retain their pre-existing fixture-seed shape failure; recorded in `deferred-items.md` and the cross-phase WINDOWS ledger when available.
- The exact Phase 17 replay child invocation remains incompatible with the existing required `--edition-id` CLI argument; recorded in `deferred-items.md` and the cross-phase WINDOWS ledger when available.
- Live operator installation/bootstrap/bootout remains manual verification per plan; tests use only reversible captured launchctl calls.
- The WINDOWS append helper was attempted for both blockers but refused because the existing ledger frontmatter counts disagree with its entries; the ledger was left untouched to preserve unrelated planning state.

## Known Stubs

None in the files modified by this plan.

## Self-Check: PASSED

- Declared scheduler, wrapper, coordinator, and test files exist.
- Task commits `9bb3fea`, `6e77a60`, and `db53068` exist in Git history.
- Required focused selectors, full Phase 17 suite, plist lint, bounded dry-run, and available focused regressions were run.

---
*Phase: 17-shared-dashboards-and-atomic-refresh-operations*
*Completed: 2026-08-25*
