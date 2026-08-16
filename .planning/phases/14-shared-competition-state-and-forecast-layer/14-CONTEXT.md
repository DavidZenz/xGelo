# Phase 14: Shared Competition State and Forecast Layer - Context

**Gathered:** 2026-08-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Build one edition-aware state, standings, form, and pre-match forecast layer for the 2026/27 UEFA Nations League and UEFA EURO 2028 qualifying. The layer must normalize match state and score semantics, derive replayable standings and form at explicit cutoffs, consume only an approved calibrated model release, publish auditable fixture forecasts, and prove that no future information enters a pre-match feature.

This phase includes the narrow validated calibration-release prerequisite needed because the currently pinned Phase 12 release exposes only a raw 1X2 fallback. It does not implement Nations League promotion/relegation and knockout rules, EURO qualification and play-off topology, tournament simulation, dashboard rendering, or atomic hourly publication. Those remain in Phases 15 through 17.

</domain>

<decisions>
## Implementation Decisions

### Match state and score semantics
- **D-01:** Retain both a strict canonical `match_status` and the original `source_status` on normalized match records. Source wording remains auditable; only the canonical value drives shared state behavior.
- **D-02:** Use two orthogonal axes. `match_status` represents lifecycle (`scheduled`, `in_progress`, `completed`, `postponed`, `abandoned`), while `completion_method` records `regulation`, `extra_time`, `penalties`, `awarded`, or `not_applicable`. Source adapters may map additional source values into this contract but may not silently invent a completed state.
- **D-03:** Store regulation score, final football score, shootout score, and `winner_team_id` separately. `final_*` includes extra time but excludes shootout kicks. An awarded result uses the official awarded score in `final_*` and carries `completion_method = awarded`.
- **D-04:** Keep `counts_for_standings` and `counts_for_form` separate. Postponed, abandoned, and unresolved matches default to false for both. Awarded matches may count for standings under the edition rules but default to excluded from form because no football was played.

### Standings and ranking boundary
- **D-05:** Retain reproducible computed metrics together with UEFA `official_rank` and `official_points`. Official rank is displayed when available; neither source silently overwrites the other, and every comparison has an explicit reconciliation status.
- **D-06:** Phase 14 computes universal table metrics: played, wins, draws, losses, goals for, goals against, goal difference, and points. It exposes a ruleset-adapter boundary; Phases 15 and 16 own competition-specific head-to-head, cross-group, and play-off ordering. Without an edition adapter, computed ordering is explicitly provisional.
- **D-07:** Key every standings snapshot by `edition_id`, `group_id`, `state_cutoff_utc`, and `source_bundle_id`. Include only standings-eligible results completed by the cutoff, and compare only with official standings from the same accepted source bundle.
- **D-08:** A mismatch in played, goals, goal difference, or points blocks the new edition-state publication and retains the previous accepted state. A rank-only mismatch may publish with a visible warning. When official standings are absent, computed metrics may publish with `rank_status = provisional`.

### Form windows and point-in-time cutoffs
- **D-09:** Expose two distinct form products: a user-facing last-five sequence and the approved model's existing 12-match EWMA. Every row records the applicable window and cutoff; the display window must not be substituted for a model feature.
- **D-10:** Competition-specific form uses only eligible matches from the selected edition. It never backfills from a prior Nations League edition or EURO qualifying cycle. If fewer than five matches exist, publish the available matches and their sample count.
- **D-11:** All-international form includes every eligible senior men's A international, including friendlies, and retains `competition_type`. Exclude unplayed and purely awarded results. Shootout kicks do not alter the football result used for form.
- **D-12:** Apply a strict exclusive pre-kickoff cutoff. Evidence completion time must be earlier than the forecast fixture kickoff. Date-only history qualifies only on an earlier calendar date; same-day rows without provable ordering are excluded. Retain `feature_cutoff_utc`, latest evidence time, and contributing match IDs. Missing descriptive history remains explicitly unavailable rather than imputed.

