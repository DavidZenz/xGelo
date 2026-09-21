---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "00"
subsystem: testing
tags: [R, testthat, UEFA, Champions-League, RED-contract, targets]

# Dependency graph
requires:
  - phase: 19-independent-club-forecast-authority
    provides: "CR-01 through CR-05 authority-blocker vocabulary and typed parent-reason states"
provides:
  - "Explicit 36-club/144-fixture UCL Wave 0 graph and targeted mutation builders"
  - "Eight-record typed UEFA 2026/27 rules and unresolved draw-procedure sidecar"
  - "Focused and adversarial RED contracts for requirements, edges, threats, targets, outputs, CLI, and typed results"
affects: [20-01, 20-02, 20-03, 20-04, 20-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Explicit fixture declarations with stable IDs, source lineage, lifecycle, score, venue, kickoff, and row hashes"
    - "Typed non-promotable fixture authority and unresolved draw-evidence states"
    - "Fresh-process RED probes using the red_missing_ucl_entrypoints condition class"

key-files:
  created:
    - tests/testthat/helper_uefa_champions_league.R
    - tests/testthat/test_uefa_champions_league.R
    - tests/testthat/test_phase20_adversarial_regression.R
    - data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json
    - .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-00-RED.md
  modified: []

key-decisions:
  - "Keep the seven official regulation records accepted and the edition-specific draw procedure unresolved and non-accepted."
  - "Treat the approved-shape fixture release as process-temporary and permanently production-ineligible."
  - "Require exact inventories for 19 public edge probes, 21 critical/high threat mappings, 10 targets, 15 target edges, 19 public symbols, and 10 output schemas."

patterns-established:
  - "Wave 0 fixtures declare every row and preserve explicit authority, lineage, and production eligibility markers."
  - "Missing implementation entrypoints fail with a typed RED condition instead of fixture/schema errors."

requirements-completed: [UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01, UCLOUT-02, UCLOUT-03, UCLOUT-04, UCLOUT-05, UCLOUT-06]

coverage:
  - id: D1
    description: "Full-cardinality fixture graph, approved-release mechanics fixture, and targeted mutation builders"
    requirement: UCLRULE-01
    verification:
      - kind: unit
        ref: "Rscript fixture/inventory smoke check"
        status: pass
    human_judgment: false
  - id: D2
    description: "Typed eight-record rules evidence sidecar with unresolved draw procedure"
    requirement: UCLOUT-03
    verification:
      - kind: unit
        ref: "test_uefa_champions_league.R evidence-schema contract"
        status: pass
    human_judgment: false
  - id: D3
    description: "Focused nine-requirement and EDGE-01 through EDGE-19 RED contract"
    requirement: UCLRULE-02
    verification:
      - kind: unit
        ref: "test_uefa_champions_league.R fresh-process RED run"
        status: fail
    human_judgment: true
    rationale: "Wave 0 intentionally records missing production entrypoints; later implementation waves must turn this RED contract GREEN."
  - id: D4
    description: "Adversarial CLI/targets/threat/public-registry/typed-result contract"
    requirement: UCLOUT-06
    verification:
      - kind: unit
        ref: "test_phase20_adversarial_regression.R fresh-process RED run"
        status: fail
    human_judgment: true
    rationale: "The scaffold must fail closed until the later orchestration implementation exists."

duration: 20min
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 00: Wave 0 UCL Validation Contract Summary

**Wave 0 UCL validation contracts with explicit 36x144 fixtures, typed UEFA evidence, and durable RED orchestration probes**

## Performance

- Duration: 20 minutes
- Started: 2026-09-21T14:35:00+02:00
- Completed: 2026-09-21T14:48:32+02:00
- Tasks: 2
- Files created: 6

## Accomplishments

- Declared and smoke-checked exactly 36 stable clubs and 144 explicit fixtures, including eight-opponent/4-home/4-away structure, lineage, lifecycle, score, venue, kickoff, and targeted mutation builders.
- Added exactly seven accepted official regulation records plus a typed, unresolved draw_procedure_2026_27 record with pinned canonical UEFA URLs and retrieved SHA-256 evidence.
- Added focused nine-requirement and adversarial contracts covering the exact public symbols, targets, directed edges, output schemas, EDGE-01..EDGE-19 inventory, CR-01..CR-05 probes, threat mappings, protected roots, and fail-closed typed results.
- Recorded fresh-process non-zero RED transcripts before implementation work in .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-00-RED.md.

## Task Commits

Each task was committed atomically; RED transcript updates are separate documentation commits because their commit references are recorded after the scaffold hashes exist:

1. Task 1 fixture/evidence/focused RED contract - 9bc7de9 (test)
2. Task 1 RED evidence transcript - 27a10b5 (docs)
3. Task 2 adversarial orchestration RED probes - 80821d4 (test)
4. Task 2 RED evidence transcript - 135ea6f (docs)

## Files Created

- tests/testthat/helper_uefa_champions_league.R - Full fixture graph, release fixture, mutations, inventories, threat map, and RED boundary helpers.
- tests/testthat/test_uefa_champions_league.R - Focused nine-requirement, evidence, graph, parent-reason, and edge contract.
- tests/testthat/test_phase20_adversarial_regression.R - Exact CLI/targets/output/public/threat/CR/protected-root adversarial contract.
- data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json - Typed eight-record official-evidence sidecar.
- .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-00-RED.md - Durable focused and adversarial RED transcripts.

## Verification

- Focused fresh-process test command: rtk Rscript --vanilla -e testthat::test_file(... test_uefa_champions_league.R ...). Expected exit 1; fixture/evidence assertions pass, then red_missing_ucl_entrypoints failures occur.
- Adversarial fresh-process test command: rtk Rscript --vanilla -e testthat::test_file(... test_phase20_adversarial_regression.R ...). Expected exit 1; exact inventories and fail-closed assertions pass, then four red_missing_ucl_entrypoints failures occur.
- Targeted fixture mutation and inventory smoke check: exit 0.
- No aggregate or long-running test suites were run.

## Decisions Made

- Canonical regulation rows use the fetched official UEFA page bytes for both raw and canonical hashes because Wave 0 defines no additional canonicalization transform.
- Missing edition-specific draw evidence remains unresolved; no guessed bracket or accepted draw record is included.
- Shared .planning/STATE.md, ROADMAP.md, REQUIREMENTS.md, and PROJECT.md were intentionally left untouched for the parent orchestrator while Phase 19 authority repair remains active.

## Deviations from Plan

### Auto-fixed Issues

1. Rule 1 fixture data bug: corrected invalid calendar dates in explicit kickoff declarations.
   - Found during: Task 1 fixture smoke check.
   - Issue: The initial deterministic declaration sequence contained 2026-09-31 through 2026-09-34.
   - Fix: Normalize those explicit fixture values to 2026-10-01 through 2026-10-04 before graph construction.
   - File: tests/testthat/helper_uefa_champions_league.R.
   - Verification: Calendar parsing and full 36/144 fixture smoke checks pass.
   - Commit: 9bc7de9.

Total deviations: 1 auto-fixed fixture-data bug. Impact: no scope expansion; deterministic IDs and cardinality are preserved.

## Issues Encountered

- Git required escalated permission for two commits that staged .planning files; no index lock file was present and no unrelated files were staged.
- RED failures are intentional and distinguishable from fixture/schema failures by the red_missing_ucl_entrypoints condition class.
- Deliberate null selector/root/draw-artifact fields are typed non-promotable or unresolved evidence markers, not implementation stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The five implementation waves can consume the committed fixture/evidence helpers and exact contract inventories. They must make the focused and adversarial suites GREEN while preserving unresolved draw-procedure state, fixture non-promotion, protected incumbent bytes, and Phase 19 typed human-needed/blocked semantics.

## Self-Check: PASSED

- All six plan-owned files exist on disk.
- Task and RED-evidence commits 9bc7de9, 27a10b5, 80821d4, and 135ea6f are present in git history.
- Focused/adversarial RED runs and fixture/inventory smoke checks match the recorded outcomes.
- No shared planning state or unrelated user-owned paths were staged.

---
Phase: 20-ucl-rules-state-and-tournament-outcomes
Completed: 2026-09-21
