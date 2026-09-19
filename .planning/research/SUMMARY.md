# Project Research Summary

**Project:** xGelo v4.0 UEFA Champions League Forecast Dashboard
**Domain:** Open-data club-football forecasting and static competition dashboards
**Researched:** 2026-09-19
**Confidence:** MEDIUM

## Executive Summary

The Champions League dashboard is realistic, but it is not a small content adapter. It introduces a new club-football data and model domain, a 36-team incomplete-round-robin ranking engine, rank-constrained knockout paths, and a third edition in a publisher that currently assumes exactly two. The reliable implementation pattern is to preserve xGelo's R, `targets`, static renderer, immutable lineage, and atomic publication machinery while building club identity, historical results, model validation, and UEFA rules as separate authorities. National-team releases may provide patterns, but they must never authorize club forecasts.

The recommended source stack is deliberately narrow: football-data.org v4 for delayed current fixtures/results after a key-backed acceptance and terms review; pinned OpenFootball CC0 histories for club-rating and goal-model development after coverage audits; and manually reviewed, hashed UEFA regulations for competition rules. Current xG, injuries, lineups, cards, and advanced match statistics have no accepted free production source and must remain typed as unavailable. The product should promise periodic, auditable refreshes—not live scoring.

The largest risks are false authority rather than raw implementation difficulty: assuming a free API is open data, reusing the national-team model, leaking future information into club backtests, silently skipping late UEFA tie-break criteria, generating illegal knockout paths, or weakening the existing atomic publisher. Mitigate them with an early source-acceptance gate, independent club-domain release promotion, point-in-time tests, edition-versioned rules that can return `unresolved`, and a registry-driven N-edition transaction proven against the two incumbent dashboards before UCL is enabled.

## Key Findings

### Recommended Stack

Keep the existing monolithic R/`targets` application and static publication architecture. Add provider-specific adapters behind accepted-bundle contracts, pure-R competition rules, and a separately promoted club model. Do not add a database, web server, frontend framework, scraping wrapper, or generic tournament package; none addresses the actual correctness risks.

**Core technologies:**

- **R 4.6.1 runtime:** ingestion, modelling, rules, simulation, and payload generation — preserves the tested implementation and release surface.
- **`targets` 1.12.0:** incremental club pipelines and registry-driven per-edition branching — already proven in xGelo and sufficient for three editions.
- **`httr2` 1.3.0 target:** authenticated, rate-limited, cached API acquisition — supports redacted headers, retry, throttling, and cache behavior; upgrading also requires `rlang >= 1.3.0` and full regression tests.
- **`jsonlite` 2.0.0 and `digest` 0.6.39:** exact adapter decoding plus SHA-256 lineage — match the existing accepted-source and publication contracts.
- **`glmnet` 5.0, `Matrix`, and `MASS`:** sparse regularized Poisson candidate and negative-binomial benchmark — appropriate for unequal club histories, but promotion must depend on club-specific temporal evidence.
- **Existing static HTML/CSS/JS renderer and atomic promoter:** third-edition delivery — generalize their registry and inventory inputs instead of creating another frontend or deployment path.

**Source roles:**

- **football-data.org v4:** delayed current UCL match state, only after a live-key coverage, schema, terms, attribution, retention, and freshness spike passes.
- **OpenFootball CC0:** pinned historical domestic and European results, only after completeness, duplication, identity, and score-semantics audits.
- **UEFA regulations:** manual, versioned rules authority; UEFA pages must not be scraped or systematically collected.
- **StatsBomb Open Data:** optional historical research only; its selective UCL event coverage cannot support current-season xG.

See [STACK.md](./STACK.md) for versions, compatibility constraints, and source details.

### Expected Features

The MVP must combine factual current state, club-specific match forecasts, competition simulation, and truthful provenance. A results-only dashboard can exist during development, but public probability claims are blocked until an independent club release passes its promotion gates.

**Must have (table stakes):**

