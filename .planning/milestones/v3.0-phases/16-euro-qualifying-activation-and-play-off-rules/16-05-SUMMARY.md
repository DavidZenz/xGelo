---
phase: 16-euro-qualifying-activation-and-play-off-rules
plan: 05
subsystem: cli-publication
tags: [r, uefa-euro, outcomes, replay, atomic-publication, baseline]

# Dependency graph
requires:
  - phase: 16-04
    provides: Phase 16 EURO outcomes candidate, validator, lineage graph, and atomic writer
  - phase: 15
    provides: Registered Nations League interim handoff and model lineage contract
provides:
  - Registered EURO qualifying outcomes CLI and thin UEFA wrapper
  - Exact validated nine-file EURO outcomes inventory at the registered output root
  - Revision-safe incumbent retention, D-16 pre_draw control payload, and fresh-process replay evidence
affects: [phase-17-dashboard, euro-outcomes-consumers, release-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [manifest-driven CLI inputs, isolated Phase 14 embedding, candidate-before-publication validation, byte-level replay fingerprints]

key-files:
  created:
    - scripts/build_euro_qualifying_outcomes.R
    - scripts/build_uefa_euro_qualifying_outcomes.R
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/competition_topology.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/stage_slots.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/projected_standings.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/projected_rankings.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/qualification_ledger.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/team_path_probabilities.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/fixture_forecast_form.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/simulation_metadata.csv
    - outputs/competition/uefa_euro_2028_qualifying/outcomes/outcomes_manifest.csv
  modified:
    - tests/testthat/test_phase16_euro_qualifying.R

key-decisions:
  - "Require --edition-id uefa_euro_2028_qualifying for every non-help CLI mode; do not infer an edition or add a future endpoint."
  - "Reuse the Phase 16 validator and atomic publication transaction, with candidate rows suppressed for unavailable or revision-blocked states."
  - "Treat the recorded Phase 13 full-suite baseline as non-green evidence: the comparator exits zero only when no new identity/signature appears."

patterns-established:
  - "Fresh replay fingerprints compare exact CSV bytes, SHA-256 hashes, lineage fields, manifest parent hashes, and D-16 payload metadata."
  - "Embedded Phase 14 dependencies load into an isolated environment so their direct-entrypoint guard cannot consume EURO CLI arguments."

requirements-completed: [COMP-03, SIM-02, SIM-04]

coverage:
  - id: D1
    description: "Registered EURO CLI builds the exact nine-file pre_draw and active-after-draw outcomes candidate from validated inputs."
    requirement: COMP-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#cli|inventory|dry_run|payload_copy|active_after_draw"
        status: pass
      - kind: other
        ref: "Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --edition-id uefa_euro_2028_qualifying --dry-run"
        status: pass
    human_judgment: false
  - id: D2
    description: "Atomic write behavior retains incumbent bytes for blocked revisions and publishes validated revisions only."
    requirement: SIM-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#cli|publication|continuity|Refresh blocked|incumbent bytes"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase16_euro_qualifying.R#cli|publication|continuity|valid revision replaces after validation"
        status: pass
    human_judgment: false
  - id: D3
    description: "Normal, reversed, repeated, fresh-process, and baseline-aware acceptance checks are wired to the registered bundle."
    requirement: SIM-02
    verification:
      - kind: integration
        ref: "Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --edition-id uefa_euro_2028_qualifying --replay-check"
        status: pass
      - kind: other
        ref: "Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --compare --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md"
        status: pass
    human_judgment: false

# Metrics
duration: 2h 8m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 05: EURO outcomes CLI and publication summary

**Registered EURO qualifying outcomes CLI with exact nine-file publication, D-16 pre_draw control metadata, revision continuity, and fresh-process replay validation.**

## Performance

- **Duration:** 2h 8m
- **Started:** 2026-08-24T13:45:03Z
- **Completed:** 2026-08-24T15:53:14Z
- **Tasks:** 2 completed
- **Files modified:** 12 plan-owned files

## Accomplishments

- Added the manifest/config-driven registered EURO CLI and thin UEFA wrapper with explicit edition validation for dry-run, replay-check, and write modes.
- Published the exact nine-file `pre_draw` inventory with valid self-hashed manifest and exact D-16 heading, body, draw date, refresh timestamp, source bundle, and unavailability reason.
- Added candidate suppression and incumbent byte retention for D-03/D-04 revision behavior, plus normal/reversed/repeated/fresh child-process replay fingerprints covering lineage and parent hashes.
- Confirmed Phase 13 publication, Phase 14 state, Phase 15 production, and full Phase 16 regressions; the baseline comparator accepted only the recorded known failure and reported it as non-green.

## Task Commits

Each task was committed atomically with TDD RED/GREEN gates:

1. **Task 1 RED: Trace CLI and exact inventory contract** - `69d58ad` (`test`)
2. **Task 1 GREEN: Add registered EURO outcomes CLI** - `99f37e2` (`feat`)
3. **Task 2 RED: Add revision and replay acceptance tests** - `50518b9` (`test`)
4. **Task 2 GREEN: Publish revision-safe EURO outcomes** - `ec6dd0a` (`feat`)

## Files Created/Modified

- `scripts/build_euro_qualifying_outcomes.R` - Registered input loader, candidate builder, exact inventory validation, dry-run/replay/write modes, D-16 payload, revision overlay, and replay fingerprints.
- `scripts/build_uefa_euro_qualifying_outcomes.R` - Thin compatibility wrapper delegating to the plan-owned CLI.
- `tests/testthat/test_phase16_euro_qualifying.R` - CLI inventory, payload, publication continuity, candidate isolation, and typed replay mismatch tests.
- `outputs/competition/uefa_euro_2028_qualifying/outcomes/` - Exact sibling inventory: `competition_topology.csv`, `stage_slots.csv`, `projected_standings.csv`, `projected_rankings.csv`, `qualification_ledger.csv`, `team_path_probabilities.csv`, `fixture_forecast_form.csv`, `simulation_metadata.csv`, and `outcomes_manifest.csv`.

The generated manifest contains nine `valid` rows and records manifest SHA-256 `af69aef712b0d0b0f7953e9520909bd4189ba12264303bf7a4ad89ce82d99ffc`.

## Decisions Made

- The CLI accepts only the registered `uefa_euro_2028_qualifying` edition and resolves source/state data from accepted manifests and configured Phase 14/15 inputs.
- Existing Phase 16 validation and atomic writer remain the publication boundary; no changes were made to `R/competition/uefa_euro_outcomes.R` or Phase 14 state files.
- Blocked and unavailable candidates retain schema-valid control metadata but no structural, fixture, standings, ledger, topology, or probability rows.
- A persistent known baseline is explicitly non-green even when the comparator exits zero; only new or unparseable failures gate acceptance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Made CLI dependency resolution safe for sourced/test contexts.**
- **Found during:** Task 1
- **Issue:** `sys.source()` did not provide a reliable `--file` context, and Phase 14's direct-entrypoint guard could consume EURO CLI arguments when loaded into the global environment.
- **Fix:** Walk upward to resolve the project root, lazy-load simulation dependencies, and isolate the Phase 14 entrypoint in a child environment while exporting only its required functions.
- **Files modified:** `scripts/build_euro_qualifying_outcomes.R`
- **Verification:** Full Phase 16 suite and registered dry-run pass.
- **Committed in:** `99f37e2`

**2. [Rule 1 - Bug] Hardened structured coalescing at the CLI boundary.**
- **Found during:** Task 1
- **Issue:** The inherited `%||%` helper evaluated structured one-element values as scalar `NA` conditions during the real manifest-backed dry run.
- **Fix:** Scoped a robust CLI-local `%||%` implementation after dependency loading without editing the shared Phase 16 modules.
- **Files modified:** `scripts/build_euro_qualifying_outcomes.R`
- **Verification:** Registered dry-run completes with `validation=TRUE` and `source_validation=TRUE`.
- **Committed in:** `99f37e2`

**3. [Rule 2 - Missing Critical] Suppressed all candidate rows for unavailable/revision-blocked outputs and cleared leaked candidate content from the write result.**
- **Found during:** Task 2 RED publication tests
- **Issue:** An invalid active source could leave unavailable fixture rows in the candidate, and the incumbent overlay retained the original candidate under the duplicate `candidate` list name.
- **Fix:** Empty every structural artifact for blocked statuses, recompute content/manifest hashes, and explicitly null candidate/simulation fields after incumbent overlay.
- **Files modified:** `scripts/build_euro_qualifying_outcomes.R`
- **Verification:** Publication continuity tests pass and incumbent manifest bytes remain identical before/after blocked write.
- **Committed in:** `ec6dd0a`

**4. [Rule 3 - Verification] Adapted the plan's filtered test command to installed testthat behavior.**
- **Found during:** Task 1 verification
- **Issue:** Installed testthat 3.3.2 rejects `filter=` for `test_file()`; the plan's literal command errors before selecting tests.
- **Fix:** Ran exact test descriptions with `desc=` and the complete Phase 16 file; all selected and full Phase 16 tests passed.
- **Files modified:** None
- **Verification:** Focused `desc=` runs, full Phase 16 run, and registered CLI dry-run/replay/write checks all pass.
- **Committed in:** `99f37e2` / `ec6dd0a`

**Total deviations:** 4 auto-fixed (Rules 1, 2, and 3)

**Impact on plan:** All deviations were required for correct embedding, truthful blocked output, or executable verification. No unrelated modules, endpoints, dashboard behavior, or Phase 14/Plan 04 files were changed.

## Verification Evidence

- Focused CLI/publication/replay tests: pass.
- Full `tests/testthat/test_phase16_euro_qualifying.R`: pass.
- Phase 13 publication transaction and integration regressions: pass.
- Phase 14 state-bundle regression: pass.
- Phase 15 Nations League and production regressions: pass.
- Registered CLI replay: `replay_verified=TRUE`, non-mutating.
- Registered CLI write: `durable_mutation=TRUE`, output root published atomically.
- Baseline comparator exit: `0`.
- Baseline child exit: `1`, with exactly the ten recorded Phase 13 identities and signature `156 fixture IDs paired with zero-length normalized source columns`.
- Baseline disposition: `persistent known baseline (non-green); no new failures.`

## Known Stubs

None. Empty structural/projection/probability CSVs in the current bundle are intentional D-16 `pre_draw` control output, validated by the Phase 16 contract rather than placeholder data.

## Issues Encountered

The plan's literal `testthat::test_file(..., filter=...)` syntax is incompatible with the installed testthat version; the equivalent exact-description and full-file runs were used and recorded above. No unresolved implementation blocker remains.

## User Setup Required

None - no external service or package configuration was introduced.

## Next Phase Readiness

The registered output root is ready for a Phase 17 consumer to read the exact nine-file bundle and its lineage/status metadata. The first official post-draw activation still requires human inspection of the accepted UEFA group/fixture bundle, confirmed kickoffs, host/Nations League ledger, draw-condition lineage, and blocked reasons before release-ready active output is treated as final.

## Self-Check: PASSED

- Summary file exists at the plan-owned path.
- Task commits `69d58ad`, `99f37e2`, `50518b9`, and `ec6dd0a` are present in git history.
- The generated nine-file inventory and valid manifest were confirmed on disk.

---
*Phase: 16-euro-qualifying-activation-and-play-off-rules*
*Plan: 05*
*Completed: 2026-08-24*
