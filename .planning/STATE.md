---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: UEFA Competition Forecast Dashboards
current_phase: 14
current_phase_name: shared-competition-state-and-forecast-layer
status: executing
stopped_at: Completed 14-17-PLAN.md
last_updated: "2026-08-17T19:58:36.733Z"
last_activity: 2026-08-17
last_activity_desc: Completed Plan 14-17 deterministic production batch state and forecast expansion
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 35
  completed_plans: 32
---

# xGelo Project State

## Current Position

Phase: 14 (shared-competition-state-and-forecast-layer) — IN PROGRESS
Plan: 19 of 22 complete; Plan 14-18 is next
Status: Ready to execute
Last activity: 2026-08-17 — Completed Plan 14-17 deterministic production batch state and forecast expansion

## Progress

**Progress:** [█████████░] 91% (32/35 plans complete)

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 13 | Source Contracts and Competition Registry | Complete | 5/5 |
| 14 | Shared Competition State and Forecast Layer | Canonical state, cutoff-safe form, release-active forecast tracer, deterministic production batch state/forecast expansion, and edition-isolated candidates delivered (19/22 complete) | 7/7 |
| 15 | Nations League Rules and Outcomes | Not started | 2/2 |
| 16 | EURO Qualifying Activation and Play-off Rules | Not started | 4/4 |
| 17 | Shared Dashboards and Atomic Refresh Operations | Not started | 10/10 |

**Overall:** 1 of 5 phases complete (20%); Phase 14 now has a durable calibrated selector, dual-edition revision-2 authority, isolated schema-v2 transaction proof, canonical match identity/lifecycle semantics, cutoff-safe universal standings with fail-closed official reconciliation, honest form availability, and deterministic production state-to-forecast batches, with Plan 14-18 next.

## Project Reference

See `.planning/PROJECT.md` for the product definition, constraints, and current
milestone scope.

**Core value:** Accurate, calibrated international-football forecasting without
dependence on paid data feeds.

