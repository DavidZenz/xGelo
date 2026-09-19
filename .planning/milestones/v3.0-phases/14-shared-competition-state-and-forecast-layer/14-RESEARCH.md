# Phase 14: Shared Competition State and Forecast Layer - Research

**Researched:** 2026-08-16
**Domain:** Edition-aware football competition state, point-in-time features, calibrated pre-match forecasting, and file-backed audit contracts
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Match state and score semantics
- **D-01:** Retain both a strict canonical `match_status` and the original `source_status` on normalized match records. Source wording remains auditable; only the canonical value drives shared state behavior.
- **D-02:** Use two orthogonal axes. `match_status` represents lifecycle (`scheduled`, `in_progress`, `completed`, `postponed`, `abandoned`), while `completion_method` records `regulation`, `extra_time`, `penalties`, `awarded`, or `not_applicable`. Source adapters may map additional source values into this contract but may not silently invent a completed state.
- **D-03:** Store regulation score, final football score, shootout score, and `winner_team_id` separately. `final_*` includes extra time but excludes shootout kicks. An awarded result uses the official awarded score in `final_*` and carries `completion_method = awarded`.
- **D-04:** Keep `counts_for_standings` and `counts_for_form` separate. Postponed, abandoned, and unresolved matches default to false for both. Awarded matches may count for standings under the edition rules but default to excluded from form because no football was played.

#### Standings and ranking boundary
- **D-05:** Retain reproducible computed metrics together with UEFA `official_rank` and `official_points`. Official rank is displayed when available; neither source silently overwrites the other, and every comparison has an explicit reconciliation status.
- **D-06:** Phase 14 computes universal table metrics: played, wins, draws, losses, goals for, goals against, goal difference, and points. It exposes a ruleset-adapter boundary; Phases 15 and 16 own competition-specific head-to-head, cross-group, and play-off ordering. Without an edition adapter, computed ordering is explicitly provisional.
- **D-07:** Key every standings snapshot by `edition_id`, `group_id`, `state_cutoff_utc`, and `source_bundle_id`. Include only standings-eligible results completed by the cutoff, and compare only with official standings from the same accepted source bundle.
- **D-08:** A mismatch in played, goals, goal difference, or points blocks the new edition-state publication and retains the previous accepted state. A rank-only mismatch may publish with a visible warning. When official standings are absent, computed metrics may publish with `rank_status = provisional`.

#### Form windows and point-in-time cutoffs
- **D-09:** Expose two distinct form products: a user-facing last-five sequence and the approved model's existing 12-match EWMA. Every row records the applicable window and cutoff; the display window must not be substituted for a model feature.
- **D-10:** Competition-specific form uses only eligible matches from the selected edition. It never backfills from a prior Nations League edition or EURO qualifying cycle. If fewer than five matches exist, publish the available matches and their sample count.
- **D-11:** All-international form includes every eligible senior men's A international, including friendlies, and retains `competition_type`. Exclude unplayed and purely awarded results. Shootout kicks do not alter the football result used for form.
- **D-12:** Apply a strict exclusive pre-kickoff cutoff. Evidence completion time must be earlier than the forecast fixture kickoff. Date-only history qualifies only on an earlier calendar date; same-day rows without provable ordering are excluded. Retain `feature_cutoff_utc`, latest evidence time, and contributing match IDs. Missing descriptive history remains explicitly unavailable rather than imputed.

#### Forecast eligibility, release, and output contract
- **D-13:** Generate a forecast only for a fixture with canonical `match_status = scheduled`, a confirmed kickoff, resolved team identities, and sufficient approved-release evidence. Retain a row for every suppressed fixture with an explicit reason such as `pre_draw`, `kickoff_unconfirmed`, `identity_unresolved`, `feature_evidence_unavailable`, or `release_not_calibrated`.
- **D-14:** The approved release contract controls the primary probability view. Once a validated calibrated release is approved, publish calibrated `p_home`, `p_draw`, and `p_away` as the consumer view while retaining raw 1X2 values, calibrator identity, and calibration status for audit. Validate both probability simplices. Never relabel raw probabilities as calibrated.
- **D-15:** The current pinned release `phase12-wc2026-incumbent-retained-v1` is `raw_1x2` with calibrator `fit_status = raw_fallback`. Phase 14 must therefore include or sequence a narrow, properly evaluated calibration-release revision and update both edition registry pins through the existing revision/audit contract. Public forecasts remain suppressed until that release is approved; no ad hoc dashboard calibration is allowed.
- **D-16:** Preserve the approved model's complete canonical score distribution on support `0:40` goals per team. Derive a compact top-10 scoreline projection and report omitted probability mass for later dashboard use. The modal score comes from the unchanged canonical distribution, independently of the calibrated 1X2 view.
- **D-17:** Publish quantitative uncertainty metadata: 1X2 entropy, maximum outcome probability, modal-score probability, top-10 scoreline mass, central 80 percent goal intervals, calculation method, support bound, and Monte Carlo seed/count when simulation is used. Use an explicit unavailable status and reason when a release cannot supply a field; do not invent qualitative confidence labels.