- Edition/stage header with last successful refresh, delayed-source status, model release, and last-known-good behavior.
- One 36-team league-phase table with accessible top-8, ranks 9-24, and ranks 25-36 qualification bands.
- Edition-versioned interim and final tie-break behavior, including explicit unresolved outcomes when disciplinary or coefficient evidence is missing.
- Complete club schedules, fixtures, results, statuses, and filters for the accepted eight-opponent schedule.
- Pre-kickoff home/draw/away and expected-goals forecasts from a promoted club-domain release, with immutable audit history.
- Rank distributions and mutually exclusive top-8/play-off/eliminated probabilities conditioned on accepted completed results.
- Legal knockout play-off and round-of-16 path states, two-leg resolution, extra time/penalties, neutral final handling, and monotone tournament progression probabilities.
- Freshness, source, rules, model, seed, and unavailable-data lineage in a responsive static page published atomically with existing editions.

**Should have (competitive):**

- Qualification pressure and probabilistic top-8/top-24 cut lines.
- Remaining schedule-strength explanations derived from frozen model inputs.
- Rank-to-path probability maps that collapse only when an accepted draw resolves uncertainty.
- Forecast change ledger and explicit separation of model uncertainty, draw uncertainty, source staleness, and missing enrichment.

**Defer (v4.x or later):**

- Reproducible what-if result scenarios until deterministic baseline simulations and browser performance are stable.
- Optional advanced-data adapters until lawful sources and incremental predictive value are proven.
- Qualifying-round coverage until the league-phase product and its distinct rules/data paths are stable.
- Player availability modelling, near-live publication, and additional UEFA club competitions until sources, operations, and competition-specific rules justify them.

**Exclude:** real-time event tracking, automated UEFA scraping, browser-side authenticated API calls, unsupported current xG/lineup/injury claims, betting advice, and deterministic single-table predictions.

See [FEATURES.md](./FEATURES.md) for feature contracts and dependency details.

### Architecture Approach

The core architecture rule is **share contracts, not domain evidence**. External club data crosses an accepted source and identity boundary; historical results feed a club-only benchmark/release pipeline; current UCL state and a versioned rules artifact feed a separate state/rules engine; only their validated outputs join in a replayable forecast/outcome bundle. That bundle crosses the existing neutral dashboard payload boundary and is promoted inside one registry-derived N-edition transaction.

**Major components:**

1. **Club identity and historical-result contracts** — stable club IDs, source-scoped aliases, validity windows, canonical score/status semantics, licensing, hashes, and point-in-time availability.
2. **UCL current-state adapter and acceptance boundary** — authenticated acquisition, raw hashing, schema/cardinality/freshness validation, immutable edition-scoped fixtures/results/team bundles, and secret isolation.
3. **Club model benchmark and release authority** — club ratings/features, rolling temporal folds, calibration, promotion gates, immutable releases, and hard rejection of national-team selectors.
4. **UCL state, rules, and simulator** — 36-team rankings, qualification zones, legal draw/bracket paths, two-leg and penalty resolution, unresolved-rule states, deterministic seeds, and lineage-bound outcome tables.
5. **Neutral payload/provider registry** — edition-declared adapter dispatch and optional neutral fields without embedding Champions League rules in the renderer.
6. **N-edition publication and operations** — registry-derived routes/inventory, per-edition `targets` branches, one batch identity, exact read-back validation, rollback, scheduling, and last-known-good preservation.

Migration should first prove that registry v2 and the generalized publisher reproduce the existing two-edition outputs and URLs. Register UCL disabled, validate its full bundle in staging, then enable the first three-edition promotion as one atomic transaction. See [ARCHITECTURE.md](./ARCHITECTURE.md) for component boundaries and test seams.

### Critical Pitfalls