**Current focus:** Phase 14 — shared-competition-state-and-forecast-layer
for Nations League and EURO qualifying.

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
- [Phase ?]: Use Plan 13-12's production normalized publication transaction to regenerate the complete fourteen-target graph from committed compact fixtures; do not repair hashes manually.
- [Phase ?]: Keep accepted snapshots and refresh-batch history as separate trust boundaries; this loader validates only the replaceable accepted tree.
- [Phase ?]: Set bundle source_bundle_sha256 and artifact_manifest_sha256 before computing bundle canonical content so the canonical hash covers its complete non-circular projection.
- [Phase ?]: Plan 13-08 uses the user-selected option 1: explicit source-contract source_match_id enters before preprocessing, with scores, row order, and score-bearing hashes excluded from identity.
- [Phase ?]: Unique martj42 non-score projections use deterministic SHA-256 IDs; the duplicate Tahiti/New Caledonia projection uses two explicit reviewed source IDs.
- [Phase ?]: The current Phase 13 registry is primary and the legacy historical team map is supplemental, with current stable IDs taking precedence and three explicit historical aliases.
- [Phase ?]: Historical edition membership is assigned only through the explicit martj42_historical_v1 match-to-edition lookup.
- [Phase 13]: Route complete public acquisition refreshes through raw-source dual-edition handoffs and one fourteen-target transaction.
- [Phase 13]: Preserve isolated one-edition fixture replay and explicit blocked recovery compatibility boundaries.
- [Phase 14]: Keep Plan 14 release fixtures descriptor-only and reconstruct complete trusted roots from the incumbent model during tests.
- [Phase 14]: Bind fixture authority to a one-row self-hashed selector and exact manifest/object hashes while preserving distinct raw and fitted probability views.
- [Phase 14]: D-15 remains CALIBRATION_RELEASE_BLOCKED under unchanged RPS and strict calibration-improvement vetoes. — Frozen evidence worsened RPS by 0.0008328552 and calibration error by 0.00307133; authority remains raw and downstream promotion refuses blocked evidence.
- [Phase 14]: Plan 14-21 freezes one raw, 16 shrunk-scalar, and 28 regularized-vector remediation candidates; exploratory values never control selection.
- [Phase 14]: The unchanged Phase 12 outer gate approved the remediation evidence with zero reasons, but candidate_authority remains false pending Plan 14-22.
- [Phase 14]: Final candidate vector_w400_p0p010 was fitted on all 630 development rows only after the actual outer pass.
- [Phase 14]: Plan 14-22 makes the independent semantic replay and adversarial suite the calibration-remediation acceptance authority; producer pass flags and self-consistent hashes are insufficient.
- [Phase 14]: The acknowledged calibration-v2-gate-passed signal satisfies Plan 14-06's precondition without mutating release selectors, registries, public suppression, or runtime authority.
- [Phase 14]: Selector-only calibrated release authority — Runtime callers use the exact self-hashed approved_release.csv selector; direct manifests remain internal staging inputs.
- [Phase 14]: Plan 14-22 identity is mandatory for calibrated staging — The accepted manifest, gate, source release, model, and source calibrator hashes are pinned; staging does not write or promote a selector.
- [Phase 14]: Plan 14-07 installs a completely validated sibling candidate only through one guarded atomic directory rename; existing release IDs are never overwritten.
- [Phase 14]: Plan 14-07 preserves incumbent model, freeze, and final-evaluation bytes while development-only calibration leaves the score distribution unchanged.
- [Phase 14]: Plan 14-07 creates no approved release selector and changes no competition-edition registry row; authority promotion remains deferred.
- [Phase 14]: Allow only phase14-open-nb-incumbent-calibrated-v1 to satisfy the selector-candidate contract. — Explicit allowlisting prevents directory discovery, raw fallback selection, and unknown release authority.
- [Phase 14]: Keep the persisted selector candidate non-authoritative until Plan 14-09. — Runtime selector creation and both competition registry repins must remain one atomic transaction.
- [Phase 14]: Keep FORECAST-01 addressed but pending through Plan 14-08. — Requirement completion depends on downstream dashboard consumption of the calibrated release.
- [Phase 14]: Promote the selector and both competition-edition rows only through one locked transaction; stale expected bytes fail closed and no durable retry was attempted.
- [Phase 14]: Runtime and registry validation use phase14_resolve_approved_release(selector_path, trusted_release_root); direct release manifests remain internal staging inputs.
- [Phase 14]: Keep FORECAST-01 addressed but pending until downstream dashboard consumers expose the calibrated release lineage.
- [Phase 14]: Keep Phase 13 v1 source/normalized replay as the default and select v2 only through explicit schema branches.
- [Phase 14]: Preserve source_status verbatim; match_status and completion_method remain orthogonal, and absent evidence never creates completed state or score axes.
- [Phase 14]: Leave STATE-01 and STATE-02 pending until downstream canonical semantics, reconciliation, transaction proof, and durable promotion plans complete.
- [Phase 14]: Keep the schema-v2 candidate and rollback evidence isolated from durable accepted, registry, release, state, and dashboard files until the later promotion plan.
- [Phase 14]: Delegate normalization, hashing, manifests, loading, promotion, failure injection, and rollback to production callbacks; tests add assertions only.
- [Phase 14]: Leave STATE-01 and STATE-02 pending because downstream canonical semantics and durable promotion remain unfinished.
- [Phase ?]: Promote the exact fourteen-target Phase 13 envelope through the production snapshot/stage/promote transaction; exclude competition_editions.csv, refresh_batches, release authority, state outputs, rules, dashboards, and unrelated siblings.
- [Phase ?]: Use the production raw-store source handoff builder as the publication input and refresh all derived identities through production callbacks; never hand-edit hashes or provenance.
- [Phase ?]: Keep STATE-01 and STATE-02 pending until later semantic state and forecast consumers complete.
- [Phase ?]: Phase 14 Plan 14-13: Mint canonical match identity from score-free source projections and preserve canonical IDs across corrections.
- [Phase ?]: Phase 14 Plan 14-13: Prefer accepted competition semantics while retaining martj42 historical lineage, and validate source_status separately from match_status and completion_method.
- [Phase ?]: Phase 14 Plan 14-13: Keep STATE-02 and STATE-04 pending until all downstream owners complete.
- [Phase ?]: Plan 14-14 keeps universal standings arithmetic separate from competition-specific ordering; no adapter is explicitly provisional.
- [Phase ?]: Plan 14-14 requires counts_for_standings, completed paired scores, and evidence completion at or before the state cutoff.
- [Phase ?]: Plan 14-14 reconciles official aggregates only within the computed source bundle and retains prior state for aggregate, partial, or foreign mismatches.
- [Phase ?]: Keep competition last-five, all-senior last-five, and national-team xG EWMA as separate products; display result history never substitutes for xG evidence.
- [Phase ?]: Do not fabricate current national-team xG: the no-accepted-source registry preserves explicit unavailable/NA rows for Austria and Germany.
- [Phase ?]: Reject club rolling_form.csv, football-goal relabels, non-shot evidence, and non-exclusive point-in-time evidence at the national_team_xg adapter boundary.
- [Phase ?]: Plan 14-16: runtime forecast authority remains the exact self-hashed approved release selector; raw manifests are not fallback authority.
- [Phase ?]: Plan 14-16: immutable active predictors control evidence sufficiency; inactive national-team xG remains audited unavailable/NA, while synthetic xG-active releases suppress.
- [Phase ?]: Plan 14-16: required active shared-input failures fan out across edition candidates, while EURO pre_draw remains structurally empty and derived state stays edition-scoped.
- [Phase ?]: Phase 14 Plan 14-17: approved selector and immutable active-predictor manifest remain the sole batch forecast authority.
- [Phase ?]: Phase 14 Plan 14-17: production candidates use an exact eleven-artifact in-memory inventory with hashes and no Phase 17 durable promotion.
- [Phase ?]: Phase 14 Plan 14-17: shared active evidence is preflighted only for forecastable rows, preserving edition-local kickoff and status suppression.
- [Phase ?]: Phase 14 Plan 14-17: fixed startup seed 14017L and deterministic replay protect repeated dry-run batch outputs.