#### Shared inputs, isolated edition state, and audit lineage
- **D-18:** Share only canonical team identity, the approved model/calibrator release, Elo/xG strength inputs, and historical senior international matches. Keep fixtures, results, status, groups, standings, competition form, forecasts, cutoffs, source bundles, warnings, and output paths strictly edition-scoped. Every edition-state row carries `edition_id`, and undeclared cross-edition joins fail validation.
- **D-19:** Give each real match one stable canonical `match_id` across competition and historical sources. Form and feature builders deduplicate on that ID, prefer the accepted competition record for competition-specific fields, and retain both source lineages.
- **D-20:** Each forecast retains edition/fixture identity, kickoff, accepted source-bundle ID and state hash, registry revision and ruleset version, release/calibrator/model hashes, team-identity registry hash, feature cutoff, latest evidence time, contributing form/history hashes, score support, calculation method, seed/count where applicable, and generation time.
- **D-21:** Shared-input failures invalidate both editions. Edition-specific failures invalidate only that edition's build; the other edition may still compute for diagnosis. Phase 17's atomic publication rule withholds the complete public batch on either failure and keeps the last accepted batch active. State is never copied between editions.

### the agent's Discretion
- Choose exact R module boundaries, table names, column ordering, hash projections, and compact artifact paths in sympathy with the existing file-based contracts.
- Choose a deterministic central-interval algorithm and the complete suppression/reconciliation reason enums, provided every reason remains machine-readable and auditable.
- Choose focused test-fixture sizes and helper decomposition while preserving the full production G=40 contract and strict cutoff behavior.

### Deferred Ideas (OUT OF SCOPE)
- Nations League head-to-head ordering, cross-group comparisons, promotion/relegation, quarter-final, and title-path logic remain Phase 15.
- EURO host-place handling, official post-draw groups, direct qualification, Nations League-linked play-offs, and variable topology remain Phase 16.
- Tournament simulation manifests, shared dashboard rendering, filters, collapsed data credits, hourly refresh, browser checks, and atomic public promotion remain Phase 17.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STATE-01 | Compute competition standings with universal metrics and official rank. | Canonical match eligibility, replay reducer, official/computed reconciliation, and provisional ranking boundary. |
| STATE-02 | Preserve scheduled, completed, postponed, abandoned, extra-time, penalty, regulation, and final-score semantics. | Two-axis lifecycle/completion schema plus independent regulation/final/shootout score columns. |
| STATE-03 | Publish separate competition and all-international form with explicit windows and cutoffs. | Edition-filtered last-five, shared-history last-five, model EWMA separation, and exclusive evidence cutoffs. |
| STATE-04 | Keep Nations League and EURO state independent while sharing identity, strengths, and history. | Shared-input/edition-output boundary, cross-edition validation, and per-edition failure isolation. |
| FORECAST-01 | Use the approved calibrated release and expose model/data/feature cutoffs. | Blocking calibration-release revision, explicit approved-release selector, dual registry repin, and lineage schema. |
| FORECAST-02 | Publish calibrated 1X2, expected goals, modal score, bounded distribution, and uncertainty. | Existing G=40 benchmark distribution contract, top-10 projection, two independent probability views, and deterministic uncertainty derivation. |
| FORECAST-03 | Prove point-in-time safety and exclude future competition outcomes. | UTC evidence timestamps, conservative retrieval-time fallback, date-only exclusion rule, contributing IDs, and adversarial cutoff tests. |
</phase_requirements>

## Summary

Phase 14 should be planned as two hard-gated foundations followed by one vertical state-to-forecast tracer. First, create a narrow calibration-release revision for the retained incumbent using development-only, chronology-safe evidence; approve it only if the existing raw-versus-calibrated gates pass. The installed release currently declares `primary_probability_view = raw_1x2`, its calibrator is `raw_fallback`, and both edition rows pin that release. Forecast rows must therefore remain suppressed until a new immutable release is validated and both edition rows are revisioned together. [VERIFIED: `outputs/releases/phase12-wc2026-incumbent-retained-v1/model_contract.json`, `model/calibrator.rds`, `data/competition/registries/competition_editions.csv`]

Second, evolve the accepted competition schema before building state. The current Phase 13 fixtures/results/standings tables do not retain group identity on fixtures, kickoff confirmation, lifecycle source wording separately from canonical status, regulation/final/shootout scores, completion method, winner identity, or the official played/goals metrics required for reconciliation. Schema evolution must flow through the existing normalization, canonical hashing, manifest regeneration, and complete publication transaction; manually repairing CSV hashes would violate the established trust boundary. [VERIFIED: `R/competition/source_contracts.R`, `R/competition/team_identity.R`, `R/competition/publication_hashes.R`, accepted competition CSVs]

After those gates, build one edition-parameterized backend that emits canonical matches, replayed standings, two form products, fixture eligibility rows, full local G=40 distributions, compact top-10 projections, and lineage-rich forecasts. Reuse the approved model's benchmark adapter (`predict_registered_baseline()`) and distribution validators. Do not use the dashboard's `simulate_fixture_from_lambdas()` as the canonical producer: it currently defaults to a renormalized `0:10` grid, whereas the release contract is G=40. [VERIFIED: `R/benchmark/baselines.R`, `R/benchmark/contracts.R`, `R/visualization/worldcup_dashboard.R`]