1. **Using an authoritative but impermissible source** — automate only a reviewed machine-readable provider; use UEFA pages solely for manually reviewed rules artifacts with recorded terms and hashes.
2. **Treating a free API as open or live data** — keep tokens outside artifacts, stay below rate limits, render attribution and delayed-state semantics, verify retention/display rights, and maintain a provider-exit path.
3. **Reusing national-team forecast authority for clubs** — enforce separate club identities, histories, folds, model domain, release root, selector, calibration, and promotion evidence.
4. **Leaking future or simultaneous-match information** — give every feature an `information_cutoff_utc`; freeze all same-kickoff Matchday 8 inputs before incorporating any of those results.
5. **Publishing false certainty from incomplete UEFA rules inputs** — implement every tie-break in order, measure unsupported disciplinary-resolution mass, and return ambiguous/unresolved outcomes instead of skipping criteria.
6. **Generating illegal knockout paths or score semantics** — model draw slots and bracket paths as versioned data; separate regulation, extra time, aggregate, and shootout values; never revive away goals.
7. **Hard-coding a third publisher branch or promoting partial state** — derive all inventories from the registry, stage the complete batch, validate/read back every route, and keep incumbent bytes unchanged on any failure.

See [PITFALLS.md](./PITFALLS.md) for warning signs, recovery procedures, and the complete pitfall-to-phase mapping.

## Implications for Roadmap

Based on the combined research, the roadmap should use five phases. This separates the first irreversible decision—the production source contract—from modelling, rules, publication migration, and scheduled operations.

### Phase 1: Club and UCL Source Contracts

**Rationale:** Every downstream result depends on lawful, complete, correctly normalized club data. The current-source API and historical corpus are still unproven in the live 2026/27 context.

**Delivers:**

- Key-backed football-data.org source spike and documented accept/reject decision.
- Source terms, attribution, retention, refresh-delay, request-budget, secret-handling, and provider-exit contracts.
- Club identity registry with source-ID-first resolution, validity windows, reviewed aliases, and cross-domain rejection.
- Canonical historical/current club-match schema with separate regulation, extra-time, aggregate, shootout, and status fields.
- Pinned OpenFootball adapters, coverage/duplicate/overlap audits, accepted UCL source bundles, captured redacted fixtures, and registry v2 scaffolding with UCL disabled.

**Addresses:** permitted current state, fixtures/results, freshness/provenance, and historical depth prerequisites.

**Avoids:** prohibited UEFA scraping, token leakage, free-tier/live misrepresentation, cross-league incomparability, duplicate matches, club-name joins, and score/status contamination.

**Exit gate:** Do not begin production UCL automation unless the provider contract and current-edition completeness evidence pass. A failed gate permits only a reviewed manual-snapshot or explicit unavailable mode.

### Phase 2: Independent Club Forecast Authority

**Rationale:** UCL match and tournament probabilities cannot be authorized by the national-team release. Historical club data must first demonstrate point-in-time completeness and adequate cross-league signal.

**Delivers:**

- Internally computed club Elo and club-only feature history.
- Negative-binomial baseline and regularized Poisson candidate, with documented cold-start and cross-league behavior.
- Frozen rolling-origin club/UCL evaluation folds, information-cutoff audits, proper scores, calibration, uncertainty, and promotion thresholds.
- Immutable club model bundle, model card, consumer contract, approved selector, and national-release rejection tests.
- Current xG, injury, lineup, and player data explicitly marked unavailable rather than imputed.

**Addresses:** current match forecasts and the forecast authority required by all advancement simulations.

**Avoids:** model-domain transfer, temporal and simultaneous-kickoff leakage, overconfident cold starts, unsupported enrichment, and tuning tournament claims to one new-format season.

### Phase 3: UCL Rules, State, and Tournament Outcomes

**Rationale:** The new league phase and fixed knockout topology are competition logic, not renderer behavior. They require a validated state engine before public qualification or champion probabilities are credible.

**Delivers:**

- Hashed 2026/27 rules artifact and accepted manual overlays for club coefficients and available disciplinary evidence.
- Separate interim and completed league-phase ranking engines with decisive-criterion output and adversarial tests for every tie-break.
- Top-8/play-off/eliminated bands, rank distributions, cut-line distributions, and unresolved-mass accounting.
- Data-driven knockout slots, pre-draw/observed-draw lifecycle, fixed bracket propagation, leg-order rules, two-leg/extra-time/penalty handling, and neutral final.
- Fixed-seed league/tournament simulations binding source, rules, and club-release hashes, with replay and probability reconciliation tests.

**Addresses:** exact standings behavior, league-phase outcomes, legal knockout paths, and tournament progression probabilities.

