# Phase 13: Source Contracts and Competition Registry - Context

**Gathered:** 2026-08-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the source, provenance, identity, and competition-edition registry contracts for the 2026/27 UEFA Nations League and UEFA EURO 2028 qualifying cycle. The phase must make authoritative structured UEFA snapshots capturable and auditable, support reviewed manual fallback bundles, normalize source records to stable xGelo identities, and register both editions for later state, rules, forecast, simulation, dashboard, and refresh work.

This phase does not implement competition standings, Nations League rules, EURO qualification rules, tournament simulation, shared dashboard rendering, or hourly publication orchestration. Those belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Snapshot shape and acquisition
- **D-01:** Accept structured UEFA resources only. Ordinary HTML pages and PDFs are not first-class accepted snapshot inputs for this contract.
- **D-02:** Assemble fixtures, groups, standings, results, and competition status into one edition-scoped accepted snapshot bundle, even when UEFA exposes them through separate structured resources.
- **D-03:** Treat each bundle as a candidate that must pass required-resource and schema validation before acceptance. On failure, reject the candidate and retain the last accepted bundle.
- **D-04:** Retain exact raw response bytes in an ignored, edition-scoped local snapshot store. Keep Git publication compact by committing manifests, hashes, parser identity, and compact normalized or dashboard-ready artifacts rather than raw response bodies.

### Provenance and fallback acceptance
- **D-05:** Record provenance at both bundle and raw-artifact level. Each artifact row must expose its source URL, retrieval time, byte count, raw SHA-256, parser identity, and fallback status; the accepted bundle must reference its component artifacts.
- **D-06:** A manual fallback requires explicit review before publication. The operator must record source, retrieval date, reason, operator note, and checksum, and the bundle must carry an acceptance/review state.
- **D-07:** A manual fallback replaces a complete edition-wide bundle. Do not silently mix official and fallback resources within one accepted edition snapshot.
- **D-08:** Parser identity is the Git commit only, as selected by the user. The implementation must make that identity available in each accepted snapshot manifest and keep the source bytes and hashes sufficient for replay.

### Team and edition identity
- **D-09:** Use an xGelo-owned stable `team_id` as the canonical team key. Retain FIFA code, UEFA source ID, current UEFA display name, and aliases as mapped attributes for interoperability and auditability.
- **D-10:** If a UEFA team cannot be mapped unambiguously, use normalized display-name matching as a fallback and emit a visible warning and audit record. The fallback must not be silent; planner and implementer should define the warning/mapping fields and ensure downstream publication can surface them.
- **D-11:** Keep canonical identity stable when a source display name changes. Preserve the current UEFA display name on the snapshot row and append reviewed historical names to an alias mapping.
- **D-12:** Assign explicit xGelo competition-edition IDs, including `uefa_nations_league_2026_27` and `uefa_euro_2028_qualifying`. Preserve source-provided edition IDs as metadata rather than using them as the sole internal key.

### Registry lifecycle and release slots
- **D-13:** Use a strict forward lifecycle: `pre_draw -> scheduled -> in_progress -> complete`. Any lifecycle may enter `blocked`; recovery requires explicit operator action and validation.
- **D-14:** Require a complete registry release contract before publication, including lifecycle state, ruleset version, source bundle, model release, and output bundle target. The EURO pre-draw entry uses explicit pre-draw source and output values rather than null release fields.
- **D-15:** Pin an explicit approved model-release ID in each edition registry entry. Changing the model release requires a new registry revision and audit entry.
- **D-16:** If a candidate refresh is blocked, keep the last accepted output active, mark the edition and refresh batch as blocked, and expose the failure and timestamp in metadata. Never publish a partial bundle or silently switch to an unreviewed fallback.