**Primary recommendation:** Plan calibration approval and accepted-schema v2 as blocking prerequisites, then prove one scheduled Nations League fixture and one EURO `pre_draw` suppression through the complete shared engine before expanding lifecycle, standings, form, and batch coverage.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical match state and score normalization | API / Backend (batch R) | Database / Storage | Pure transformation owns semantics; file contracts retain source and canonical fields. |
| Match identity bridge and lineage | Database / Storage | API / Backend | A durable crosswalk owns stable IDs; builders consume it rather than reminting IDs. |
| Replayable standings and reconciliation | API / Backend (batch R) | Database / Storage | Reducer computes metrics; snapshots and reconciliation evidence are persisted. |
| Competition/all-international form | API / Backend (batch R) | Database / Storage | Point-in-time filters and windows are computation concerns with persisted evidence IDs. |
| Forecast eligibility and suppression | API / Backend (batch R) | CDN / Static | Backend decides eligibility; compact status rows become later static payload inputs. |
| G=40 forecasting and uncertainty | API / Backend (batch R) | Database / Storage | Approved model/calibrator produce and validate outputs; full grids remain local artifacts. |
| Dashboard rendering and atomic two-site publication | CDN / Static | Browser / Client | Explicitly deferred to Phase 17. |

## Project Constraints (from AGENTS.md)

- Use R and the existing script-oriented, file-backed architecture; orchestration remains `targets`. [VERIFIED: `AGENTS.md`, `_targets.R`]
- Keep xG and Elo combination at the integration/feature-table boundary. [VERIFIED: `AGENTS.md`]
- Use canonical stable team IDs and preserve source names. [VERIFIED: `AGENTS.md`, `R/competition/team_identity.R`]
- Prevent temporal leakage; only evidence strictly before prediction time is eligible. [VERIFIED: `AGENTS.md`, `R/forecast/features.R`]
- Preserve Negative Binomial goal distributions; do not replace them with Poisson. [VERIFIED: `AGENTS.md`, approved release model classes]
- Do not automate FotMob scraping; Phase 14 requires no new external data source. [VERIFIED: `AGENTS.md`, `.planning/REQUIREMENTS.md`]
- Make random paths reproducible with explicit seeds; analytic G=40 production should record simulation fields as unavailable/not used. [VERIFIED: `AGENTS.md`, CONTEXT D-17]
- Use `testthat`, run focused tests frequently, and verify before committing. [VERIFIED: `AGENTS.md`]
- Do not edit unread files, remove unrelated code, or disturb unrelated dirty worktree files. [VERIFIED: `AGENTS.md`, bounded research worktree inspection]

## Standard Stack

No new package installation is needed. Use the already installed project stack and existing APIs. [VERIFIED: local R namespace/version audit]

### Core

| Library | Installed Version | Purpose | Why Standard Here |
|---------|-------------------|---------|-------------------|
| R | 4.6.1 | Runtime, UTC/date handling, reducers, serialization | Project runtime and all existing modules. |
| `stats` | R 4.6.1 | `dnbinom()`, CDF/quantile operations, entropy inputs | Official mean/dispersion NB parameterization; deterministic analytic grids. |
| `MASS` | 7.3-65 | Approved Negative Binomial model objects | The approved release contains `negbin`/`glm` fits. |
| `digest` | 0.6.39 | SHA-256 rows, tables, and artifacts | Existing Phase 13/benchmark/release integrity contract. |
| `jsonlite` | 2.0.0 | Model/release contracts | Existing structured contract reader/writer. |
| `testthat` | 3.3.2 | Unit and integration validation | Existing test framework; supports focused `test_file()` runs and failure assertions. |
| `targets` | 1.12.0 | Durable pipeline orchestration | Existing project orchestration boundary. |

### Supporting

| Library | Installed Version | Purpose | When to Use |
|---------|-------------------|---------|-------------|
| `dplyr` | 1.2.1 | Existing table transforms | Only where it improves clarity; contract validators should remain explicit and deterministic. |
| `lubridate` | 1.9.5 | Existing date parsing | Prefer explicit UTC `as.POSIXct(..., tz = "UTC")` at trust boundaries. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing benchmark G=40 adapter | Dashboard `0:10` helper | Rejected: wrong support and renormalization boundary for Phase 14. |
| Analytic NB grid | 50,000-draw Monte Carlo | Rejected for current release: slower, introduces sampling error, and is unnecessary. |
| Explicit match-identity crosswalk | Recompute IDs from mutable scores/status | Rejected: corrections would change identity and break lineage. |
| Existing file contracts | New database/API | Rejected: outside milestone architecture and unnecessary for static batch outputs. |

**Installation:** None.

## Package Legitimacy Audit

Not applicable. This phase should install no external packages; every recommended package is already used by the repository and present in the local R environment. [VERIFIED: codebase and local namespace audit]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 13 accepted bundle + edition registry
        |                         Shared identity/history/strengths
        |                                      |
        v                                      v
Accepted-schema v2 validator ---> canonical match builder <--- canonical match crosswalk
                                           |
                        +------------------+------------------+
                        |                                     |
                        v                                     v
             standings replay/reconcile            point-in-time form views
                        |                                     |
                        +------------------+------------------+
                                           v
                                  fixture eligibility gate
                         scheduled + confirmed + identities + evidence?
                              | yes                         | no
                              v                             v
                approved calibrated release?       suppression row/reason
                         | yes       | no
                         v           v
                G=40 model grid   release_not_calibrated
                         |
                 raw 1X2 + expected goals + modal score
                         |
                 approved calibrator (1X2 only)
                         |
              calibrated consumer 1X2 + uncertainty
                         |
          full local grid + compact top-10 + lineage manifest
                         |
             edition-local candidate validation/promotion
                         |
              Phase 17 static payload/publication boundary
