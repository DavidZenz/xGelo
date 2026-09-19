---
phase: 15-nations-league-rules-and-outcomes
plan: "01"
subsystem: competition
tags: [uefa, nations-league, topology, source-admission, access-list, stage-capture]
requires:
  - phase: 15-nations-league-rules-and-outcomes
    provides: Wave 0 focused harness, source vocabulary, and contract decisions
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: accepted 2026/27 scheduled snapshot, Phase 13 five-resource contract, and Phase 14 state seam
provides:
  - canonical Articles 12-19 rules, topology, and hash-stable stage-slot schema
  - separately registered and hashed optional downstream-stage capture boundary
  - unresolved and admitted Article 13 access-list and seeded group-formation validation
affects: [15-02, 15-03, 15-04, standings, outcomes, forecast]
tech-stack:
  added: []
  patterns:
    - pure base-R contracts with canonical SHA-256 serialization
    - optional source captures outside the Phase 13 five-resource enum
key-files:
  created:
    - R/competition/uefa_nations_league_rules.R
    - data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-stage-capture-v1/stage_capture.json
    - data/competition/accepted/uefa_nations_league_2026_27/stage_capture.csv
    - data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv
    - data/competition/registries/stage_captures.csv
  modified:
    - R/competition/uefa_nations_league_adapter.R
    - R/competition/edition_registry.R
    - tests/testthat/test_phase15_nations_league.R
key-decisions:
  - Keep the Phase 13 five-resource enum and Phase 14 eleven-artifact state inventory unchanged; later-stage source facts use a separately validated capture pair.
  - Represent the current scheduled snapshot as unresolved_access_list with NA access positions and draw pots rather than inventing standings or access metadata.
  - Allow a complete named stage-capture pair beside accepted Phase 13 tables while rejecting arbitrary extras or partial pairs.
patterns-established:
  - Official and completed source rows require source fixture or artifact lineage; projected, unresolved, and suppressed slots require explicit non-official policies or reasons.
  - Reverse source row order must produce identical ruleset, topology, and access-formation hashes.
requirements-completed: [COMP-02]
coverage:
  - id: D1
    description: Hash-stable 2026/27 Nations League Articles 12-19 topology and stage-slot contract
    requirement: COMP-02
    verification:
      - kind: unit
        ref: tests/testthat/test_phase15_nations_league.R
        status: pass
    human_judgment: false
  - id: D2
    description: Separate official downstream-stage capture boundary with durable empty scheduled snapshot
    requirement: COMP-02
    verification:
      - kind: integration
        ref: tests/testthat/test_phase15_nations_league.R
        status: pass
    human_judgment: false
  - id: D3
    description: Article 13 unresolved and admitted seeded group-formation validation
    requirement: COMP-02
    verification:
      - kind: unit
        ref: tests/testthat/test_phase15_nations_league.R
        status: pass
    human_judgment: false
metrics:
  duration: 24min
  completed: 2026-08-22
status: complete
---
# Phase 15 Plan 01: Nations League Rules and Outcomes Summary

**Hash-stable 2026/27 Nations League rules, separately admitted stage captures, and truthful Article 13 group-formation boundaries.**

## Accomplishments

- Added the canonical 2026/27 UEFA Nations League ruleset for Articles 12-19, including the 14-group, 156-fixture, 54-team topology, eight stage identifiers, stage-slot schema, and order-independent SHA-256 contracts.
- Added a separate downstream-stage capture admission boundary with the exact 26-field capture schema, manifest checks, durable raw/accepted/registry paths, and an intentionally empty scheduled snapshot. The capture pair remains outside the Phase 13 five-resource enum.
- Added Article 13 access-list and group-formation validators. The current scheduled source remains explicitly unresolved, while admitted synthetic formation data is checked for edition, team, band, draw-pot, lineage, group coverage, and deterministic seed invariants.
- Preserved the scheduled-state truth boundary: no completed outcomes, standings, form, national-team xG, or invented access positions were added.

## Task Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `0bca211` | Freeze Nations League topology, rules, and stage-slot contracts |
| 2 | `acd1a4e` | Add Nations League downstream-stage capture admission and durable artifacts |
| 3 | `50a3d40` | Validate Article 13 access-list and group formation |

## Corrective Commits

- `aa7fd9d` - Validate mixed official and completed stage-capture statuses per row.
- `2154199` - Allow the complete named optional stage-capture pair beside Phase 13 resources while rejecting arbitrary extras or partial pairs.

## Decisions Made