### Claude's Discretion
- Choose the concrete structured-source adapter boundaries, local directory layout, table schemas, validation implementation, and test fixtures in a way that follows the existing file-based R patterns.
- Choose the exact mapping warning fields and confidence representation needed to make the selected display-name fallback auditable, provided the warning is visible and ambiguous mappings cannot pass silently.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and phase scope
- `.planning/ROADMAP.md` - v3.0 milestone objective, Phase 13 boundary, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` - DATA-01 through DATA-04 and COMP-01 acceptance requirements and traceability.
- `.planning/PROJECT.md` - project constraints, open-data-first policy, source restrictions, and approved model/release context.
- `.planning/STATE.md` - v3.0 decisions: official UEFA authority, audited fallback, EURO `pre_draw`, atomic publication, and compact Git outputs.

### Domain research
- `.planning/research/SUMMARY.md` - UEFA source volatility, pre-draw behavior, recommended MVP boundary, and operational watch-outs.
- `.planning/research/ARCHITECTURE.md` - proposed source-adapter, snapshot-manifest, registry, payload, and refresh boundaries.

### Existing implementation patterns
- `.planning/codebase/STACK.md` - R/file-based runtime and dependency constraints.
- `.planning/codebase/ARCHITECTURE.md` - current raw/processed/output contracts and layer boundaries.
- `.planning/codebase/INTEGRATIONS.md` - existing external-source and publication integration points.
- `R/benchmark/registry.R` - existing project-root checks, canonical table hashing, schema validation, and registry foreign-key patterns.
- `R/release/release_contract.R` - existing release metadata, artifact identity, path, and validation conventions.
- `R/release/release_bundle.R` - existing hash-backed artifact manifest and fail-closed release patterns.
- `R/visualization/worldcup_dashboard.R` - current dashboard input validation and normalized fixture/team display patterns to generalize later.
- `scripts/update_worldcup_dashboard.R` - current static dashboard build and artifact publication entry point.
- `scripts/auto_update_worldcup_dashboard.sh` - current clean-worktree, upstream-alignment, validation, compact-publication, and fail-closed refresh pattern.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/benchmark/registry.R` already provides canonical scalar handling, SHA-256 row/table hashing, project-root containment checks, required-column validation, uniqueness checks, and foreign-key validation. Its Phase 09-specific schemas should not be copied blindly, but its validation style is a useful local pattern.
- `R/release/release_contract.R` and `R/release/release_bundle.R` provide release identity, file hashing, manifest, and fail-closed validation patterns that fit the snapshot and registry audit requirements.
- `R/visualization/worldcup_dashboard.R` validates source tables before deriving dashboard fixture fields and preserves separate source and display team values.

### Established Patterns
- The project is a script-oriented R repository with file-based CSV/RDS/JSON contracts, direct `source()` loading, and testthat coverage rather than an installed package namespace.
- Provenance and integrity are represented with explicit manifest columns and SHA-256 values in the existing benchmark and release work.
- Generated publication is kept separate from raw/local data, and the existing World Cup updater refuses dirty or diverged worktrees before publication.

### Integration Points
- Phase 13 source adapters and registry artifacts will feed the shared competition state layer in Phase 14.
- The canonical team registry must remain compatible with historical international results and the approved Phase 12 model release.
- Source bundle identity and registry release slots will later be consumed by simulation metadata, dashboard payloads, and the atomic refresh workflow.

</code_context>

<specifics>
## Specific Ideas

- Use an edition-scoped accepted bundle even if structured UEFA resources are split across endpoints.
- Keep exact raw bytes locally but keep the Git publication boundary compact.
- Keep EURO 2028 qualifying explicitly pre-draw until the official draw snapshot exists; do not synthesize groups or fixtures.
- Treat the normalized display-name fallback as an explicit warning path that requires careful audit fields, not as silent fuzzy matching.

</specifics>

<deferred>
## Deferred Ideas

- Competition-specific standings, match-status semantics, form windows, point-in-time forecasts, and leakage tests are Phase 14 work.
- Nations League promotion/relegation, quarter-final, and title-path rules are Phase 15 work.
- EURO qualifying activation, host places, Nations League-linked play-offs, and topology rules are Phase 16 work.
- Shared dashboard rendering, filters, collapsed data credits, hourly launchd refresh, browser smoke checks, atomic promotion, and compact auto-push are Phase 17 work.

No additional out-of-scope ideas were raised during discussion.

</deferred>

---

*Phase: 13-source-contracts-and-competition-registry*
*Context gathered: 2026-08-13*