```

### Recommended Project Structure

```text
R/
├── competition/
│   ├── match_state.R          # canonical lifecycle, score, eligibility, identity bridge
│   ├── standings.R            # replay reducer, provisional ordering, reconciliation
│   ├── form.R                 # last-five and model-EWMA products with evidence cutoffs
│   ├── forecast_layer.R       # release-backed G=40 forecast and uncertainty projection
│   └── state_bundle.R         # edition-scoped build, validation, hashes, local promotion
└── release/
    └── calibration_revision.R # incumbent-only dev calibration gate and release revision
scripts/
└── build_competition_state.R  # explicit edition/both-edition entry point
tests/
├── fixtures/phase14/          # lifecycle, reconciliation, cutoff, release fixtures
└── testthat/test_phase14_*.R
outputs/competition/<edition_id>/
├── state/                     # compact accepted state/form/forecast tables
├── audit/                     # manifests, reconciliation and suppression rows
└── local/score_distributions.rds # full G=40 grids; not a compact Git payload
```

### Pattern 1: Candidate -> Validate -> Promote

Build each edition under a temporary candidate root, validate every table/hash/foreign key, then replace only that edition's last accepted state. A standings aggregate mismatch must leave the prior accepted state untouched. Phase 17 later adds all-or-nothing public promotion across both editions; Phase 14 must not pre-empt that boundary. [VERIFIED: CONTEXT D-08/D-21 and Phase 13 transaction pattern]

### Pattern 2: Source-independent semantics, source-retaining rows

Canonical rows should contain `source_status` plus strict `match_status`, and source score fields plus validated regulation/final/shootout projections. Unknown source values fail or map to an explicit unresolved state; they never silently become completed. [VERIFIED: CONTEXT D-01 through D-04]

### Pattern 3: Explicit evidence time

Use `result_evidence_at_utc` as the inclusion timestamp. Prefer a validated source completion timestamp; when absent, use the accepted source artifact retrieval timestamp as a conservative availability bound. Date-only history is eligible only when `history_date < as.Date(kickoff_utc, tz = "UTC")`. Persist latest evidence time and contributing match IDs. [VERIFIED: CONTEXT D-12 and Phase 13 artifact retrieval metadata]

### Pattern 4: Two probability contracts

The canonical score grid produces raw 1X2, expected goals, modal score, and score intervals. The fitted calibrator changes only the consumer 1X2 vector. Validate raw/grid mass and calibrated 1X2 independently; do not force calibrated 1X2 to reconcile back to the unchanged score grid. [VERIFIED: Phase 12 calibration and benchmark contracts]

### Pattern 5: Shared-input allowlist

Only identity, approved release, strengths, and historical matches are shared. Every derived row carries the target `edition_id`. Competition form rejects foreign editions; all-international form allows them only through a declared `history_scope = all_senior_international` path. [VERIFIED: CONTEXT D-18]

### Anti-Patterns to Avoid

- **Forecast before release approval:** raw fallback must produce `release_not_calibrated`, never a probability row labeled calibrated.
- **Schema logic only downstream:** if the accepted adapter drops shootout/group/official metrics, Phase 14 cannot reconstruct them truthfully.
- **Using score as match identity:** score corrections must not change `match_id`.
- **Ranking by generic sort and calling it official:** generic ordering is provisional until Phase 15/16 adapters apply official tie-breakers.
- **Using `<=` at kickoff:** equality is leakage; eligibility is strictly earlier.
- **Imputing missing history to zero:** descriptive form is unavailable with sample count/reason, not fabricated.
- **One forecast file per fixture:** repeated model loads and tiny files create severe I/O overhead; build one edition batch.

## Dependency Ordering for the Planner

1. **Wave 0 — tests and fixtures:** add Phase 14 lifecycle, score, standings, same-timestamp, date-only, cross-edition, raw-release, calibrated-release, and G=40 fixtures.
2. **Gate A — calibrated release revision:** create an explicit approved-release selector that can choose one immutable revision without "latest directory" logic; build incumbent development OOF calibration evidence; run the existing vetoes; abort/suppress if it fails; stage and validate the revision.
3. **Gate B — atomic dual registry repin:** update both rows in memory, increment both revisions/audits, validate against the explicit approved release, then atomically replace `competition_editions.csv`. A split pin is invalid.
4. **Accepted-schema v2:** extend fixture/result/standings resource fields and regenerate the complete Phase 13 canonical/hash graph through existing helpers.
5. **Canonical match + identity bridge:** produce stable canonical matches and source crosswalks before standings or form.
6. **Vertical tracer:** one scheduled Nations League fixture flows through eligibility, cutoff-safe `elo_diff`, G=40, calibrated 1X2, top-10, uncertainty, and lineage; EURO produces truthful `pre_draw` edition status with no fabricated fixture.
7. **Expansion:** lifecycle matrix, standings/reconciliation, competition form, all-international form, suppression matrix, and edition-local state promotion.
8. **Integration/performance gate:** both editions, shared-input invalidation, edition-specific isolation, deterministic replay, compact-output boundary, and full regressions.

Gate A is an empirical gate: the planner must not assume that incumbent calibration will pass. If it fails, the correct outcome is an explicit blocked checkpoint and continued forecast suppression, not threshold relaxation. [VERIFIED: CONTEXT D-15 and Phase 12 calibration-selection code]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Negative Binomial score grid | Custom PMF or simulation approximation | `predict_registered_baseline()` + `benchmark_one_distribution()` | Preserves the approved model's G=40 and raw-tail contract. |
| 1X2 calibration | Dashboard-specific rescaling | `fit/apply_phase12_1x2_calibrator()` plus selection vetoes | Keeps calibration evidence, model identity, and unchanged score distribution auditable. |
| Probability validation | Ad hoc sum checks | Existing benchmark/proper-score validators | They enforce full rectangles, support, finite mass, and market reconciliation. |
| Release trust | Newest directory/mtime selection | Hash-backed release preflight plus explicit approved-release selector | Prevents ambiguous or stale release authority. |
| Source/registry hashing | Manual CSV hash edits | Phase 13 canonical hash, manifest, and transaction helpers | The files form one linked integrity graph. |
| Generic UEFA tie-breakers | Universal custom sorter | Provisional order + Phase 15/16 ruleset adapters | Competition-specific rules are deferred and versioned. |

**Key insight:** the difficult work is contract integrity and point-in-time lineage, not arithmetic. Existing project validators already cover the most dangerous edges; Phase 14 should compose and extend them.

## Common Pitfalls

### Pitfall 1: A second immutable release makes the current resolver ambiguous

**What goes wrong:** `preflight_phase12_approved_release()` currently requires exactly one manifest candidate below `outputs/releases`; retaining v1 and adding v2 causes preflight failure. [VERIFIED: `R/release/release_contract.R`]

**How to avoid:** add an explicit hash-backed approved-release selector/pointer and make release/registry validation accept an exact release ID and manifest path. Never select by modification time.

### Pitfall 2: Incumbent calibration is not already frozen as a Phase 12 candidate

**What goes wrong:** Phase 12 calibration artifacts cover `phase11_rf_dynamic_elo_open`; the installed incumbent calibrator is only a compatibility `raw_fallback`. The Phase 12 freeze candidate list does not contain `open_nb_incumbent`. [VERIFIED: Phase 12 freeze/calibration artifacts]

**How to avoid:** create a narrow calibration-revision manifest binding the exact incumbent model hash, Phase 09 development predictions, recipe/protocol hashes, chronology, and gate result. Do not rewrite the historical final-evaluation manifest or reopen WC2026 labels.

### Pitfall 3: Accepted schema cannot support required reconciliation

**What goes wrong:** current accepted standings retain only position and points, while fixtures lack group identity and score-completion detail. [VERIFIED: accepted CSVs and Phase 13 schemas]

**How to avoid:** evolve the accepted schema first and exercise it with complete lifecycle/standings fixtures before implementing reducers.

### Pitfall 4: Same-day evidence leaks through date-only helpers

**What goes wrong:** existing forecast helpers compare `Date` values and can only prove day ordering, not same-day ordering. [VERIFIED: `R/forecast/features.R`]

**How to avoid:** use UTC timestamps for competition evidence; exclude same-day historical rows that have date only; test `evidence == kickoff` and one-second-before boundaries.

### Pitfall 5: Calibration changes the displayed scoreline

**What goes wrong:** a consumer tries to make top scorelines agree with calibrated 1X2 and silently distorts the approved distribution.

**How to avoid:** modal score, expected goals, top-10, and intervals always come from the unchanged G=40 grid; calibrated 1X2 is a separate consumer view. [VERIFIED: CONTEXT D-14/D-16 and Phase 12 invariants]

### Pitfall 6: Full G=40 grids bloat Git or memory

**What goes wrong:** each fixture has 1,681 cells; writing repeated CSV grids or expanding them per simulation wastes space and time.

**How to avoid:** load the approximately 142 MB approved model once per build, predict the batch once, store compressed full grids locally, publish only top-10 plus hashes/metadata, and validate bounded artifact size. [VERIFIED: release manifest byte count and G=40 rectangle]

## Code Examples

### Strict point-in-time eligibility

```r
# Source: CONTEXT D-12; adapt into R/competition/form.R
kickoff_utc <- as.POSIXct(fixture$kickoff_utc, tz = "UTC")

