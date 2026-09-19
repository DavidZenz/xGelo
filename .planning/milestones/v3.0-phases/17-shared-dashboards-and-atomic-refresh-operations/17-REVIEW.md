---
phase: 17-shared-dashboards-and-atomic-refresh-operations
reviewed: 2026-08-25T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - R/dashboard/payload_contract.R
  - R/dashboard/payload_nations_league.R
  - R/dashboard/payload_euro.R
  - R/dashboard/renderer.R
  - R/dashboard/publication.R
  - scripts/refresh_competition_dashboards.R
  - scripts/com.xgelo.competition-dashboards.plist
  - scripts/auto_update_competition_dashboards.sh
  - scripts/com.xgelo.dashboard-update.plist
  - docs/competitions/phase17-batch-manifest.json
  - docs/competitions/current.json
  - docs/competitions/nations-league/index.html
  - docs/competitions/nations-league/payload.json
  - docs/competitions/nations-league/route-manifest.json
  - docs/competitions/nations-league/current.json
  - docs/competitions/euro-qualifying/index.html
  - docs/competitions/euro-qualifying/payload.json
  - docs/competitions/euro-qualifying/route-manifest.json
  - docs/competitions/euro-qualifying/current.json
findings:
  critical: 5
  blocker: 5
  warning: 4
  info: 0
  total: 9
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-08-25T00:00:00Z  
**Depth:** standard  
**Files Reviewed:** 19  
**Status:** issues_found

## Summary

The dashboard contract and renderer have useful escaping and inventory checks, but the operational path is not safe to ship. The production coordinator records callback names without executing the real source/build contracts, then materializes hard-coded fixture data; the checked-in public payloads prove that behavior. Promotion also cannot restore the incumbent after a post-promotion read-back failure, and the launchd entry point bypasses the only wrapper that performs Git publication.

## Critical Issues

### CR-01: Production refresh publishes fixture data instead of accepted competition outputs

**File:** `scripts/refresh_competition_dashboards.R:271-310`

**Issue:** The coordinator's `record()` function only invokes optional test callbacks and ignores their return values. The supposed Phase 13-16 gates at lines 288-305 are trace entries, not calls to the named production functions. At line 307, both bundles are unconditionally created with `phase17_fixture_bundle()`, so every non-dry run renders `fixture-001` with teams `Alpha` and `Beta` and the synthetic lineage. The committed `docs/competitions/nations-league/payload.json` contains exactly that fixture data and `nl-fixture-v1`. This can replace the public dashboard with fabricated data while reporting a passed gate trace.

**Fix:** Source and call the real Phase 13-16 loaders/builders with their validated inputs, propagate their returned bundles into `phase17_materialize_routes()`, and stop when any callback returns `valid = FALSE` or an error. Reserve `phase17_fixture_bundle()` for explicit test/fixture mode and reject it from the production entry point.

### CR-02: Regression gate always invokes the replay script with the wrong arguments

**File:** `scripts/refresh_competition_dashboards.R:141-146`

**Issue:** The first command is passed to `system2()` as `c("--vanilla", commands[[i]])`, where `commands[[1]]` is the single string `scripts/build_euro_qualifying_outcomes.R --replay-check`. Rscript interprets that entire string as a script filename; it does not split the embedded option. The production regression gate therefore fails or runs no replay check, despite the summary claiming this gate is enforced.

**Fix:** Invoke `system2("Rscript", c("--vanilla", "scripts/build_euro_qualifying_outcomes.R", "--replay-check"), ...)`, or use `-e` with a correctly quoted command. Add an integration test that asserts the child process receives the option and returns nonzero for a failed replay.

### CR-03: Read-back failure leaves the new publication live

**File:** `R/dashboard/publication.R:199-217`

**Issue:** After `file.rename(candidate_root, public_root)`, `promoted` is set to `TRUE`. If `phase17_validate_batch_envelope(public_root)` fails at line 215, the `on.exit()` handler does not restore the backup because it only rolls back when `!promoted`. The function then unwinds with the invalid candidate still at the public path. When there was no incumbent, the same failure leaves a bad new publication instead of restoring absence.