**Avoids:** generic points sorts, silently skipped disciplinary criteria, invented fixtures/opponents, independent random knockout draws, away-goals errors, and inflated new-format validation claims.

### Phase 4: N-Edition Dashboard and Atomic Publication

**Rationale:** UCL should enter production only after the publisher no longer depends on exact two-edition lists. This migration must prove incumbent compatibility before adding the third route.

**Delivers:**

- Registry-driven provider dispatch, edition validation, routes, expected artifacts, credits, lifecycle states, and output limits.
- Generalized neutral payload validation with UCL stage/rank-zone/path fields and typed unavailable states.
- Dynamic `targets` branching and exact 0/1/N-edition publication tests.
- Byte-compatible Nations League/EURO routes, golden two-edition candidate tests, then staged and enabled UCL routes.
- Single-batch staging, manifest validation, atomic promotion, promoted read-back, and incumbent byte-preservation after any candidate failure.

**Addresses:** responsive public UCL dashboard, shared navigation, provenance, and safe third-edition delivery.

**Avoids:** `if (ucl)` sprawl, rules in JavaScript, mixed schema/batch IDs, duplicate/unsafe routes, and partial multi-edition publication.

### Phase 5: Automated Refresh and Release Hardening

**Rationale:** A manually successful dashboard is not yet a reliable public product. The delayed keyed service and multi-source bundle require failure-injection evidence under scheduled execution.

**Delivers:**

- Rate-aware bounded refresh scheduling, request caching, retry/backoff, non-overlapping runs, secret scans, and provider quota/subscription checks.
- One retrieval-window candidate, lifecycle-specific freshness limits, coherent forecast cutoffs, and failed-refresh diagnostics outside the public bundle.
- End-to-end failure tests for 429/5xx/null/empty/stale/postponed/no-network/concurrent-run conditions.
- Simulation performance profiling, deterministic RNG across batching/worker changes, compact aggregate outputs, browser smoke/accessibility checks, and release acceptance evidence.
- Recovery runbooks for source exit, credential exposure, model demotion, rules correction, identity collision, and publication rollback.

**Addresses:** automatic periodic refresh, last-known-good operation, observable source health, and sustainable release operations.

**Avoids:** stale-success UI, partial endpoint updates, overlapping schedulers, recomputing models on score refresh, row-wise simulation bottlenecks, and silent fallback success.

### Phase Ordering Rationale

- Source legality, identity, score semantics, and completeness come before any modelling or public-state claims.
- The independent club model and UCL rules engine can be developed as separate streams after Phase 1, but both must pass before tournament outcomes are publishable.
- The N-edition publisher may begin after registry v2 exists, yet UCL remains disabled until a complete state/model/rules/outcome bundle passes staging.
- Operations hardening comes after the full transaction exists so failure injection exercises the real release boundary rather than provisional scripts.
- Each phase has a fail-closed deliverable: rejected source, unpromoted model, unresolved rank, disabled UCL registry row, or retained last-known-good batch.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 1:** mandatory live-key API spike and explicit source-terms/retention review; documentation alone cannot prove 2026/27 completeness or intended public-use rights.
- **Phase 2:** historical coverage, cross-league comparability, cold-start uncertainty, and promotion thresholds require empirical exploration before plans are frozen.
- **Phase 3:** edition-specific draw notices, disciplinary tie-break policy, and scarce new-format validation evidence warrant rules-focused research.

Phases with established project patterns (skip broad research-phase):