competition_ok <- matches$counts_for_form &
  !is.na(matches$result_evidence_at_utc) &
  as.POSIXct(matches$result_evidence_at_utc, tz = "UTC") < kickoff_utc

history_ok <- matches$date_precision == "date" &
  as.Date(matches$match_date) < as.Date(kickoff_utc, tz = "UTC")

stopifnot(!any(matches$result_evidence_at_utc[competition_ok] >= kickoff_utc))
```

### Release-backed G=40 and separate calibrated 1X2

```r
# Source: R/benchmark/baselines.R; R/calibration/probability_calibration.R
predicted <- predict_registered_baseline(
  fit = release$model,
  fixtures = feature_rows,
  support_max = 40L
)

raw <- setNames(
  unlist(predicted$predictions[1, c("p_home", "p_draw", "p_away")]),
  c("home", "draw", "away")
)
consumer <- apply_phase12_1x2_calibrator(release$calibrator, raw)

stopifnot(abs(sum(raw) - 1) < 1e-10)
stopifnot(abs(sum(consumer) - 1) < 1e-10)
```

### Deterministic top-10 and central 80% intervals

```r
# Source: official R dnbinom/quantile semantics and existing benchmark grid contract
grid <- predicted$distributions
grid <- grid[order(-grid$probability, grid$home_goals + grid$away_goals,
                   grid$home_goals, grid$away_goals), ]
