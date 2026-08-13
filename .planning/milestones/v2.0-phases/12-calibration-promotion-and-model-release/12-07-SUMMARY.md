---
phase: 12-calibration-promotion-and-model-release
plan: 07
subsystem: consumers
tags: [phase12, resolver, dashboard, targets, ui-regression]
requires:
  - completed Phase 12 release bundle
  - one-shot final evaluation and promotion decision
provides:
  - approved-release resolver
  - release-backed dashboard and publisher
  - explicit Phase 12 target ancestry
affects: [dashboard, forecast-publishing]
status: complete
completed: 2026-08-11
---

# Phase 12 Plan 07: Approved Consumer Boundary Summary

## Outcome

Dashboard and publishing consumers now resolve exactly one completed approved or
incumbent-retained release through R/release/release_contract.R. The production
targets dashboard and scripts/update_worldcup_dashboard.R no longer select raw
model paths as consumer authority.

## Implementation

- Added fresh-process resolver and metadata projection with trusted-root,
  path, hash, identity, status, panel, primary-view, and G=40 checks.
- Added release provenance to dashboard JSON and an accessible release panel with
  resolved, loading/error, retained-status, raw-fallback, and full-provenance
  states.
- Wired _targets.R through calibration/freeze, approval-gated labels, final
  evaluation, promotion report, release bundle, resolver, and dashboard.
- Kept phase12_final_labels as a format = file target downstream of the
  explicit approval target. Its default approval state is pending, so no second
  holdout opener is possible without an explicit operator approval.

## Verification

- Target manifest contains all eight required Phase 12 target seams.
- Release-backed dashboard smoke test passed with deterministic small simulations.
- Dashboard suite: 451 passing assertions.
- Full repository suite: 2,532 passing assertions, 0 failures, 0 warnings, 0 skips.
- The final label source was not reopened during consumer verification.

## Commit

- 03adb2c — feat(12-07): publish approved release consumer boundary
- 483133a — test(12): close promotion contract gate

---
*Phase: 12-calibration-promotion-and-model-release*
*Plan: 07*
