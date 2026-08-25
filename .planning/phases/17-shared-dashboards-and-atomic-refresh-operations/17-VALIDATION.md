---
phase: 17
slug: shared-dashboards-and-atomic-refresh-operations
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 17 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | None; tests are direct `tests/testthat/test_*.R` files |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase17_dashboards.R", desc="phase17_smoke", stop_on_failure=TRUE, reporter="summary")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase17_dashboards.R", stop_on_failure=TRUE, reporter="summary")'` |
| **Estimated runtime** | Under 60 seconds for contract and failure-injection tests; browser smoke is environment-dependent |

## Sampling Rate

- **After every task commit:** Run the Phase 17 quick contract test command.
- **After every plan wave:** Run the full Phase 17 suite and the relevant Phase 13-16 focused regressions.
- **Before `/gsd:verify-work`:** Run the full suite, fresh-process replay, plist lint, bounded batch dry run, and available browser smoke.
- **Max feedback latency:** 60 seconds for the R-side quick suite.

## Per-Plan Verification Map

| Plan | Wave | Requirements | Test Type | Automated Verification |
|------|------|--------------|-----------|------------------------|
| 17-01 | 1 | SIM-03, DASH-01, DASH-02 | contract/integration | Payload schema, edition isolation, truthful pre-draw state, lineage fields, and deterministic replay assertions |
| 17-02 | 2 | DASH-01, DASH-02, DASH-03, DASH-04 | renderer/browser | Shared-renderer identity, required sections, filter dimensions, responsive DOM/ARIA checks, warning and collapsed-credit rendering |
| 17-03 | 3 | OPS-02, OPS-03, OPS-05 | integration/failure injection | Candidate envelope staging, ordered gates, exact inventories/hashes, promotion, rollback, and incumbent-byte preservation |
| 17-04 | 4 | OPS-01, OPS-04, OPS-05 | shell/operational | `plutil -lint`, bounded launchd entrypoint, clean/upstream-aligned preflight, compact allowlist, and no mutation on failure |

## Requirement Coverage

| Requirement | Behavior | Test Type | Automated Command | File Exists? |
|-------------|----------|-----------|-------------------|--------------|
| SIM-03 | Both edition payloads expose seed, ruleset, source, model, projection, and replay lineage. | integration/replay | Phase 17 test file plus fresh `Rscript` child replay | No - Wave 0 |
| DASH-01 | Nations League and EURO entry points use one schema and renderer. | unit/integration | Shared renderer and schema assertions | No - Wave 0 |
| DASH-02 | Structure, standings, fixtures, results, forecasts, form, and projected outcomes are present or truthfully unavailable. | contract | Payload section assertions | No - Wave 0 |
| DASH-03 | Section, league/group, team, matchday, and fixture-status filters work at responsive viewports. | browser smoke | Safari WebDriver/Playwright gate or approved fallback | No - Wave 0 |
| DASH-04 | Refresh, confidence, model, warnings, and collapsed credits render without operational detail dominating. | DOM/ARIA and payload | Browser smoke plus structural payload assertions | No - Wave 0 |
| OPS-01 | launchd invokes one bounded hourly batch with explicit paths and logs. | shell/integration | `plutil -lint` plus bounded dry run | No - Wave 0 |
| OPS-02 | Both candidate dashboards stage and promote as one coherent batch. | integration/failure injection | Atomic batch test with interrupted promotion | No - Wave 0 |
| OPS-03 | Source, rules, probabilities, freshness, replay, browser, and regression gates run before publication. | orchestration | Ordered gate trace and injected-failure tests | No - Wave 0 |
| OPS-04 | Commit/push occurs only from clean, upstream-aligned state and after validation. | shell/integration | Isolated git fixture with dirty/diverged cases | No - Wave 0 |
| OPS-05 | Invalid, partial, oversized, dirty, or failed batches retain the incumbent publication. | failure injection | Fail-closed and rollback assertions | No - Wave 0 |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase17_dashboards.R` with repository-root-aware loaders and deterministic fixtures.
- [ ] Neutral payload schema validator and exact expected section/filter dimensions.
- [ ] Candidate batch fixture with incumbent/candidate trees and byte-snapshot helper.
- [ ] Failure injectors for source, rules, probability, freshness, replay, browser, manifest/hash, promotion, read-back, and Git preflight gates.
- [ ] Browser smoke harness or an explicit Safari WebDriver provisioning decision; do not silently install Playwright or browser binaries.
- [ ] Plist lint/status helper and bounded `--dry-run` refresh command.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Public route layout and visual hierarchy on a real desktop and mobile browser | DASH-03, DASH-04 | No browser automation is currently installed; environment capability must be decided before publication is accepted. | Open both routes, exercise every filter, verify responsive layout, inspect warnings/credits, and record browser/version. |
| launchd installation and hourly scheduling under the user's macOS account | OPS-01 | `launchctl` state and permissions are host-specific. | Lint the plist, install in the user LaunchAgents domain, trigger a bounded run, inspect stdout/stderr and exit status, then unload it. |

## Validation Sign-Off

- [ ] All tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity has no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing requirement references.
- [ ] No watch-mode flags are used.
- [ ] Feedback latency is below 60 seconds for the quick suite.
- [ ] `nyquist_compliant: true` set after validation is implemented.

**Approval:** pending