top10 <- utils::head(grid, 10L)
top10_mass <- sum(top10$probability)
top10_omitted_mass <- 1 - top10_mass

discrete_interval <- function(goals, probability) {
  marginal <- rowsum(probability, goals, reorder = TRUE)
  support <- as.integer(rownames(marginal))
  c(lower = support[which(cumsum(marginal) >= 0.10)[1]],
    upper = support[which(cumsum(marginal) >= 0.90)[1]])
}
```

## State of the Art

| Old/Current Approach | Phase 14 Approach | Impact |
|----------------------|-------------------|--------|
| Sole release discovered by directory scan | Explicit approved immutable release revision | Multiple releases remain auditable without ambiguous resolution. |
| Raw retained-incumbent 1X2 | Development-gated fitted calibration or continued suppression | Prevents raw probabilities being mislabeled. |
| Phase 13 source-shaped status and score pair | Canonical lifecycle + completion method + separated scores | Supports postponed/abandoned/ET/penalties/awards truthfully. |
| Date-only latest-before feature lookup | UTC evidence cutoff plus conservative date-only rule | Proves same-day leakage safety. |
| Dashboard 0:10 display helper | Approved G=40 benchmark distribution | Matches release support and preserves tail audit. |
| One blended probability presentation | Raw grid-derived markets + calibrated consumer 1X2 | Keeps score forecasts invariant and calibration auditable. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | None. Recommendations are derived from locked decisions, inspected code/artifacts, or cited official documentation. | — | — |

## Planning Resolutions

1. **Calibration is an empirical pass-or-block gate.** The executor computes the frozen development comparison before any release authority changes. A pass requires every existing support, coverage, score-identity, RPS, Brier, log-loss, fold-stability, and strict calibration-improvement veto to pass unchanged. Any failure records `CALIBRATION_RELEASE_BLOCKED`, leaves the approved selector and both edition pins byte-identical, and retains `release_not_calibrated` suppression. Final holdout labels are never reopened and raw 1X2 is never relabelled as calibrated.

2. **Adapter-specific completion, kickoff-confirmation, and split-score fields are optional and fail closed.** The accepted schema exposes typed canonical inputs, but an absent or unmapped source field remains missing/unresolved. Dependent standings, form, or forecast behavior is blocked or suppressed until an accepted adapter proves the mapping; no source adapter may infer completion or scores from unrelated fields.

3. **Canonical match IDs use a durable crosswalk.** `data/competition/registries/match_identity.csv` maps competition and historical source IDs to one canonical `match_id` with one-to-one constraints and explicit reviewed collision rows. Minting inputs are stable source identity, edition, teams, scheduled time/date, and neutral/venue context; scores, lifecycle/status, row order, and score-bearing hashes are excluded so corrections cannot remint identity.

4. **National-team xG is optional shared evidence whose requiredness comes from the immutable release manifest.** Repository evidence fixes this boundary: `data/processed/rolling_form.csv` contains domestic clubs only; the Phase 10 feature contract registers xGF/xGA/xGD EWMA as optional open/derived predictors; and the approved Phase 09 incumbent manifest activates only `elo_diff` while recording xGF/xGA/xGD as `missing_or_zero_variance`/dropped. Phase 14 therefore adds a declared `national_team_xg` source registry/adapter that accepts only reviewed, shot-derived, point-in-time senior national-team rows with stable match/team IDs, evidence timestamps, and source hashes. It adds no scraper/API and rejects club xG or goals relabelled as national-team xG. Current Austria/Germany xG availability is `unavailable` with reason/source/sample_count/cutoff fields and `NA` descriptive/model-form values per D-09/D-12/D-18.

   `phase14_adapt_matches_for_forecast()` maps canonical rows to the exact `build_forecast_feature_table()` match contract (`date`, canonical home/away names, scores, `match_id`, and `venue`) through the accepted team registry and explicit kickoff/cutoff. `phase14_build_release_features()` hash-binds `active_predictors`/`dropped_predictors_with_reason`, requires strictly prior evidence only for active predictors, and permits registered internal missingness only for inactive dropped predictors while public xG remains unavailable/NA. The current Elo-only approved release can forecast Austria versus Germany through G=40 with unavailable xG recorded in lineage; a synthetic xG-active release suppresses that fixture as `feature_evidence_unavailable` until accepted national-team xG covers both teams before kickoff. Failure fan-out applies to required active shared inputs; optional inactive xG absence is audited without invalidating both editions. Production tests must prove adapter columns, strict-before Elo, Elo-only availability, xG-active suppression, and club-only rolling-form rejection.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| R | All Phase 14 code/tests | ✓ | 4.6.1 | — |
| testthat | Validation architecture | ✓ | 3.3.2 | — |
| digest | SHA-256 contracts | ✓ | 0.6.39 | — |
| jsonlite | Release/model JSON | ✓ | 2.0.0 | — |
| MASS | Approved NB models | ✓ | 7.3-65 | — |
| targets | Pipeline integration | ✓ | 1.12.0 | Direct script runner for focused diagnosis only |
| Phase 13 accepted bundles | State inputs | ✓ | schema v1 | Evolve through fixture-backed schema v2 before state use |
| Calibrated approved release | FORECAST-01/02 | ✗ | current release is raw fallback | Blocking calibrated release revision; otherwise suppress forecasts |
| Live UEFA structured API | Not required for implementation | unavailable in prior Phase 13 audit | — | Deterministic accepted fixtures/manual reviewed source bundles |

**Missing dependencies with no fallback:** approved fitted calibrated release for public forecasts.

**Missing dependencies with fallback:** live UEFA access is not required for Phase 14 code or fixture validation; production source-field activation remains fail-closed.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.3.2 |
| Config file | none; repository uses direct `testthat::test_file()` / `test_dir()` |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R")'` |
| Full Phase 14 command | `Rscript --vanilla -e 'files <- Sys.glob("tests/testthat/test_phase14_*.R"); lapply(files, testthat::test_file)'` |
| Full repository command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STATE-01 | Replay universal standings; reconcile same-bundle official metrics; block aggregate mismatch; warn rank-only mismatch | unit/integration | `testthat::test_file("tests/testthat/test_phase14_standings.R")` | No - Wave 0 |
| STATE-02 | Lifecycle/completion axes and regulation/final/shootout/awarded score invariants | unit/property matrix | `testthat::test_file("tests/testthat/test_phase14_match_state.R")` | No - Wave 0 |
| STATE-03 | Separate last-five competition/all-international and 12-match EWMA; strict cutoffs and sample counts | unit/integration | `testthat::test_file("tests/testthat/test_phase14_form.R")` | No - Wave 0 |
| STATE-04 | Shared-input allowlist, edition-scoped outputs, explicit cross-edition rejection and failure isolation | integration | `testthat::test_file("tests/testthat/test_phase14_state_bundle.R")` | No - Wave 0 |
| FORECAST-01 | Raw release suppresses; fitted release resolves; both registry pins revise atomically; lineage exposed | integration/security | `testthat::test_file("tests/testthat/test_phase14_calibration_release.R")` | No - Wave 0 |
| FORECAST-02 | Full 41x41 grid, top-10 mass, expected goals/modal invariance, calibrated simplex, intervals/entropy | unit/integration/performance | `testthat::test_file("tests/testthat/test_phase14_forecast_layer.R")` | No - Wave 0 |
| FORECAST-03 | One-second-before passes; equal/after fails; same-day date-only fails; contributing IDs/hash replay | adversarial/integration | `testthat::test_file("tests/testthat/test_phase14_cutoffs.R")` | No - Wave 0 |

