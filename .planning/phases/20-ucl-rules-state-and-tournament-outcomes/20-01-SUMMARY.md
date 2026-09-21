---
phase: 20-ucl-rules-state-and-tournament-outcomes
plan: "20-01"
subsystem: competition
tags: [R, UEFA, Champions-League, Article-18, simulation, provenance]

requires:
  - phase: 20-ucl-rules-state-and-tournament-outcomes
    provides: Full-cardinality fixture graph, pinned rules sidecar, and RED contract
  - phase: 19-independent-club-forecast-authority
    provides: Fixed production resolver and typed parent-authority boundary
provides:
  - Editioned UCL 2026/27 rules and Article 18 ranking trace
  - Typed 36-club/144-fixture state and immutable forecast ledger
  - Seeded simulation, draw-gated knockout paths, tie/final resolvers, and outcome artifacts
  - Machine-readable Phase 20 result contract with fail-closed production normalization
affects: [phase-20-ucl-rules-state-and-tournament-outcomes, UCL targets, outcome verification]

tech-stack:
  added: [digest, jsonlite, testthat]
  patterns: [typed blocked states, canonical row hashing, fixture non-promotion, seeded replay]

key-files:
  created:
    - R/competition/uefa_champions_league_rules.R
    - R/competition/uefa_champions_league_state.R
    - R/competition/uefa_champions_league_simulation.R
    - R/competition/uefa_champions_league_outcomes.R
  modified:
    - tests/testthat/helper_uefa_champions_league.R
    - tests/testthat/test_uefa_champions_league.R
    - .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-01-RED.md

key-decisions:
  - "Use Phase 14 lifecycle, score, and standings helpers whenever available."
  - "Resolve production club authority only through the fixed Phase 19 resolver."
  - "Treat fixture evidence as mechanics-only and keep missing draw evidence explicit."

patterns-established:
  - "Canonicalize stable fixture identity before state, simulation, or artifact hashing."
  - "Carry source, rules, model, draw, cutoff, and seed lineage on every candidate."

requirements-completed: [UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01, UCLOUT-02, UCLOUT-03, UCLOUT-04, UCLOUT-05, UCLOUT-06]

coverage:
  - id: D1
    description: "Exact 36-club/144-fixture schedule validation with opponent, home-away, lifecycle, kickoff, venue, identity, and lineage checks."
    requirement: UCLRULE-01
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Schedule mutations are typed blocked states and never repaired
        status: pass
    human_judgment: false
  - id: D2
    description: "Article 18 criteria trace preserves unresolved rank intervals and ignores provider display order."
    requirement: UCLRULE-02
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Article 18 retains an unresolved interval and ignores provider display order
        status: pass
    human_judgment: false
  - id: D3
    description: "Phase 19 production authority remains fail-closed while fixture mechanics produce a non-promotable ledger."
    requirement: UCLOUT-01
    verification:
      - kind: integration
        ref: tests/testthat/test_uefa_champions_league.R#Fixture authority supplies mechanics but production remains fail-closed
        status: pass
    human_judgment: false
  - id: D4
    description: "Seeded conditional simulation fixes settled rows, samples eligible open rows, and reproduces rank and band outputs."
    requirement: UCLOUT-02
    verification:
      - kind: integration
        ref: tests/testthat/test_uefa_champions_league.R#Conditional simulation fixes settled rows, samples eligible opens, and is reproducible
        status: pass
    human_judgment: false
  - id: D5
    description: "Draw evidence, legal rank paths, two-leg no-away-goals resolution, extra time, penalties, and neutral final are typed."
    requirement: UCLOUT-03
    verification:
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Draw evidence gates legal paths and accepted same-edition conditioning
        status: pass
      - kind: unit
        ref: tests/testthat/test_uefa_champions_league.R#Two-leg and final resolvers apply no-away-goals and neutral-final rules
        status: pass
    human_judgment: false
  - id: D6
    description: "Validated outcome candidates emit exact schemas, canonical reverse-input hashes, protected-root checks, and zero-failure result contracts."
    requirement: UCLOUT-06
    verification:
      - kind: integration
        ref: rtk Rscript --vanilla -e testthat::test_file(tests/testthat/test_uefa_champions_league.R)
        status: pass
      - kind: integration
        ref: rtk Rscript --vanilla -e testthat::test_file(tests/testthat/test_phase14_match_state.R)
        status: pass
    human_judgment: false