### Forecast eligibility, release, and output contract
- **D-13:** Generate a forecast only for a fixture with canonical `match_status = scheduled`, a confirmed kickoff, resolved team identities, and sufficient approved-release evidence. Retain a row for every suppressed fixture with an explicit reason such as `pre_draw`, `kickoff_unconfirmed`, `identity_unresolved`, `feature_evidence_unavailable`, or `release_not_calibrated`.
- **D-14:** The approved release contract controls the primary probability view. Once a validated calibrated release is approved, publish calibrated `p_home`, `p_draw`, and `p_away` as the consumer view while retaining raw 1X2 values, calibrator identity, and calibration status for audit. Validate both probability simplices. Never relabel raw probabilities as calibrated.
- **D-15:** The current pinned release `phase12-wc2026-incumbent-retained-v1` is `raw_1x2` with calibrator `fit_status = raw_fallback`. Phase 14 must therefore include or sequence a narrow, properly evaluated calibration-release revision and update both edition registry pins through the existing revision/audit contract. Public forecasts remain suppressed until that release is approved; no ad hoc dashboard calibration is allowed.
- **D-16:** Preserve the approved model's complete canonical score distribution on support `0:40` goals per team. Derive a compact top-10 scoreline projection and report omitted probability mass for later dashboard use. The modal score comes from the unchanged canonical distribution, independently of the calibrated 1X2 view.
- **D-17:** Publish quantitative uncertainty metadata: 1X2 entropy, maximum outcome probability, modal-score probability, top-10 scoreline mass, central 80 percent goal intervals, calculation method, support bound, and Monte Carlo seed/count when simulation is used. Use an explicit unavailable status and reason when a release cannot supply a field; do not invent qualitative confidence labels.

### Shared inputs, isolated edition state, and audit lineage
- **D-18:** Share only canonical team identity, the approved model/calibrator release, Elo/xG strength inputs, and historical senior international matches. Keep fixtures, results, status, groups, standings, competition form, forecasts, cutoffs, source bundles, warnings, and output paths strictly edition-scoped. Every edition-state row carries `edition_id`, and undeclared cross-edition joins fail validation.
- **D-19:** Give each real match one stable canonical `match_id` across competition and historical sources. Form and feature builders deduplicate on that ID, prefer the accepted competition record for competition-specific fields, and retain both source lineages.
- **D-20:** Each forecast retains edition/fixture identity, kickoff, accepted source-bundle ID and state hash, registry revision and ruleset version, release/calibrator/model hashes, team-identity registry hash, feature cutoff, latest evidence time, contributing form/history hashes, score support, calculation method, seed/count where applicable, and generation time.
- **D-21:** Shared-input failures invalidate both editions. Edition-specific failures invalidate only that edition's build; the other edition may still compute for diagnosis. Phase 17's atomic publication rule withholds the complete public batch on either failure and keeps the last accepted batch active. State is never copied between editions.

### Claude's Discretion
- Choose exact R module boundaries, table names, column ordering, hash projections, and compact artifact paths in sympathy with the existing file-based contracts.
- Choose a deterministic central-interval algorithm and the complete suppression/reconciliation reason enums, provided every reason remains machine-readable and auditable.
- Choose focused test-fixture sizes and helper decomposition while preserving the full production G=40 contract and strict cutoff behavior.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and phase scope
- `.planning/ROADMAP.md` - Phase 14 goal, requirements, success criteria, and boundaries with Phases 15 through 17.
- `.planning/REQUIREMENTS.md` - STATE-01 through STATE-04 and FORECAST-01 through FORECAST-03 acceptance requirements.
- `.planning/PROJECT.md` - v3.0 dashboard milestone, open-data constraints, approved architecture, and leakage-safe forecasting priority.
- `.planning/STATE.md` - current milestone decisions, approved-release continuity, edition separation, and next workflow state.
- `.planning/phases/13-source-contracts-and-competition-registry/13-CONTEXT.md` - locked source, provenance, identity, edition, release-pin, lifecycle, and fail-closed publication decisions inherited by this phase.

### Research and existing product behavior
- `.planning/research/FEATURES.md` - expected standings, match-state, form, forecast, uncertainty, and pre-draw behavior for the two competition dashboards.
- `MODEL-CARD.md` - existing 12-match EWMA feature semantics and historical forecast feature contract.
- `R/visualization/worldcup_dashboard.R` - existing calibrated/raw probability-view handling, bounded Negative Binomial score grids, cutoff-aware results, and dashboard forecast projections to generalize.

### Competition data and identity contracts
- `R/competition/source_contracts.R` - accepted five-resource source schemas, provenance validation, trusted paths, and canonical hash helpers.
- `R/competition/team_identity.R` - normalized fixture/result schemas, stable team identity resolution, mapping warnings, and accepted-result linkage.
- `R/competition/edition_registry.R` - edition lifecycle, source-bundle and approved-release pins, registry revisions, blocked overlays, and two-edition validation.