### Blocking Prerequisite Tests

- Calibration revision never reads WC2026 label artifacts and binds the exact incumbent model hash, development predictions, protocol, recipe, and code hash.
- Calibration failure leaves the approved selector and both registry pins unchanged.
- Adding v2 beside v1 is unambiguous only through the explicit approved-release selector.
- A forged calibrator hash, model identity, primary view, selector hash, or split registry pin fails before RDS use/forecasting.
- Accepted-schema v2 regeneration preserves Phase 13 raw hashes/provenance and updates the complete canonical/manifest graph through existing helpers.

### Required Adversarial Matrix

| Surface | Cases |
|---------|-------|
| Lifecycle | scheduled, in_progress, completed regulation, extra_time, penalties, awarded, postponed, abandoned, unknown source token |
| Scores | missing pairs, one-sided score, tied regulation then ET, tied final then penalties, shootout excluded from final, awarded without football form |
| Cutoffs | evidence < kickoff, evidence == kickoff, evidence > kickoff, prior-day date-only, same-day date-only, missing evidence time |
| Standings | exact match, rank-only mismatch, points mismatch, played mismatch, goals mismatch, official absent, foreign source bundle |
| Editions | NL-only failure, EURO-only failure, shared identity/release failure, undeclared cross-edition join, explicit all-history join |
| Forecasts | pre_draw, kickoff_unconfirmed, identity_unresolved, evidence unavailable, raw release, calibrated release, status ineligible |
| Distribution | exactly 1,681 rows/fixture, support 0:40, normalized mass, raw-tail metadata, deterministic modal tie-break, top-10 omitted mass |

### Performance Checks

- Load the approved model/calibrator once per build, not once per fixture.
- Predict all eligible fixtures in one adapter call.
- Assert one full G=40 grid is 1,681 rows per fixture and benchmark representative batches.
- Compare analytic output byte size with compressed local RDS and enforce a compact top-10 publication limit.
- Require deterministic output hashes across two identical runs.
- Keep the per-task quick suite under 30 seconds; run the repository suite only at wave/phase gates.

### Sampling Rate

- **Per task commit:** focused owning `test_phase14_*.R` file.
- **Per wave merge:** all Phase 14 test files plus directly affected Phase 12/13 regression files.
- **Phase gate:** full repository suite green, or any unrelated pre-existing failure documented with unchanged evidence; calibrated release preflight and both edition registry validation must pass in a fresh R process.

### Wave 0 Gaps

