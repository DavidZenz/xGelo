# Phase 16: EURO Qualifying Activation and Play-off Rules - Context

**Gathered:** 2026-08-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the EURO 2028 qualifying edition truthful before and after the official draw. Before the official draw-and-schedule snapshot, preserve an explicit `pre_draw` state with no fabricated competition structure or probabilities. After a complete official snapshot is accepted, activate real groups, fixtures, standings, and forecasts, then apply the official direct-qualification, host-place, best-runners-up, Nations League-linked play-off, and play-off-topology rules. Unresolved, blocked, or insufficient-source inputs remain explicit and suppress derived outputs.

This phase owns EURO qualifying activation and qualification logic. Shared dashboard rendering, filters, collapsed data credits, hourly refresh, browser smoke checks, atomic public promotion, and compact auto-push remain Phase 17 work.

</domain>

<decisions>
## Implementation Decisions

### Draw activation boundary
- **D-01:** Activate the EURO edition only when a complete official draw-and-schedule bundle has validated successfully. The initial active bundle must include an official status, groups, stable team identities, and a complete fixture/schedule resource. Empty standings and results are valid at initial activation.
- **D-02:** Require every official pairing to have a stable fixture ID and confirmed kickoff before the edition becomes active and fixtures become forecast-eligible.
- **D-03:** Treat post-draw corrections as a new complete official source bundle. Validate the candidate bundle before replacing the active edition state.
- **D-04:** Keep the last accepted bundle active while a replacement bundle is being validated. Expose a visible refresh or revision warning and keep the candidate isolated until acceptance.

### Host-reserved places
- **D-05:** Represent host places as explicit conditional slots, separate from ordinary direct qualification. Record which host associations are covered and whether each reserved slot is occupied, unused, or unresolved.
- **D-06:** Maintain an explicit allocation ledger when a host association also qualifies directly. Direct qualification consumes the relevant host slot first, and host capacity must never be counted twice.
- **D-07:** If the official rules or source bundle do not resolve whether a host place is guaranteed, publish an explicit conditional or `host_place_unresolved` state and suppress fabricated qualification probabilities.
- **D-08:** Show host-place treatment in the main qualification table, including the qualification status and source/rules lineage, rather than relegating it to audit metadata only.

### Best runners-up and play-off topology
- **D-09:** Derive the play-off topology from the accepted official rules and source bundle. Support every valid official format and mark an incomplete or unsupported format as unresolved rather than assuming a bracket.
- **D-10:** Consume Nations League-linked eligibility from the Phase 15 transition outcomes by stable `team_id`. Require a complete accepted eligibility source bundle; otherwise retain an unresolved eligibility state.
- **D-11:** Calculate best runners-up only after direct qualifiers and host allocations are known, using the official tie-break rules. Keep the result unavailable until the required standings and rules are complete.
- **D-12:** Treat each official play-off rule or topology change as a versioned, replayable source/rules revision. Publish it atomically and retain the prior accepted version until the revision validates.

### Pre-draw visibility and unavailable-state behavior
- **D-13:** Before the official draw, show the competition status, official draw date, source confidence, refresh timestamp, warnings, and empty or unavailable sections.
- **D-14:** Keep empty pre-draw sections schema-valid and pair them with explicit `pre_draw` or `unavailable` statuses. Do not use projected teams or placeholder structures that could be mistaken for official data.
- **D-15:** Before the official draw and schedule are available, publish no fixture-level or qualification probabilities. Expose only an edition-level forecast status explaining why forecasts are unavailable.
- **D-16:** Visible pre-draw messaging must state that the dashboard is awaiting the official draw, show the expected draw date, last refresh time, source bundle, and the reason forecasts are unavailable.

### Claude's Discretion
- Choose the exact R module boundaries, table names, column order, and compact artifact paths while preserving the existing edition-scoped contracts.
- Choose the machine-readable status and reason enums needed to represent conditional host slots, unresolved eligibility, unsupported topology, source revisions, and pre-draw suppression.
- Choose the exact official UEFA rules adapter and topology representation after research, provided it supports every valid official shape and fails closed when the rules are incomplete.
- Choose the presentation details of warnings and qualification ledger fields within the existing dashboard payload and state conventions; Phase 17 owns the shared visual renderer.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and acceptance criteria
- `.planning/ROADMAP.md` - Phase 16 goal, requirements, success criteria, and Phase 17 boundary.
- `.planning/REQUIREMENTS.md` - COMP-03, COMP-04, SIM-02, and SIM-04 acceptance requirements and traceability.
- `.planning/PROJECT.md` - v3.0 open-data policy, approved model/release context, file-based architecture, and source restrictions.
- `.planning/STATE.md` - current v3.0 decisions, EURO `pre_draw` status, official draw boundary, source authority, and accepted-release continuity.