### Form, forecast, calibration, and release contracts
- `R/integration/rolling_form.R` - current lagged pre-match EWMA implementation and span-12 model-form behavior to adapt without leakage.
- `R/forecast/features.R` - latest-evidence lookups, feature evidence metadata, imputation flags, cutoff construction, and leakage assertions.
- `R/forecast/output.R` - existing fixture forecast and scoreline output shape.
- `R/forecast/monte_carlo.R` - expected-goal, 1X2, modal score, and complete scoreline-distribution outputs.
- `R/calibration/calibration_selection.R` - Phase 12 calibrated-versus-raw 1X2 selection and invariant score-distribution rules.
- `R/release/release_contract.R` - trusted approved-release preflight, model/calibrator loading, identity validation, and release metadata.
- `outputs/releases/phase12-wc2026-incumbent-retained-v1/model_contract.json` - current G=40 release contract and explicit raw 1X2 fallback status.
- `outputs/releases/phase12-wc2026-incumbent-retained-v1/release_manifest.csv` - current approved artifact identities and hashes used by registry preflight.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/competition/edition_registry.R` already preflights the trusted release, validates both edition IDs, preserves lifecycle separately from blocked state, and revision-controls model-release pins.
- `R/competition/team_identity.R` already gives normalized fixtures/results stable edition, fixture, team, source-artifact, display-name, and mapping-warning fields.
- `R/forecast/features.R` already provides source-date evidence columns, explicit imputation reasons, strict `source_date < fixture_date` checks, and reusable leakage assertions.
- `R/visualization/worldcup_dashboard.R` already derives exact bounded Negative Binomial score grids, keeps score distributions unchanged across 1X2 calibration, and exposes modal score and expected goals.
- `R/release/release_contract.R` already fails closed on stale, forged, or identity-drifted approved release handoffs.

### Established Patterns
- xGelo uses script-oriented R modules, direct `source()` composition, testthat coverage, and CSV/RDS/JSON files as explicit layer contracts.
- Durable outputs carry stable IDs, SHA-256 hashes, cutoff metadata, and source/release lineage; validators reject partial or inconsistent artifacts before promotion.
- Point-in-time features use strict earlier-than comparisons and preserve missing-source/imputation evidence instead of silently replacing absent values.
- The current Phase 12 release preserves a G=40 score distribution but explicitly declares raw 1X2 fallback, so calibration must be solved through a new approved release rather than consumer-side relabeling.

### Integration Points
- The new state loader consumes Phase 13 accepted edition bundles and registries, then produces edition-scoped canonical matches, standings snapshots, form views, and forecast artifacts.
- Historical match identity must bridge Phase 13's martj42 mapping artifacts with accepted competition results before form or forecast feature construction.
- Forecast generation resolves the registry-pinned release through `R/release/release_contract.R`, consumes leakage-safe feature rows from `R/forecast/features.R`, and reuses existing score-distribution logic.
- Phases 15 and 16 attach competition-specific ranking and outcome adapters to the shared state contract; Phase 17 consumes compact state/forecast artifacts and owns atomic dashboard publication.

</code_context>

<specifics>
## Specific Ideas

- Keep EURO qualifying truthful in `pre_draw`: no groups, fixtures, standings, form-by-edition, or probabilities are fabricated before an accepted official draw bundle exists.
- Treat descriptive last-five form and model EWMA as visibly separate products so users can understand recent results without changing the approved feature definition.
- Keep raw probability values available for audit even after calibrated probabilities become primary.
- Let rank-only reconciliation differences remain visible because later ruleset adapters may explain them; never hide aggregate source disagreements.

</specifics>

<deferred>
## Deferred Ideas

- Nations League head-to-head ordering, cross-group comparisons, promotion/relegation, quarter-final, and title-path logic remain Phase 15.
- EURO host-place handling, official post-draw groups, direct qualification, Nations League-linked play-offs, and variable topology remain Phase 16.
- Tournament simulation manifests, shared dashboard rendering, filters, collapsed data credits, hourly refresh, browser checks, and atomic public promotion remain Phase 17.

</deferred>

---

*Phase: 14-shared-competition-state-and-forecast-layer*
*Context gathered: 2026-08-16*