- [ ] `tests/fixtures/phase14/match_lifecycle_cases.csv`
- [ ] `tests/fixtures/phase14/standings_reconciliation_cases.csv`
- [ ] `tests/fixtures/phase14/point_in_time_history.csv`
- [ ] `tests/fixtures/phase14/raw_release/` and `calibrated_release/` compact trusted-root fixtures
- [ ] `tests/testthat/test_phase14_match_state.R`
- [ ] `tests/testthat/test_phase14_standings.R`
- [ ] `tests/testthat/test_phase14_form.R`
- [ ] `tests/testthat/test_phase14_cutoffs.R`
- [ ] `tests/testthat/test_phase14_calibration_release.R`
- [ ] `tests/testthat/test_phase14_forecast_layer.R`
- [ ] `tests/testthat/test_phase14_state_bundle.R`

This section is sufficient to seed `14-VALIDATION.md`; task IDs can be added after the planner fixes the final plan decomposition.

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not disable it. [VERIFIED: `.planning/config.json`]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No user authentication surface in this batch phase. |
| V3 Session Management | no | No sessions. |
| V4 Access Control | no | No network/API authorization surface. |
| V5 Input Validation (template category) | yes | Exact schemas, enums, ranges, foreign keys, and fail-closed contextual validation. |
| V6 Cryptography (template category) | yes, integrity only | Existing `digest` SHA-256 artifact/row contracts; never custom cryptography. |
| ASVS 5.0 V2 Validation and Business Logic | yes | Validate lifecycle/score combinations, cutoffs, edition joins, probability mass, and reconciliation rules. |
| ASVS 5.0 V5 File Handling | yes | Trusted-root containment, no symlinks/path traversal, expected files only, size bounds. |
| ASVS 5.0 V13 Configuration | yes | Versioned ruleset/release/schema identifiers and fail-closed defaults. |
| ASVS 5.0 V16 Logging and Error Handling | yes | Machine-readable suppression/reconciliation/failure reasons without silent fallback. |

### Known Threat Patterns for the R/File Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal or symlink escape through edition/output IDs | Tampering | Existing trusted-root containment and symlink rejection; strict edition allowlist. |
| Forged CSV/JSON/RDS hashes or identity drift | Tampering | Metadata-only preflight, exact manifest hashes, model/calibrator identity validation before load/use. |
| CSV formula injection in later public exports | Tampering | Escape leading formula metacharacters at the final static-export boundary. |
| Resource exhaustion from full grids/files | Denial of Service | Fixed G=40, batch limits, file-size checks, compressed local artifacts, compact publication. |
| Cross-edition data contamination | Information Disclosure/Tampering | Every derived row has `edition_id`; undeclared cross-edition joins fail. |
| Future-result leakage | Tampering | Exclusive UTC cutoff, contributing evidence IDs/times, adversarial boundary tests. |
| Raw fallback represented as calibrated | Spoofing | Contract-controlled probability view; fitted calibrator required; explicit suppression otherwise. |

## External Data/API Implications

Phase 14 should not add a live API client. It consumes Phase 13 accepted bundles and normalized history. Source-adapter schema work may add optional canonical fields for future UEFA payloads, but absent/unmapped fields must remain unresolved and suppress dependent state/forecasts. Existing audited manual fallback remains the only operational fallback; no paid feed or automated FotMob path is introduced. [VERIFIED: requirements, AGENTS.md, Phase 13 contracts]

## Sources

### Primary (HIGH confidence)

- `14-CONTEXT.md` - locked lifecycle, standings, form, forecast, release, isolation, and lineage decisions.
- `R/competition/source_contracts.R`, `team_identity.R`, `edition_registry.R` - accepted schemas, release pinning, loaders, and registry revisions.
- `R/benchmark/baselines.R`, `R/benchmark/contracts.R` - canonical G=40 distributions and market validation.
- `R/calibration/probability_calibration.R`, `calibration_selection.R` - fitted temperature calibration and promotion vetoes.
- `R/release/release_contract.R`, `release_bundle.R` - trusted release resolution and current retained-incumbent assumptions.
- Phase 12 release `model_contract.json`, manifest, model/calibrator RDS metadata - current raw fallback and artifact identities.
- Phase 13 accepted/registry CSVs and test suites - live schema and publication/hash boundaries.

### Secondary (MEDIUM confidence)

- Official R `dnbinom` documentation: https://stat.ethz.ch/R-manual/R-patched/RHOME/library/stats/help/dnbinom.html
- Official testthat 3.3.2 documentation: https://testthat.r-lib.org/reference/test_file.html
- Official testthat fixture guidance: https://testthat.r-lib.org/articles/test-fixtures.html
- OWASP ASVS 5.0.0 stable source: https://github.com/OWASP/ASVS
- OWASP ASVS 5.0.0 machine-readable requirements: https://github.com/OWASP/ASVS/blob/master/5.0/docs_en/OWASP_Application_Security_Verification_Standard_5.0.0_en.json

### Tertiary (LOW confidence)

- None used as authority.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - installed versions and code imports were inspected directly.
- Architecture: HIGH - derived from locked decisions and current file/release/registry contracts.
- Calibration outcome: LOW until executed - the required gate result is intentionally left open.
- Pitfalls: HIGH - each critical pitfall is visible in current code or artifacts.
- External source field mapping: LOW until a real accepted UEFA payload exposes the fields.

**Research date:** 2026-08-16
**Valid until:** 2026-09-15 for internal architecture; re-check UEFA source mappings whenever live payloads change.

## RESEARCH COMPLETE