## Accumulated Context

- The approved calibrated forecast release from v2.0 remains the shared model input for v3.0 until a later milestone changes release policy.
- Research indicates the main new complexity is competition rules: Nations League promotion and relegation paths, and EURO host-place plus Nations League-linked play-off topology.
- The dashboard surface stays static HTML or JS generated by R; this milestone does not introduce a new frontend framework or a server-backed API.

## Pending Todos

- Downstream dashboards still need to consume the durable calibrated authority and expose its model/cutoff lineage; the shared forecast engine and state candidate now provide that contract.

## Next Action

Plan 14-18 is next. It builds on Plan 14-17's deterministic batch candidates, exact artifact manifests, and scoped forecast/state failure semantics.

## Session Continuity

**Last session:** 2026-08-17T19:41:06.289Z
**Stopped at:** Completed 14-17-PLAN.md
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
| Phase 13 P05 | 1h 10m | 2 tasks | 13 files |
| Phase 13 P08 | 36m | 1 tasks | 11 files |
| Phase 13 P13 | 43m | 2 tasks | 2 files |
| Phase 14 P01 | 17min | 3 tasks | 7 files |
| Phase 14 P02 | 21m | 2 tasks | 6 files |
| Phase 14 P03 | 17m | 2 tasks | 4 files |
| Phase 14 P04 | 41m | 2 tasks | 6 files |
| Phase 14 P21 | 1h21m | 2 tasks | 9 files |
| Phase 14 P22 | 56min | 2 tasks | 3 files |
| Phase 14 P06 | 48min | 2 tasks | 3 files |
| Phase 14 P07 | 43m | 2 tasks | 18 files |
| Phase 14 P08 | 21m | 2 tasks | 3 files |
| Phase 14 P09 | 1h 10m | 2 tasks | 5 files |
| Phase 14 P10 | 32m 26s | 3 tasks | 7 files |
| Phase 14 P11 | 14m 34s | 2 tasks | 2 files |
| Phase 14 P12 | 24m 39s | 1 tasks | 10 files |
| Phase 14 P13 | 1h 18m | 2 tasks | 4 files |
| Phase 14 P14 | 12m | 2 tasks | 2 files |
| Phase 14 P15 | 39 min | 2 tasks | 4 files |
| Phase 14 P16 | 36min | 1 tasks | 4 files |
| Phase 14 P17 | 47min | 2 tasks | 5 files |

### Blockers

- Plan 14-18 blocked: accepted UEFA Nations League Austria/Germany fixture has kickoff_confirmed=FALSE and blank confirmed_kickoff_at_utc; D-13 and the plan require confirmed kickoff before an available forecast, so no bundle promotion is safe.
