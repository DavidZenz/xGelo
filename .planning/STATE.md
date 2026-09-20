---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: UEFA Champions League Forecast Dashboard
current_phase: 18
current_phase_name: club-and-ucl-source-contracts
status: executing
stopped_at: Completed 18-08-PLAN.md
last_updated: "2026-09-20T12:29:54.841Z"
last_activity: 2026-09-20
last_activity_desc: Phase 18 execution started
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 14
  completed_plans: 9
  percent: 0
---

# xGelo Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-09-19)

**Core value:** Accurate, calibrated football forecasting without dependence on paid data feeds.
**Current focus:** Phase 18 — club-and-ucl-source-contracts

## Current Position

Phase: 18 (club-and-ucl-source-contracts) — EXECUTING
Plan: 4 of 14
Status: Ready to execute
Last activity: 2026-09-20 — Phase 18 execution started

Progress: [██████░░░░] 64%

## Milestone Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 18 | Club and UCL Source Contracts | 6 | In progress (5/6) |
| 19 | Independent Club Forecast Authority | 5 | Not started |
| 20 | UCL Rules, State, and Tournament Outcomes | 9 | Not started |
| 21 | N-Edition Dashboard and Atomic Publication | 5 | Not started |
| 22 | Automated Refresh and Release Hardening | 4 | Not started |

## Performance Metrics

**Current milestone:**

- Total plans completed: 5
- Average duration: 13 min
- Total execution time: 63 min

**Previous milestone:** v3.0 completed 52 formal plans across Phases 13-17; details remain in `.planning/milestones/v3.0-phases/` and `.planning/milestones/v3.0-ROADMAP.md`.
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 18 P01 | 14 min | 3 tasks | 10 files |
| Phase 18 P02 | 10 min | 3 tasks | 10 files |
| Phase 18 P03 | 9 min | 2 tasks | 8 files |
| Phase 18 P05 | 15min | 3 tasks | 14 files |
| Phase 18 P06 | 15min | 2 tasks | 4 files |
| Phase 18 P04 | 18min | 3 tasks | 5 files |
| Phase 18 P07 | 4min | 2 tasks | 2 files |
| Phase 18 P14 | 7min | 2 tasks | 10 files |
| Phase 18 P08 | 45min | 3 tasks | 10 files |

## Accumulated Context

### Decisions

- [v4.0]: Club forecasts require a separately trained, evaluated, and selector-authorized release; national-team authority is rejected.
- [v4.0]: Automated current-state acquisition remains disabled until a live-key provider and terms acceptance gate passes.
- [v4.0]: UEFA web material is manual, versioned rules evidence rather than an automated match-state source.
- [v4.0]: Current xG, injury, lineup, suspension, and player evidence remains typed unavailable without an accepted lawful source.
- [v4.0]: UCL joins only after the publisher is registry-derived for 0/1/N editions and preserves all incumbent bytes on failure.
- [Phase 18]: Provider credentials remain process-local; only presence crosses the acceptance state machine. — Prevents tokens, headers, and reversible credential derivatives from entering durable evidence.
- [Phase 18]: First provider acceptance requires the four-resource live probe bound to exact 36-club and 144-match expectations. — Fixtures, offline checks, partial coverage, and ordinary provider-live mode cannot bootstrap authority.
- [Phase 18]: Club identity uses a project-owned club_ namespace and never reuses national-team or FIFA identity as authority. — Prevents cross-domain collisions and keeps source-ID/alias validity semantics explicit.
- [Phase 18]: Production club registries remain empty until explicit owner mappings exist. — Missing history stays hash-bound blocked evidence and an absent live probe remains not-run rather than inferred.
- [Phase 18]: The current UCL adapter accepts only the exact four fixed CL/2026 endpoints; no caller-supplied host, path, or per-ID traversal is available.
- [Phase 18]: Synthetic provider evidence remains offline-only; only explicit live_acceptance_probe may invoke atomic provider acceptance after owner and identity review.
- [Phase 18]: The 2021/22-2025/26 six-family club-history panel remains blocked until full pins, licenses, expected counts, and owner mappings exist.
- [Phase 18]: Date-only club matches become available at the next UTC day boundary and require evidence time strictly earlier than cutoff.
- [Phase 18]: Source authority is a closed discriminated union recomputed from evidence; stored eligibility booleans are never authority.
- [Phase 18]: Fixture contracts are permanently non-promotable, and production manual authority remains not_reviewed until real owner evidence exists.
- [Phase 18]: Technical refresh rollback is separate from reviewed provider-exit retain or withdraw compliance authority.
- [Phase 18]: Blocked refresh history and sidecars are hash-linked, field-consistent, and metadata-writer failures durably self-report.
- [Phase 18]: Production UCL current state remains missing-credential, automation-disabled, and no-incumbent until real accepted authority exists.
- [Phase 18]: Canonical v2 preserves exact UTF-8 bytes without Unicode normalization. — Byte-distinct normalization forms remain auditable and deterministic.
- [Phase 18]: Canonical tables permit duplicate stable keys but reject missing or blank key components. — Multiplicity remains represented while deterministic v2 row bytes provide tie-breakers.
- [Phase 18]: Every Phase 18 loader sources the canonical hash module immediately after trusted-root resolution and before consumers.
- [Phase 18]: Dynamic Phase 18 test loaders source mandatory dependencies unconditionally so missing modules fail closed.
- [Phase 18]: Production acceptance readers preserve stored canonical-v2 hashes and validators independently recompute exact owner, edition, capability, and fingerprint authority.
- [Phase 18]: Acceptance publication selects a validated immutable generation through one hash-bound atomic current.json replacement.
- [Phase 18]: The provider CLI is fixed to football_data_org_v4/ucl_2026_27 and uses tagged results with stable success, blocked, rejected, usage, and runtime exits.

### Pending Todos

- Execute Phase 18 from the verified six-plan, four-wave plan set.

### Blockers/Concerns

- Production automation is conditional on provider rights, retention, attribution, quota, schema, completeness, and freshness acceptance.
- Historical club coverage and cross-league connectivity must be measured before model promotion thresholds are frozen.
- Late UEFA tie-break evidence needs either a permitted source or an explicit unresolved-rank release tolerance.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Product | Isolated what-if result scenarios | Deferred to v4.x | v4.0 scoping |
| Data | Advanced event, lineup, injury, and suspension adapters | Await lawful source and value test | v4.0 scoping |
| Competition | UCL qualifying rounds and additional UEFA club competitions | Deferred | v4.0 scoping |
| Operations | Near-live refresh | Await source SLA, hosting, cost, and monitoring case | v4.0 scoping |

## Session Continuity

Last session: 2026-09-20T12:29:54.832Z
Stopped at: Completed 18-08-PLAN.md
Resume file: None
