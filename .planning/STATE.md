---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: UEFA Competition Forecast Dashboards
current_phase: 13
current_phase_name: Source Contracts and Competition Registry
status: verifying
stopped_at: Completed 13-source-contracts-and-competition-registry-12-PLAN.md
last_updated: "2026-08-14T14:14:18.956Z"
last_activity: 2026-08-14
last_activity_desc: Plan 13-12 completed; locked normalized fourteen-target publication graph ready for verification
progress:
  total_phases: 1
  completed_phases: 0
  total_plans: 12
  completed_plans: 9
---

# xGelo Project State

## Current Position

Phase: 13 (Source Contracts and Competition Registry) — VERIFYING
Plan: 6 of 12 (next chronological incomplete plan)
Status: Plan 13-12 complete; remaining Phase 13 plans are pending
Last activity: 2026-08-14 — Plan 13-12 completed; locked normalized fourteen-target publication graph ready for verification

## Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 13 | Source Contracts and Competition Registry | Ready for verification | 5/5 |
| 14 | Shared Competition State and Forecast Layer | Not started | 7/7 |
| 15 | Nations League Rules and Outcomes | Not started | 2/2 |
| 16 | EURO Qualifying Activation and Play-off Rules | Not started | 4/4 |
| 17 | Shared Dashboards and Atomic Refresh Operations | Not started | 10/10 |

**Overall:** 1 of 5 phases ready for verification (20%); Phase 13 has 9 of 12 plans complete.

## Project Reference

See `.planning/PROJECT.md` for the product definition, constraints, and current
milestone scope.

**Core value:** Accurate, calibrated international-football forecasting without
dependence on paid data feeds.

**Current focus:** Phase 13 — Source Contracts and Competition Registry
and the shared competition registry for Nations League and EURO qualifying.

## Decisions