### Prior competition contracts
- `.planning/phases/13-source-contracts-and-competition-registry/13-CONTEXT.md` - source bundle, provenance, stable identity, lifecycle, release pin, validation, and fail-closed publication decisions inherited by this phase.
- `.planning/phases/14-shared-competition-state-and-forecast-layer/14-CONTEXT.md` - edition isolation, state/forecast suppression, strict cutoff behavior, release authority, and state artifact contracts.
- `.planning/research/SUMMARY.md` - UEFA source volatility, pre-draw behavior, official-source boundary, and rules/data risks.
- `.planning/research/ARCHITECTURE.md` - source adapter, snapshot manifest, registry, state, payload, and publication boundaries.

### Existing source, registry, and publication implementation
- `R/competition/edition_registry.R` - edition lifecycle, official draw date, source bundle and release pins, blocked overlays, and registry revision validation.
- `R/competition/source_contracts.R` - accepted five-resource source bundle schemas, provenance validation, trusted paths, and canonical hash helpers.
- `R/competition/publication_hashes.R` - pre-draw publication guard and structural no-fabrication validation.
- `R/competition/publication_transaction.R` - accepted candidate validation and atomic edition publication transaction.
- `scripts/acquire_uefa_snapshot.R` - UEFA snapshot acquisition, EURO pre-draw guard, candidate staging, and publication flow.
- `scripts/build_competition_state.R` - edition-scoped state construction and existing pre-draw output behavior.

### Nations League and simulation integration
- `R/competition/uefa_nations_league_rules.R` - Phase 15 rules and transition eligibility interface, including unresolved EURO-linked eligibility handling.
- `R/competition/uefa_nations_league_outcomes.R` - durable Nations League outcomes and transition lineage consumed by EURO play-off eligibility.
- `R/forecast/monte_carlo.R` - existing deterministic simulation and outcome distribution patterns to extend for EURO qualification.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/competition/edition_registry.R` already models lifecycle state, official draw date, ruleset version, source bundle identity, release pins, and revision-controlled registry updates.
- `R/competition/source_contracts.R` already validates the five required source resources and their provenance, allowing the activation boundary to reuse the accepted-bundle contract.
- `R/competition/publication_hashes.R` already rejects fabricated structural rows while an edition is `pre_draw`.
- `R/competition/publication_transaction.R` already provides the candidate-isolation and atomic acceptance pattern needed for post-draw corrections.
- `R/competition/uefa_nations_league_rules.R` and `R/competition/uefa_nations_league_outcomes.R` already expose explicit Nations League transition lineage and unresolved external eligibility rather than inferring missing EURO facts.

### Established Patterns
- xGelo uses script-oriented R modules and file-backed CSV/RDS/JSON contracts with testthat coverage.
- Durable outputs carry stable IDs, source/release lineage, SHA-256 hashes, cutoff metadata, and machine-readable status/reason fields.
- Pre-draw and insufficient-source states are represented explicitly; missing data is not replaced with guessed teams, fixtures, standings, or probabilities.
- Candidate bundles are isolated and validated before publication; the last accepted bundle remains the rollback boundary during refresh.

### Integration Points
- The EURO edition registry and accepted five-resource bundle feed activation and post-draw state construction.
- Stable team identity and confirmed kickoff fields gate fixture activation and forecast eligibility.
- Phase 15 Nations League transition outcomes supply the external eligibility input for EURO-linked play-offs.
- Phase 14 edition-scoped standings, form, forecast suppression, and calibrated-release contracts provide the shared state layer consumed by EURO rules and simulations.
- Phase 17 will consume this phase's qualification states, simulation metadata, and pre-draw/unresolved statuses through the shared dashboard payload.

</code_context>

<specifics>
## Specific Ideas

- Keep EURO qualifying explicitly `pre_draw` until a complete official draw-and-schedule bundle exists; the official draw date is 6 December 2026.
- A complete initial post-draw bundle may have empty standings and results, but it must have stable teams, complete official pairings, fixture IDs, and confirmed kickoffs.
- Keep the previous accepted bundle active during candidate validation and surface the revision warning instead of exposing partial corrections.
- Keep host allocation, best-runners-up ordering, and Nations League eligibility visible and auditable in the qualification output rather than hiding them in implementation metadata.

</specifics>

<deferred>
## Deferred Ideas

- Shared dashboard rendering and responsive filtering remain Phase 17.
- Hourly launchd refresh, browser smoke checks, atomic cross-competition promotion, compact auto-commit, and push remain Phase 17.
- Full historical EURO qualifying editions and broader live-event evaluation remain future requirements.

</deferred>

---

*Phase: 16-euro-qualifying-activation-and-play-off-rules*
*Context gathered: 2026-08-23*
