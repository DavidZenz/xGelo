---
phase: 16-euro-qualifying-activation-and-play-off-rules
plan: 01
subsystem: competition-activation
tags: [r, testthat, uefa-euro, activation, lifecycle, provenance]
requires:
  - phase: 16-00
    provides: focused Phase 16 harness, deterministic fixtures, and captured baseline
provides:
  - manifest-driven EURO qualifying activation validation
  - exact D-16 pre-draw and active-after-draw envelopes
  - candidate revision isolation with incumbent continuity
  - accepted pre_draw-to-scheduled registry handoff
affects: [16-02, 16-03, 16-04, 16-05, 17]
tech-stack:
  added: []
  patterns: [registered source manifests, typed empty collections, confirmed kickoff gates, lifecycle-aware refresh callbacks]
key-files:
  created:
    - R/competition/uefa_euro_rules.R
  modified:
    - R/competition/edition_registry.R
    - scripts/acquire_uefa_snapshot.R
    - tests/testthat/test_phase16_euro_qualifying.R
decisions:
  - Keep EURO source and rules revisions registered through configuration or an explicitly registered manifest; candidates cannot self-authorize unknown IDs.
  - Use Phase 13 transition authority only after Phase 16 validates the complete accepted draw-and-schedule bundle.
  - Preserve typed empty state for pre_draw and active-after-draw results/standings instead of fabricating rows or probabilities.
metrics:
  duration: 1h 06m
  completed: 2026-08-24
  tasks: 3
  files: 4
requirements: [COMP-03, SIM-04]
status: complete
---

# Phase 16 Plan 01: EURO Qualifying Activation and Lifecycle Summary

Manifest-driven EURO qualifying activation now accepts the complete official five-resource draw-and-schedule bundle, preserves the exact D-16 pre-draw contract, isolates invalid revisions from an incumbent, and persists `pre_draw` to `scheduled` only after accepted publication and Phase 14 loader validation.

## Tasks Completed

| Task | Result | Commits |
| --- | --- | --- |
| 1. Trace accepted pre-draw and active-after-draw activation | Added the activation module, stable contract symbols, confirmed-kickoff eligibility, exact D-16 metadata, and typed empty collections. | `1802619`, `b70083b` |
| 2. Add revision isolation and continuity | Added registered revision checks, raw/canonical hash lineage, no-incumbent unavailable envelopes, and incumbent-preserving revision overlays. | `6aa1247`, `7985cf5` |
| 3. Persist the lifecycle handoff | Loaded the activation contract through the registry loader and wired both normal refresh branches to transition and persist the accepted lifecycle atomically. | `a45a0e0`, `7716c26` |

## Verification

- `tests/testthat/test_phase16_euro_qualifying.R`: passed in full, including activation, pre-draw, active-after-draw, revision, continuity, registry-path, branch, failure-injection, and no-scheduled-without-accepted checks.
- `tests/testthat/test_phase13_competition_registry.R`: passed in full, including real accepted snapshot loading and forged scheduled-state rejection.
- `tests/testthat/test_phase13_publication_integration.R`: passed in full, including publication rollback cases.
- `tests/testthat/test_phase15_nations_league.R`: passed in full as the wave-gate regression.
- `tests/testthat/test_phase14_state_bundle.R`: completed successfully with the pre-existing skipped production state-candidate assertion recorded in `.planning/WINDOWS.md` entry 18.
- `R/competition/edition_registry.R` and `scripts/acquire_uefa_snapshot.R`: parsed successfully with `Rscript --vanilla`.
- The Phase 16-00 captured full-suite baseline was consumed unchanged (`4f123bfc5edb83fac3b5ba6606ca6dba1971208793f7c2f11a2254b915c9a98c`). The repository-wide suite was not rerun, per the execution request.

The plan's `testthat::test_file(..., filter=...)` commands are incompatible with the installed testthat API, which rejects `filter` for `test_file`. Equivalent focused `desc=` selections and full focused-file runs were used; this did not change production behavior.

## Acceptance Coverage

- The validator requires the registered five-resource bundle, matching edition/source/rules lineage, raw and canonical hashes, provenance, stable group/team/fixture IDs, and confirmed kickoff timestamps before active activation.
- `active-after-draw` remains `scheduled` with empty schema-valid standings/results and no forecast eligibility for a fixture missing an ID or confirmed kickoff.
- `pre_draw` exposes the exact D-16 heading/body, official draw date, refresh/source metadata, explicit unavailability reason, and empty typed collections.
- Invalid candidates are unavailable with no candidate rows when there is no incumbent; with an incumbent, the accepted state remains visible and unchanged while revision metadata carries the warning and failure reason.
- The registry loader validates the accepted snapshot before returning scheduled EURO state, so date-only or incomplete/forged scheduled rows remain rejected.
- Both fallback and normalized `phase13_acquire_publish_refresh()` branches publish first and then call the lifecycle-aware registry update; failure before accepted publication cannot create a scheduled row.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical activation path] Candidate normalization inherited the incumbent `pre_draw` lifecycle.**
- **Found during:** Task 3 implementation review.
- **Issue:** A complete post-draw candidate would be normalized as pre-draw before the transition gate, preventing its fixtures from reaching activation.
- **Fix:** Normalize against the candidate's explicit status (`active` mapped to Phase 13 `scheduled`) while retaining incumbent identity and registry provenance.
- **Files modified:** `scripts/acquire_uefa_snapshot.R`
- **Commit:** `7716c26`

### Tooling Adaptation

The mandated focused command shape was adapted from `filter=` to `desc=`/full `test_file()` execution because the installed testthat version rejects `filter` as an unused argument. The captured baseline and repository-wide suite were left untouched.

## TDD Gate Compliance

- Task 1 RED/GREEN: `1802619` -> `b70083b`.
- Task 2 RED/GREEN: `6aa1247` -> `7985cf5`.
- Task 3 RED/GREEN: `a45a0e0` -> `7716c26`.

## Known Stubs

None. The D-16 `not available` wording and empty collections are intentional contract state, not placeholders.

## Deferred Issues

- The pre-existing Phase 14 `phase14_build_competition_state_candidate` test-loader gap remains outside Plan 16-01 scope and is tracked by `.planning/WINDOWS.md` entry 18 and `deferred-items.md`.
- The captured Phase 16-00 full-suite failure remains the comparison baseline; it was not rerun by request.

## Self-Check: PASSED

- SUMMARY and all four Plan 16-01-owned files exist.
- All six task commits are present in Git history.
- No task commit deleted a tracked file.