- **Phase 4:** the repository already provides payload, renderer, route, manifest, lock, rollback, and read-back patterns; use codebase pattern mapping and migration tests instead.
- **Phase 5:** `targets`, `launchd`, atomic promotion, last-known-good, and failure-injection patterns already exist; perform targeted provider checks rather than broad ecosystem research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Existing R/static components are proven, and package behavior comes from official docs; live API fields, rights, and 2026/27 completeness remain unverified without a key. |
| Features | MEDIUM | UEFA rules and competitor baselines establish user expectations, but the best launch treatment for unsupported disciplinary resolution requires product validation. |
| Architecture | HIGH for internal integration; MEDIUM overall | Recommendations are grounded in inspected xGelo contracts and standard `targets` branching; final source adapter and accepted data shape remain conditional. |
| Pitfalls | MEDIUM | Risks are strongly corroborated across rules, provider policies, and the codebase, but legal conclusions and rare tie-break frequencies need owner review and live evidence. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Production API acceptance:** run a real-key 2026/27 coverage/schema spike and preserve evidence before treating football-data.org as an authority.
- **Terms and retention:** obtain owner/legal confirmation for normalized public display, attribution, retention after subscription changes, and provider exit; this research is not legal advice.
- **Late tie-break evidence:** confirm a permitted disciplinary source or adopt a tested ambiguity/unresolved policy with a release tolerance; version club coefficient inputs and as-of dates.
- **Historical club corpus quality:** measure season/league coverage, duplicates, club identity changes, regulation-versus-shootout semantics, and cross-league connectivity before fitting.
- **Club promotion thresholds:** freeze baselines, proper-score/calibration gates, cold-start behavior, and UCL assessment windows only after exploratory evidence is recorded.
- **New-format validation:** separate match-model validation, rules correctness, and end-to-end format evidence; only a few 36-team seasons exist.
- **Edition-specific draw adaptations:** include official draw-procedure notices in the rules bundle because the base regulations permit operational adjustments.
- **Dependency upgrade:** verify `httr2` 1.3.0 plus `rlang >= 1.3.0` against the full existing pipeline, including changed cache filename behavior.

## Sources

### Primary (HIGH confidence)

- Existing xGelo contracts: `R/dashboard/payload_contract.R`, `R/dashboard/production_provider.R`, `R/dashboard/publication.R`, `R/competition/edition_registry.R`, `R/competition/team_identity.R`, `R/release/release_contract.R`, and `R/benchmark/challenger_protocol.R` — current two-edition, identity, model, and release boundaries.
- Existing v3.0 roadmap and completed phase artifacts — proven source-contract, simulation, dashboard, refresh, and rollback patterns.

### Official / Secondary (MEDIUM confidence)

- [UEFA Champions League 2026/27 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27-Online) — format, ranking, draw, and match-system authority.
- [UEFA league-phase standings criteria](https://www.uefa.com/uefachampionsleague/news/0291-1bd88ae04870-e1e038c319e3-1000--champions-league-league-phase-standings-how-teams-level-on-/) — interim and completed-league tie-break behavior.
- [UEFA knockout draw procedure](https://www.uefa.com/uefachampionsleague/news/02a2-1ffe3d954170-60c0b7443c85-1000--uefa-champions-league-round-of-16-quarter-final-and-semi/) — rank-paired slots, bracket paths, and leg ordering.
- [UEFA platform terms](https://www.uefa.com/termsconditions/) — automated scraping and systematic collection constraints.
- [football-data.org pricing](https://www.football-data.org/pricing), [coverage](https://www.football-data.org/coverage), [v4 policies](https://docs.football-data.org/general/v4/policies.html), and [API reference](https://www.football-data.org/documentation/api) — free-tier UCL coverage, delayed scores, request limits, null semantics, and resource shapes.
- [OpenFootball](https://github.com/openfootball) and its [Champions League repository](https://github.com/openfootball/champions-league) — CC0 historical data coverage and update model.
- [StatsBomb Open Data](https://github.com/hudl/open-data) — selective historical event-data coverage and attribution conditions.
- Official package documentation for [`targets`](https://books.ropensci.org/targets/dynamic.html), [`httr2`](https://httr2.r-lib.org/), [`jsonlite`](https://cran.r-project.org/package=jsonlite), [`digest`](https://cran.r-project.org/package=digest), and [`glmnet`](https://cran.r-project.org/package=glmnet) — branching, acquisition, serialization, hashing, and modelling behavior.

### Tertiary (LOW confidence)

- [Opta Analyst Champions League competition coverage](https://theanalyst.com/competition/uefa-champions-league) — competitor feature comparison only; not used for implementation facts.
- Academic cross-league rating studies cited in [PITFALLS.md](./PITFALLS.md) — modelling context that still requires project-specific empirical validation.

---
*Research completed: 2026-09-19*
*Ready for roadmap: yes*
