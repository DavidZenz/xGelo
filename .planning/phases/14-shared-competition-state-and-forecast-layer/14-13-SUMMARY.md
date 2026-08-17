---
phase: 14-shared-competition-state-and-forecast-layer
plan: "13"
subsystem: competition-state
tags: [match-identity, crosswalk, lifecycle, scores, tdd, provenance]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: schema-v2 accepted fixture/result contracts and stable source lineage inputs from Plan 14-12
  - phase: 13-source-contracts-and-competition-registry
    provides: accepted competition snapshots and normalized martj42 historical source
provides:
  - durable source-to-canonical match identity crosswalk
  - canonical lifecycle, completion, score, winner, evidence, and counting-state engine
  - auditable accepted-competition precedence with retained historical lineage
affects: [Phase 14 standings, Phase 14 form, Phase 14 forecast, Phase 15 competition rules]

# Tech tracking
tech-stack:
  added: []
  patterns: [score-free identity projection, orthogonal lifecycle/completion validation, deterministic row/table hashing]

key-files:
  created:
    - R/competition/match_state.R
    - data/competition/registries/match_identity.csv
    - .planning/phases/14-shared-competition-state-and-forecast-layer/deferred-items.md
    - .planning/phases/14-shared-competition-state-and-forecast-layer/14-13-SUMMARY.md
  modified:
    - tests/testthat/test_phase14_match_state.R

key-decisions:
  - "Mint canonical identity from source family/id, edition, teams, schedule/date, neutral, and venue context only; scores, lifecycle/status, row order, and score-bearing hashes are excluded."
  - "Prefer accepted competition semantics when a canonical match is shared, while retaining every accepted and historical source lineage for auditability."
  - "Keep source_status auditable and validate match_status, completion_method, score axes, winner, evidence time, standings count, and form count independently."
  - "Leave STATE-02 and STATE-04 pending because shared requirements are not complete until all downstream owners finish."

patterns-established:
  - "Corrections preserve match_id while semantic source row hashes and source lineages change."
  - "Unknown or incomplete lifecycle states fail closed; completed state is never manufactured from absent evidence or scores."

requirements: [STATE-02, STATE-04]
requirements-completed: []

coverage:
  - id: D1
    description: "All accepted fixture/result rows and all martj42 historical rows resolve through a durable, deterministic match identity crosswalk with source-lineage retention."
    requirement: "STATE-02"
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase14_match_state.R — canonical production batch and identity correction tests"
        status: pass
      - kind: other
        ref: "persisted data/competition/registries/match_identity.csv: 49,522 source rows, 49,521 unique match_id values, 0 duplicate source keys, 0 collision rows"
        status: pass
    human_judgment: false
  - id: D2
    description: "Canonical match rows enforce the complete D-02 lifecycle/completion cross-product and D-03/D-04 score, winner, evidence, standings, and form semantics."
    requirement: "STATE-04"
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase14_match_state.R — lifecycle matrix, orthogonal axes, score semantics, foreign-link rejection, deterministic hashes"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase14_match_state.R\", stop_on_failure=TRUE)'"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 18m
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 14-13: Canonical Match Identity and Lifecycle/Score Engine Summary

**Durable match identity now joins accepted and historical sources without score-bearing reminting, and a fail-closed canonical engine validates lifecycle, completion, score, winner, evidence, and counting semantics.**

## Performance

- **Duration:** 1h 18m
- **Started:** 2026-08-17T15:22:41Z
- **Completed:** 2026-08-17T16:40:31Z
- **Tasks:** 2
- **Files modified or created by implementation:** 4, plus scoped planning metadata

## Accomplishments

- Added deterministic match_identity.csv crosswalk generation, validation, and persistence across all 49,520 martj42 historical rows plus the accepted competition fixture/result inputs.
- Implemented canonical match construction with accepted-competition precedence, retained source lineages, correction-stable identity, deterministic ordering, row hashes, table hashes, and foreign-link rejection.
- Implemented the full lifecycle/completion and score engine: scheduled, in-progress, completed regulation, extra time, penalties, awarded, postponed, and abandoned states; paired score axes; penalty tie/winner rules; evidence time; independent standings/form flags; and fail-closed unknown/incomplete behavior.
- Expanded TDD coverage from the frozen lifecycle fixtures to the full production input batch and the accepted-vs-historical precedence path.

## Crosswalk and Identity Stability

- Source rows: 49,522 total — 49,520 martj42_history, 1 competition_fixture, and 1 competition_result.
- Canonical identities: 49,521 unique match_id values.
- Source-key uniqueness: 0 duplicate (source_namespace, source_id) keys.
- Collision audit: 0 collision rows; every row is collision_status=none and review_state=not_required.
- Shared accepted identity: the accepted fixture and result for nl-2026-0001 share one canonical match_id while retaining their distinct fixture/result source lineages.
- Correction stability: scheduled-to-completed corrections keep the same canonical match_id while semantic row hashes change and both source lineages remain available.

## Task Commits

Each TDD task was committed atomically with RED and GREEN gates:

1. Task 1 RED: durable crosswalk tests — 05f42e5 (test(14-13))
2. Task 1 GREEN: durable match identity crosswalk — 70be7ba (feat(14-13))
3. Task 2 RED: canonical lifecycle tests — ad8f264 (test(14-13))
4. Task 2 GREEN: canonical lifecycle and score engine — eaa5a4e (feat(14-13))