**Fix:** Keep the backup until read-back succeeds and make the failure handler roll back whenever the candidate has been promoted but the transaction has not been committed. On read-back failure, remove the candidate public root and rename the incumbent backup back, or remove the root when no incumbent existed; verify the restored byte snapshot before returning the error.

### CR-04: Hourly launchd job bypasses Git publication

**File:** `scripts/com.xgelo.competition-dashboards.plist:10-15`

**Issue:** The installed LaunchAgent runs `Rscript .../refresh_competition_dashboards.R` directly. Git staging, commit, upstream checks, and push exist only in `scripts/auto_update_competition_dashboards.sh:48-90`, which the new plist never invokes. The R coordinator itself does not stage, commit, or push; it only performs a final preflight trace. Thus the scheduled job can refresh local files without publishing them, while the documented operational design expects the hourly dashboard update to perform the complete publication operation.

**Fix:** Make the plist invoke the absolute shell wrapper, or move the complete Git publication transaction into the R entry point and invoke that entry point consistently. Keep one tested entry point and assert in an integration test that the installed plist reaches the allowlist/commit/push path.

### CR-05: Callback gates are observational, not fail-closed validation gates

**File:** `scripts/refresh_competition_dashboards.R:271-277`

**Issue:** Registered callbacks are called with one opaque `arguments` list and their return values are discarded. A real validator returning `list(valid = FALSE, failure_reason = ...)` would not stop the refresh; only an exception would. The coordinator also calls both the label callback and its alias when both are registered, which can duplicate side effects. This undermines the source, rules, probability, freshness, replay, and regression acceptance boundary even after the fixture substitution is fixed.

**Fix:** Define typed callback contracts, invoke exactly one registered implementation per gate, validate its result, and stop with the reported failure reason unless `valid` is explicitly true. Keep trace recording separate from callback execution.

## Warnings

### WR-01: Browser gate does not perform browser or viewport testing

**File:** `scripts/refresh_competition_dashboards.R:101-124`

**Issue:** After checking the pinned driver capability, the gate only reads each HTML file and searches for three literal strings. It never starts Safari/WebDriver, loads either route, sets the desktop/mobile viewport, exercises filters, or inspects the DOM/ARIA tree. A broken responsive layout or JavaScript filter can therefore pass the publication gate.

**Fix:** Run the pinned WebDriver against both staged routes at both declared viewport sizes, assert route load and required DOM/ARIA behavior, and fail closed when the browser session cannot complete.

### WR-02: First publication fails when the public root is an empty directory

**File:** `R/dashboard/publication.R:188-211`

**Issue:** `phase17_promote_batch()` creates `public_root` before promotion (`create = TRUE`). If it did not contain files, `had_incumbent` is false, but `file.rename(candidate_root, public_root)` attempts to rename over the existing empty directory and fails on typical filesystems. A clean installation with an empty `docs/competitions` directory cannot publish its first batch.

**Fix:** Do not create the destination before the rename, or remove only an owned empty destination after confirming it is empty and within the trusted parent. Test the no-incumbent/empty-directory case.

### WR-03: Disabling the legacy plist does not unload an already loaded LaunchAgent

**File:** `scripts/com.xgelo.dashboard-update.plist:6-9`

**Issue:** Adding `Disabled` to the file does not boot out an already loaded `com.xgelo.dashboard-update` job in the user's launchd domain. Without an installation/removal operation that executes the required bootout, the old scheduler can continue running and race the new job.

**Fix:** Make installation explicitly boot out the old label and verify `launchctl print-disabled` and `launchctl print` state, or document and enforce that operator step before bootstrapping the new agent.

### WR-04: Payload validator accepts a vector-valued edition identifier

**File:** `R/dashboard/payload_contract.R:221-226`

**Issue:** The validator intentionally allows `payload$edition_id` when it equals the two-element edition vector, because the `identical()` branch does nothing. Downstream code assumes a scalar edition and indexes `phase17_routes()[[payload$edition_id]]`; malformed payloads can therefore pass validation and fail later or select an unintended route.

**Fix:** Require `length(payload$edition_id) == 1L` before membership validation and normalize it with `phase17_scalar()`.

---

_Reviewed: 2026-08-25T00:00:00Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