duration: "~55 min"
completed: 2026-09-21
status: complete
---

# Phase 20 Plan 20-01: UCL rules, state, and tournament outcomes Summary

**Editioned UCL 2026/27 rules now flow through a typed, deterministic fixture tracer while Phase 19 production authority remains fail-closed.**

## Performance

- Duration: ~55 min
- Completed: 2026-09-21T17:55:06Z
- Tasks: 2/2
- Files modified: 7 unique in-scope files

## Accomplishments

- Added exact official-rule evidence validation, Article 18 criterion/subset traces, qualification bands, and unresolved intervals.
- Added canonical 36-club/144-fixture schedule/state validation, Phase 14 standings handoff, source lineage, score/lifecycle semantics, and immutable forecast rows.
- Added seeded conditional simulation, rank/band aggregation, draw gating, legal paths, two-leg/final resolution, stage reconciliation, and exact artifact schemas.
- Added the typed Phase 19 authority boundary: missing club authority becomes production_human_needed with original_parent_reason no_accepted_club_history; fixture releases remain non-promotable.
- Added focused tests for schedule mutations, authority distinctions, replay hashes, protected roots, draw states, knockout matrices, and exact module exports.

## Task Commits

1. Task 1: Implement UCL rules/state/simulation/outcome tracer — a6c80e9
2. Task 2: Harden reusable fixture mutations and authority assertions — 4d99c75

TDD RED evidence:
- fda9c97 — failing UCL tracer contract
- c2994e9 — RED transcript commit binding

## Files Created/Modified

- R/competition/uefa_champions_league_rules.R — rules contract, evidence validator, Article 18 trace.
- R/competition/uefa_champions_league_state.R — schedule/state, Phase 14 handoff, authority normalization, forecast ledger.
- R/competition/uefa_champions_league_simulation.R — seeded simulation, draw/path gating, knockout resolvers, reconciliation.
- R/competition/uefa_champions_league_outcomes.R — schemas, candidate validation/writes, manifests, CLI, result contract.
- tests/testthat/helper_uefa_champions_league.R — mutation catalog and protected-root snapshot.
- tests/testthat/test_uefa_champions_league.R — fresh-process tracer and edge coverage.
- .planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-01-RED.md — durable RED transcript and commit binding.

The eight-row rules sidecar was validated unchanged from Wave 0; it was not rewritten in this plan.

## Decisions Made

- Production data cannot be synthesized from fixture evidence or caller-provided paths; production resolution stays behind the fixed Phase 19 boundary.
- Missing edition-specific draw evidence is a typed state that suppresses exact draw-conditioned paths.
- Reverse input order is normalized before hashing so replay identity covers semantic bytes.

## Deviations from Plan

### Auto-fixed Issues

1. Rule 1 bug: the Phase 14 adapter initially omitted the required uniform state_cutoff_utc input key. The cutoff is now threaded through canonical match conversion. Verified by the focused UCL and Phase 14 suites. Committed in a6c80e9.
2. Rule 1 bug: Article 18 trace forwarding duplicated the tie-group argument, and radix sorting dropped all-NA rank intervals. Trace forwarding and unresolved rank representation were corrected. Verified by the Article 18 and simulation tests. Committed in a6c80e9.
3. Rule 1 bug: macOS temporary-root aliases rejected valid candidate siblings, and a missing fixed release root surfaced as an unrecognized blocker. Temporary aliases are canonicalized and missing release evidence maps to no_accepted_club_history while retaining diagnostics. Verified by protected-root and authority tests. Committed in a6c80e9.

Total deviations: 3 auto-fixed Rule 1 bugs. Impact: required for correctness and platform-safe deterministic verification; no architecture changed.

## Issues Encountered

The fixed Phase 19 resolver currently has no accepted club release in this checkout. This is the expected production_human_needed path; no selector, incumbent, or production artifact was created or changed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The UCL mechanics/outcome seam is ready for later target wiring and adversarial verification. Production forecast/output generation remains intentionally blocked until Phase 19 source-backed CR-01..CR-05 evidence and accepted release authority are repaired.

## Self-Check: PASSED

- All seven touched in-scope files exist.
- RED, Task 1, and Task 2 commits resolve in git history.
- Focused UCL and Phase 14 verification commands pass with zero failures, warnings, or skips.

---
Phase: 20-ucl-rules-state-and-tournament-outcomes
Plan: 20-01
Completed: 2026-09-21