- The Phase 13 five-resource contract and Phase 14 state inventory remain stable. Later-stage source capture is registered separately so future outcome rows cannot be mistaken for the scheduled snapshot resources.
- Unresolved access metadata is represented explicitly with `unresolved_access_list` and missing rule inputs. This keeps future group formation from silently consuming invented standings or access positions.
- Canonical serialization sorts source-order-sensitive collections before hashing, while semantic validation still checks exact source coverage and lineage.

## Verification

- PASS: `test_phase15_nations_league.R` - 152 expectations, 0 failures, 0 warnings, 0 skips.
- PASS: `test_phase13_source_contracts.R` - 175 expectations.
- PASS: `test_uefa_nations_league_production.R` - 58 expectations.
- PASS: direct replay of the registered empty stage capture through the Phase 15 adapter.
- PARTIAL: `test_phase14_standings.R` reaches the accepted-snapshot loader, but retains a pre-existing failure at line 686 comparing a row-names attribute. The column values are identical, and a control run without the optional stage-capture files reproduced the same order-only mismatch.
- NOT RUN: the full `tests/testthat` directory and the Phase 14 state-bundle regression were not completed after the user requested bounded focused verification and summary completion. No background process remains.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made topology and ruleset hashing truly order-independent**

- **Found during:** Task 1
- **Issue:** Canonical hashing attempted to serialize a function-valued field, and group labels were assigned before canonical group sorting, so reversed source order could change the hash.
- **Fix:** Normalize scalar rule values before serialization and assign canonical group labels after sorting.
- **Files modified:** `R/competition/uefa_nations_league_rules.R`, `tests/testthat/test_phase15_nations_league.R`
- **Commit:** `0bca211`

**2. [Rule 1 - Bug] Validated mixed stage-capture statuses per row**

- **Found during:** Task 2
- **Issue:** A capture containing both official and completed rows applied score requirements globally, rejecting valid official rows without scores.
- **Fix:** Apply score and completion metadata requirements to each row according to its status and preserve the official-row lineage rules.
- **Files modified:** `R/competition/uefa_nations_league_adapter.R`, `tests/testthat/test_phase15_nations_league.R`
- **Commit:** `aa7fd9d`

**3. [Rule 2/3 - Missing compatibility] Admitted the planned optional capture pair at the Phase 13 snapshot boundary**

- **Found during:** Task 2 regression verification
- **Issue:** The accepted snapshot validator required exactly the five Phase 13 tables, so the plan-required optional `stage_capture.csv` and `stage_capture_manifest.csv` pair made the existing loader reject the otherwise valid snapshot.
- **Fix:** Permit only the complete named optional pair, retain the Phase 13 five-resource enum, and continue rejecting arbitrary extras or partial pairs.
- **Files modified:** `R/competition/edition_registry.R`
- **Commit:** `2154199`

**4. [Rule 1 - Artifact correction] Corrected durable capture hashes after replay**

- **Found during:** Task 2 artifact verification
- **Issue:** The first durable manifest values included a transposed raw SHA substring and therefore could not replay through the registered capture boundary.
- **Fix:** Recomputed the raw, manifest, registry-row, and accepted CSV hashes and committed the corrected artifact set.
- **Files modified:** `data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-stage-capture-v1/stage_capture.json`, `data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv`, `data/competition/registries/stage_captures.csv`
- **Commit:** `acd1a4e`

## Issues and Deferred Verification

- The Phase 14 standings test still has an existing row-order-only `row.names` attribute mismatch at `tests/testthat/test_phase14_standings.R:686`; it is outside this plan because the same mismatch reproduces without the Phase 15 capture resources. The values and loader semantics are unchanged.
- The `windows append` helper could not record this residual because the pre-existing `.planning/WINDOWS.md` frontmatter counts already disagree with its entries (`23/0/5/28` versus `22/0/6/28`). `WINDOWS.md` was left untouched to preserve unrelated planning state.

## Known Stubs

None. The empty stage-capture payload is an intentional accepted scheduled-state artifact, not a placeholder for completed outcomes.

## Threat Flags

None. The new source boundary is explicitly constrained to validated local artifacts and does not add a network endpoint, authentication path, file-access trust boundary, or schema mutation outside the plan.

## Next Phase Readiness

Plan 15-02 can consume the canonical ruleset, topology, stage slots, and access-formation contract. Official downstream outcomes, standings, form, and national-team xG remain unavailable until a later official capture is admitted through the separate stage-capture boundary.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- Task commits `0bca211`, `acd1a4e`, `50a3d40`, and corrective commits `aa7fd9d`, `2154199` are present in git history.
- Focused Phase 15, Phase 13 source-contract, and UEFA production regression checks passed as recorded above.
