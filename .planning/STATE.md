---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: UEFA Champions League Forecast Dashboard
current_phase: 19
current_phase_name: independent-club-forecast-authority
status: executing
stopped_at: Completed 19-02-PLAN.md
last_updated: "2026-09-20T18:08:32.983Z"
last_activity: 2026-09-20
last_activity_desc: Plan 02 batch-safe club rating and strict replay verified
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 24
  completed_plans: 16
  percent: 67
---

# xGelo Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-09-19)

**Core value:** Accurate, calibrated football forecasting without dependence on paid data feeds.
**Current focus:** Phase 19 — independent club forecast authority

## Current Position

Phase: 19 (independent-club-forecast-authority) — EXECUTING
Plan: 3 of 10
Status: In progress; Plans 01-02 complete
Last activity: 2026-09-20 — Plan 02 batch-safe club rating and strict replay verified

Progress: [███████░░░] 67%

## Milestone Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 18 | Club and UCL Source Contracts | 6 | Automated implementation verified (6/6); human evidence pending |
| 19 | Independent Club Forecast Authority | 5 | In progress (1/10 plans) |
| 20 | UCL Rules, State, and Tournament Outcomes | 9 | Not started |
| 21 | N-Edition Dashboard and Atomic Publication | 5 | Not started |
| 22 | Automated Refresh and Release Hardening | 4 | Not started |

## Performance Metrics

**Current milestone:**

- Total plans completed: 14
- Average duration: 22 min
- Total execution time: 314 min

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
| Phase 18 P09 | 16min | 2 tasks | 11 files |
| Phase 18 P10 | 28min | 2 tasks | 4 files |
| Phase 18 P12 | 19min | 3 tasks | 24 files |
| Phase 18 P11 | 62min | 3 tasks | 9 files |
| Phase 18 P13 | 52min | 2 tasks | 6 files |
| Phase 19 P01 | 31min | 2 tasks | 5 files |
| Phase 19 P02 | 17min | 2 tasks | 2 files |

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
- [Phase 18]: Club identity authority requires canonical-v2 durability plus active status at the event instant.
- [Phase 18]: Freshness authority is the conjunction of competition, team-row, match-row, and standings-resource evidence.
- [Phase 18]: UCL source authority binds exact edition and ordered raw-byte aggregate into one canonical-v2 bundle graph.
- [Phase 18]: Candidate paths are checked lexically before resolution and parsed only from drift-checked in-memory snapshots.
- [Phase 18]: Completed history evidence is eligible only after method-specific conservative completion and strictly before cutoff.
- [Phase 18]: Historical corpus authority is independently recomputed from exact source, match, registry, review, and unresolved snapshots.
- [Phase 18]: History readers trust only one canonical-v2 atomic descriptor selecting immutable audit and accepted generations.
- [Phase 18]: Refresh visibility changes only through one canonical-v2 pointer selecting immutable accepted and transaction generations. — Readers must observe a complete old or complete new bundle/evidence tuple under crashes and concurrency.
- [Phase 18]: Provider exit is authorized only for the exact provider, edition, decision, bundle, and reviewed inventory of the current generation. — Compliance review must never affect unrelated, manual, fixture, stale, unreadable, or no-incumbent state.
- [Phase 18]: Phase 18 verification requires eight explicit fresh-process test files with zero failures, warnings, or skips.
- [Phase 18]: Live provider resource authority requires positive observed counts before automation can enable.
- [Phase 19]: Unavailable club enrichment remains value-less, inactive, optional, and non-imputable until one matching canonical hash-valid accepted source contract exists.
- [Phase 19]: The five-feature registry rejects non-canonical row order in addition to canonical row and table hash drift.
- [Phase 19]: Production club authority uses only fixed accepted Phase 18 descriptors; synthetic authority is marker-bound, temporary, explicit, and non-promotable.
- [Phase 19]: Club Elo freezes base 1500 and admits only predeclared K, home-advantage, and annual inactivity-factor domains. — Keeps rating evidence inside the frozen club candidate search space.
- [Phase 19]: Current-UCL rating authority requires the exact roster in one accepted-history connected component. — A shared numeric base is not evidence of cross-league comparability.

### Pending Todos

- Complete real provider terms/key acceptance for `football_data_org_v4`.
- Approve real club identity mappings for the supported UCL edition.
- Supply and approve pinned/licensed historical club sources before Phase 19 model training.
- Re-run Phase 18 verification and completion, then advance to Phase 19 planning.

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

Last session: 2026-09-20T18:08:32.972Z
Stopped at: Completed 19-02-PLAN.md
Resume file: None