- [Milestone v3.0]: Reuse one shared static dashboard engine while keeping Nations League and EURO competition state, rules, and outputs separate.
- [Milestone v3.0]: Treat official UEFA competition data as the authority and support audited manual fallbacks instead of silent overrides.
- [Milestone v3.0]: Keep EURO 2028 qualifying in an explicit `pre_draw` state until an official UEFA draw snapshot exists after the 6 December 2026 draw.
- [Milestone v3.0]: Publish both competition bundles atomically as one hourly batch or not at all.
- [Milestone v3.0]: Keep Git publication compact by limiting committed outputs to code, manifests, and dashboard-ready payloads.
- [Phase 13]: Use one edition-scoped source-bundle abstraction for official and reviewed fallback variants; reject mixed provenance.
- [Phase 13]: Persist the Git commit SHA as parser identity and retain only compact hashes and metadata in committed artifacts.
- [Phase 13]: Keep normalized display-name fallback visible and fail closed on unresolved or ambiguous team identity.
- [Phase 13]: Register EURO qualifying as explicit pre_draw metadata with non-null source/output slots and no fabricated structures.
- [Phase 13]: Require all five structured resource classes and provenance fields before acceptance, with explicit source-shaped schemas.
- [Phase 13]: Use bounded explicit HTTPS capture and deterministic fixture replay with exact raw bytes in an ignored local store and compact accepted CSVs.
- [Phase 13]: Treat reviewed fallback as a complete edition-wide bundle and write blocked refresh metadata while retaining the last accepted output.
- [Phase 13]: Keep xGelo team_id canonical and stable while preserving FIFA code, UEFA source ID, current display name, and reviewed aliases.
- [Phase 13]: Allow only deterministic exact normalized-name fallback, and require visible warning/audit metadata for it.
- [Phase 13]: Preflight the sole approved Phase 12 release manifest before accepting competition-edition model pins.
- [Phase 13]: Represent EURO qualifying as explicit pre_draw metadata with real source/output slots and no fabricated structures.
- [Phase ?]: Capture-only is the default; accepted-directory publication remains an explicit opt-in for legacy replay checks and later plans own normal publication.
- [Phase ?]: A missing status URL is valid only when one unambiguous status and edition identity can be derived from validated mandatory structured resources.
- [Phase ?]: Derived status lineage is recorded as sorted contributing source artifact IDs and URL lineage, while canonical content hashes cover complete CSV bytes including headers.
- [Phase 13]: The accepted publisher validates the complete manifest and five compact tables before replacing only the edition directory.
- [Phase 13]: Derived status canonical content is hashed with its complete sorted source_artifact_id lineage, not the synthetic status artifact ID.
- [Phase 13]: data/competition/registries/refresh_batches remains outside the accepted replacement scope and is never created, renamed, or deleted by the publisher.
- [Phase 13]: The committed Nations League output remains a source-shaped seed; identity normalization and final canonical/hash-graph promotion stay with Plans 13-04, 13-11, and 13-12.
- [Phase ?]: EURO pre_draw status publishes canonical lifecycle_state and keeps source-shaped structure tables empty until official structures exist.
- [Phase ?]: Shared source registries and final normalized/hash transaction remain owned by Plans 13-11 and 13-12.
- [Phase ?]: Accepted results inherit identity, display, edition, schedule, mapping, and fixture-artifact fields from the exact normalized fixture match; source status and valid scores remain result-owned.
- [Phase ?]: Score-only changes are permitted and change the result row hash, while optional source identity or edition fields must match the normalized fixture contract.
- [Phase ?]: EURO pre_draw results use the explicit registry edition when the normalized fixture table is empty, preserving an exact zero-row schema without fabricated records.
- [Phase ?]: Canonical/hash helper extraction and all-target atomic rollback remain owned by Plans 13-11 and 13-12.
- [Phase 13]: Canonical and derived hash helpers write only to a supplied staging root; locks, snapshots, promotion, and rollback remain Plan 13-12 responsibilities.
- [Phase 13]: Raw SHA-256 and source/provenance fields remain unchanged while row, canonical-content, derived bundle, artifact-manifest, and self-hashes are regenerated.
- [Phase 13]: Bundle canonical_content_sha256 follows the established complete non-circular bundle-content CSV projection, while manifest self-hashes use the existing source-contract self-hash convention.
- [Phase ?]: The durable publication envelope owns exactly fourteen files; refresh_batches remains outside the target and cleanup scope.
- [Phase ?]: Canonical and manifest hash calculation remains delegated to Plan 13-11 helpers inside the transaction staging root.
- [Phase ?]: Production acquisition routes complete two-edition roots through normalized publication while isolated one-edition fixture replay remains supported.

## Accumulated Context

- The approved calibrated forecast release from v2.0 remains the shared model input for v3.0 until a later milestone changes release policy.
- Research indicates the main new complexity is competition rules: Nations League promotion and relegation paths, and EURO host-place plus Nations League-linked play-off topology.
- The dashboard surface stays static HTML or JS generated by R; this milestone does not introduce a new frontend framework or a server-backed API.

## Pending Todos

- Prepare Phase 14 planning around shared standings, form, and point-in-time forecast safety.

## Next Action

Run `$gsd-verify-work` for Phase 13.

## Session Continuity

**Last session:** 2026-08-14T14:14:18.948Z
**Stopped at:** Completed 13-source-contracts-and-competition-registry-12-PLAN.md
**Resume file:** None

## Performance Metrics

Plan 13-01 execution metrics are recorded below.

---
*State reset for milestone v3.0 on 2026-08-13*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 13-source-contracts-and-competition-registry P01 | 25 min | 2 tasks | 8 files |
| Phase 13-source-contracts-and-competition-registry P02 | 26 min | 2 tasks | 18 files |
| Phase 13 P03 | 27 min | 2 tasks | 5 files |
| Phase 13 P07 | 20min | 2 tasks | 4 files |
| Phase 13 P09 | 26min | 2 tasks | 3 files |
| Phase 13 P10 | 22min | 2 tasks | 4 files |
| Phase 13 P04 | 27min | 2 tasks | 4 files |
| Phase 13 P11 | 26m | 2 tasks | 4 files |
| Phase 13 P12 | 29min | 2 tasks | 4 files |