The plan metadata commit is recorded separately after STATE/ROADMAP reconciliation.

## Files Created/Modified

- R/competition/match_state.R — crosswalk builder/validator/persistence plus canonical lifecycle and score engine.
- data/competition/registries/match_identity.csv — persisted 49,522-row source-to-canonical identity registry.
- tests/testthat/test_phase14_match_state.R — RED/GREEN coverage for identity, lifecycle, score, lineage, production, and hash contracts.
- .planning/phases/14-shared-competition-state-and-forecast-layer/deferred-items.md — scoped record of the unrelated Phase 13 v1/v2 regression mismatch.
- .planning/WINDOWS.md — broken-windows ledger entry for the deferred Phase 13 regression.

## Verification

- Phase 14 exact match-state regression: FAIL 0 | WARN 0 | SKIP 0 | PASS 369.
- Phase 13 exact registry regression: FAIL 4 | WARN 0 | SKIP 0 | PASS 151. All four failures are pre-existing production-loading assertions comparing legacy phase13_normalized_fixture_schema() / phase13_normalized_result_schema() names with the accepted Phase 14 v2 snapshot schema. No Phase 13 source, fixture, or test was changed; details are in deferred-items.md.
- TDD gate compliance: RED commits precede their corresponding GREEN commits for both tasks; the final Phase 14 regression is fully green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Paired source rows were initially treated as ambiguous identity collisions**

- Found during: Task 1/Task 2 accepted-vs-historical integration coverage.
- Issue: Fixture and result records for one accepted source match were not collapsed before candidate resolution, and legitimate accepted-plus-historical matches were rejected as unreviewed collisions.
- Fix: Group same-source fixture/result records before identity resolution and allow the explicitly supported competition-plus-history merge while retaining both source families and preferring accepted competition fields.
- Files modified: R/competition/match_state.R.
- Verification: Phase 14 exact regression and production-batch assertion pass.
- Committed in: eaa5a4e.

**2. [Rule 1 - Bug] Row-aligned defaults caused excessive allocation during historical crosswalk minting**

- Found during: Task 1 production crosswalk generation.
- Issue: Default vectors were accidentally expanded against the full input length, producing avoidable quadratic allocation risk.
- Fix: Use row-aligned coalescing defaults and vectorized venue/candidate construction.
- Files modified: R/competition/match_state.R.
- Verification: Full 49,522-row crosswalk generated, persisted, and round-trip validated.
- Committed in: 70be7ba.

**3. [Rule 1 - Bug] Partial score axes were silently repaired**

- Found during: Task 2 score-semantic tests.
- Issue: A complete score pair could overwrite a partially supplied paired axis, hiding malformed input.
- Fix: Copy a paired axis only when its destination pair is entirely absent; partial pairs now fail closed.
- Files modified: R/competition/match_state.R.
- Verification: lifecycle/score invalid-case coverage passes.
- Committed in: eaa5a4e.

**4. [Rule 1 - Bug] Generic completed labels collapsed the completion axis**

- Found during: Task 2 orthogonality tests.
- Issue: Generic completed/finished/full_time source labels were implicitly forced to regulation, preventing an explicit extra-time or penalties method.
- Fix: Only source labels with explicit method meaning constrain completion_method; generic completed labels remain orthogonal and require explicit or safely defaulted semantics.
- Files modified: R/competition/match_state.R.
- Verification: completed-source-label/extra-time test and full Phase 14 regression pass.
- Committed in: eaa5a4e.

**5. [Rule 3 - Blocking issue] Historical source match_id was mistaken for a canonical ID**

- Found during: Task 2 production-batch construction.
- Issue: The historical source identifier could be interpreted as a supplied canonical identity, conflicting with the durable crosswalk.
- Fix: Treat historical match_id as a source identifier unless an explicit canonical_match_id is supplied; resolve canonical identity through the crosswalk.
- Files modified: R/competition/match_state.R.
- Verification: all historical production inputs resolve and canonical counts match the persisted crosswalk.
- Committed in: eaa5a4e.

Total deviations: 5 auto-fixed issues (Rules 1 and 3); 1 pre-existing Phase 13 regression mismatch deferred.

Impact on plan: All fixes were required for deterministic identity, truthful lifecycle semantics, or production-scale execution. No unrelated implementation scope was changed.

## Deferred Issues

The exact Phase 13 registry regression remains red for the four legacy-v1 schema-name assertions described in deferred-items.md. The owning Phase 13/v2 contract work must reconcile those expectations; Plan 14-13 intentionally did not modify out-of-scope files.

## Known Stubs

None in the files created or modified by this plan. Future-phase placeholder skips remain owned by their respective plans and were not changed here.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The canonical identity and lifecycle/score contracts are ready for downstream standings and form consumers. STATE-02 and STATE-04 remain pending until their shared downstream owners complete. The next plan is 14-14 after metadata reconciliation.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*

## Self-Check: PASSED

- Summary file exists on disk.
- Task commits `05f42e5`, `70be7ba`, `ad8f264`, and `eaa5a4e` are present in git history.
- STATE and ROADMAP metadata reconcile to 15/22 Phase 14 plans complete with Plan 14-14 next.
- Requirements remain pending; no requirements completion metadata was advanced.
