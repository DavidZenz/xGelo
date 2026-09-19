# Architecture Research: UEFA Champions League Forecast Dashboard

**Domain:** Auditable club-football forecasting and static competition dashboards in R/targets
**Researched:** 2026-09-19
**Confidence:** HIGH for integration recommendations; MEDIUM for the final external-source adapter until its licence and production limits are accepted

## Recommended Architecture

Treat Champions League support as a new **club-football domain** that joins the system only at the existing neutral competition-bundle and dashboard boundaries. Reuse hashing, accepted-bundle promotion, simulation replay, rendering, and atomic publication patterns. Do not pass club data through national-team identity, Elo, feature, benchmark, or release contracts.

```text
UNTRUSTED EXTERNAL INPUTS
  permitted match-state API       historical club results       UEFA regulations
             |                              |                         |
             v                              v                         v
  source adapter + raw hash       club-history adapter        reviewed rules artifact
             |                              |                         |
             +--------------+---------------+                         |
                            v                                         |
                 ACCEPTED CLUB DATA BOUNDARY                           |
             source bundle + club identity registry                   |
                            |                                         |
               +------------+------------+                            |
               |                         |                            |
               v                         v                            v
       UCL state builder          club model pipeline          UCL ruleset engine
       fixtures/results/table     time-safe backtests          ranking/bracket logic
               |                         |                            |
               |                  approved club release               |
               +-------------------------+----------------------------+
                                         v
                              UCL forecast/outcome bundle
                              lineage + seed + replay hash
                                         |
                                         v
                          NEUTRAL DASHBOARD PAYLOAD BOUNDARY
                        registry-driven adapter + shared renderer
                                         |
                                         v
                       N-EDITION ATOMIC PUBLICATION TRANSACTION
                 stage every registered route -> validate -> promote all
```

The principal rule is: **share contracts, not domain evidence**. A club release may implement the same statistical family as the national-team release, but it must have its own training panel, feature contract, backtest folds, promotion decision, release root, and selector.

## New vs Modified Components

| Component | New or modified | Responsibility | Compatibility rule |
|---|---|---|---|
| `club_identity` registry | New | Stable club IDs, source-scoped IDs, current display names, aliases, country/association, validity windows, mergers/renames | Never require `fifa_code`; never insert clubs into the national-team registry |
| Club historical-results contract | New | Accepted match history for rating/model training with source, licence, retrieval, raw/content hashes, and event cutoff | Separate storage and schema version from `elo_matches.csv` |
| UCL current-state source adapter | New | Convert the accepted machine-readable provider response into canonical fixtures, results, teams, stages, and source standings | Adapter has no standings, forecasting, or rules logic; API secrets stay outside artifacts |
| UCL competition-edition registry row | Modified generic registry | Register edition, lifecycle, route, source bundle, ruleset, club release, and output target | Existing Nations League and EURO rows remain byte-compatible projections |
| Club model benchmark and release pipeline | New | Fit and evaluate club ratings/goal models and promote one approved club release | Reject national release IDs and national panels at the club consumer boundary |
| UCL state builder | New competition adapter | Join accepted source rows to club identities and expose neutral state tables | May consume official source standings for audit, but computed standings must be independently reproducible |
| UCL ruleset and simulator | New | League-phase ranking, qualification zones, knockout draw/path resolution, and deterministic outcomes | Rules are edition-versioned data/code; unresolved source or rules state suppresses probabilities |
| Neutral payload validator | Modified | Validate any registered edition rather than membership in `phase17_editions()` | Preserve the existing eight ordered sections unless a versioned payload migration is deliberate |
| Production provider | Modified | Dispatch loaders/validators by registry-declared adapter and model domain | Remove hard-coded NL/EURO variables and callbacks; no competition-name heuristics such as `grepl("euro", ...)` |
| Route/inventory generator | Modified | Derive four route files per publishable registry row plus batch pointers/manifests | Keep current route slugs unchanged; reject duplicate or unsafe slugs |
| Batch validator/promoter | Modified | Validate and atomically promote an exact registry-derived N-edition inventory | All registered editions share one batch ID; one failure preserves the entire incumbent batch |
| targets orchestration | Modified | Branch per validated edition, then aggregate validated manifests into one publish candidate | Branch values come from a sorted, hashed registry projection |

## Component Boundaries

### 1. Source acceptance boundary

Provider JSON/CSV is untrusted input. The acquisition layer may authenticate, rate-limit, retry, and store raw bytes, but it must not directly feed the dashboard. Acceptance validates schema, edition scope, timestamps, enumerated statuses, cardinality, source IDs, hashes, and licence metadata. The accepted bundle is immutable and edition-scoped.

Recommended accepted UCL bundle:

```text
data/competition/accepted/uefa_champions_league_<edition>/
├── source_bundle_manifest.csv
├── teams.csv
├── fixtures.csv
├── results.csv
├── standings.csv
├── status.csv
└── source_artifacts.csv
```

The provider API key is runtime configuration only. It must never appear in raw caches, manifests, logs, dashboard credits, errors, or Git output. If credentials, quota, or source freshness fail, acquisition fails closed and publication keeps the last accepted batch.

### 2. Identity boundary

The existing `team_identity.csv` assumes national-team fields including `fifa_code` and a single UEFA source ID. Clubs need a different identity model:

```text
club_id
canonical_name
association_code
valid_from / valid_to
source_system / source_club_id
display_name
alias
mapping_method / review_state
source_bundle_id
row_sha256
```

Use the tuple `(source_system, source_club_id)` as the preferred lookup key. Name fallback must be deterministic, edition-aware, and review-gated. A collision or unresolved mapping blocks the affected accepted bundle; it must not generate a new club silently. Club and national identifiers should be syntactically distinguishable or explicitly typed with `entity_kind` so a join cannot cross domains accidentally.

### 3. Model authority boundary

The Phase 10/12 protocol is explicitly international: its folds are World Cups/EUROs, its panel is `open_core`, and its history is `elo_matches.csv`. It is reusable as a **design pattern**, not as evidence or an approved release.

Create a club-specific lineage:

```text
data/benchmark/club/                 # panels, folds, feature contract, candidates
outputs/benchmarks/club/             # immutable scores and audit evidence
outputs/releases/club/<release_id>/  # manifest, model, calibration, consumer contract
outputs/releases/club/approved_release.csv
```

The club resolver must enforce `model_domain == "club"`, the club training-panel hash, a club evaluation protocol, and a trusted club release root. Edition registry rows declare `model_domain` and selector identity. A UCL forecast preflight must error if the resolved contract says national/international, even if its columns are otherwise compatible.

Use strictly prior match evidence at every prediction cutoff. Current xG, injury, and lineup inputs remain typed as unavailable until a compliant accepted source and coverage audit exist; they are not zero-valued active features.

### 4. Rules and simulation boundary

Keep source parsing separate from rules. The UCL rules module consumes canonical state plus a versioned, reviewed rules artifact and emits standings and tournament paths. It should own:

- 36-team league-phase scoring and ordered tie-break application;
- rank zones and qualification/elimination status;
- knockout phase seeding, pairing constraints, bracket transitions, extra time, and penalties;
- lifecycle-dependent behavior when draws or paths are not yet known;
- deterministic Monte Carlo with recorded seed, simulation count, ruleset hash, model release hash, and source bundle hash.

Official source rankings are evidence for cross-checks, not the only implementation of the rules. A mismatch between computed and accepted official rank blocks promotion. A tie-break that depends on missing evidence returns `unresolved` and suppresses downstream probabilities rather than falling back to alphabetical or random order.

### 5. Neutral dashboard boundary

The existing payload is a useful interface: metadata, eight ordered sections, and credits. Generalize edition validation from a hard-coded vector to a validated registry row passed into the adapter. The shared renderer continues to know nothing about UCL tie-breakers or qualification rules.

Add optional neutral row fields, not UCL-only top-level sections, for `stage`, `rank_zone`, `qualification_status`, and `path_label`. If the payload shape must change, introduce a new schema version and regenerate all editions in the same transaction; do not allow mixed payload schema versions in one batch.

### 6. N-edition publication boundary

Replace exact constants derived from two editions with one canonical publish registry projection:

```r
publish_rows <- registry[
  registry$publish_enabled & !registry$blocked,
  c("edition_id", "route_slug", "adapter_id", "model_domain", "output_bundle_target")
]
publish_rows <- publish_rows[order(publish_rows$edition_id), ]
```

From that projection derive editions, routes, expected files, manifest route order, byte limits, and Git allowlist. Validate unique edition IDs and route slugs, safe relative paths, exact per-route four-file inventory, one payload per row, one batch ID, route/payload hashes, and no extra files. Aggregate only after all edition branches finish. Promotion remains one filesystem rename with incumbent backup and promoted read-back validation.

Do not weaken atomicity to “publish successful competitions.” A mixed batch would expose different source/model timestamps and make the root pointer dishonest. A blocked UCL refresh means the existing two dashboards also retain their prior batch until a complete candidate is valid.

## Recommended Project Structure

```text
R/
├── club/
│   ├── identity.R                 # club-only resolution and registry validation
│   ├── history_contract.R         # accepted historical result contract
│   ├── ratings.R                  # club strength history
│   ├── benchmark_protocol.R       # rolling club evaluation and promotion gates
│   └── release_contract.R         # club selector and consumer preflight
├── competition/
│   ├── registry_v2.R              # domain, adapter, route, source and release slots
│   ├── ucl_source_adapter.R       # provider rows -> canonical accepted rows
│   ├── ucl_state.R                # neutral state bundle
│   ├── ucl_rules.R                # edition rules and ranking
│   └── ucl_outcomes.R             # simulation and replayable output bundle
├── dashboard/
│   ├── payload_contract_v2.R      # registry-aware neutral payload
│   ├── provider_registry.R        # adapter dispatch, no edition branching
│   ├── publication_v2.R           # N-edition envelope and promotion
│   └── renderer.R                 # retained shared renderer
data/
├── club/                          # raw/accepted historical club inputs
├── benchmark/club/                # versioned model protocol artifacts
└── competition/accepted/<ucl-id>/ # accepted UCL current-state bundle
outputs/
├── releases/club/                 # independent club release authority
└── competition/<ucl-id>/          # state, forecasts, outcomes
```

Keep Phase 17 functions as compatibility shims or frozen legacy tests. New production code should use domain-neutral names rather than extending `phase17_*` conditionals indefinitely.

## Data Flow

1. **Acquire:** fetch provider data into a unique candidate directory; record retrieval time and raw-byte hash.
2. **Accept:** validate source and licence contracts, resolve club identities, canonicalize statuses/times, and promote an immutable accepted source bundle.
3. **Train/release independently:** update club history, execute leakage-safe rolling club backtests, calibrate, and promote only a club-domain release that passes frozen gates.
4. **Build state:** combine accepted UCL fixtures/results with the edition ruleset to produce canonical state and standings, preserving official-source values for comparison.
5. **Forecast:** resolve the approved club release; generate fixture probabilities and score distributions using only evidence before each kickoff.
6. **Simulate:** condition completed fixtures, replay open fixtures from the club release, apply UCL rules, and produce deterministic outcome tables.
7. **Adapt/render:** convert the accepted UCL bundle to the neutral dashboard payload and render its registry-declared route.
8. **Aggregate/promote:** collect all registered edition route manifests, validate one exact N-edition envelope, atomically replace the public root, then read it back and verify hashes.

## Compatibility and Migration Strategy

1. Add club schemas, club release resolution, and UCL adapters without modifying existing national artifacts.
2. Introduce a registry v2 projection that can derive the current two rows exactly. Keep existing route slugs and public URLs.
3. Build the generic publisher and prove it produces a valid two-edition candidate before registering UCL. Use golden manifest/payload fixtures to detect unintended drift.
4. Register UCL with `publish_enabled = FALSE`; exercise source, state, model, rules, simulation, and route checks in staging.
5. Enable the third edition only when its accepted source, approved club release, ruleset, outcomes, and route all pass. The first three-edition promotion is one atomic transaction.
6. Retain legacy `phase17_*` entrypoints until scheduled jobs, tests, and rollback tooling use the generic publisher. Remove them only in a later compatibility cleanup.

## Test Seams

| Boundary | Required tests |
|---|---|
| Source adapter | Raw-response fixtures; schema/status drift; pagination completeness; duplicate/missing match IDs; stale retrieval; secrets absent from artifacts |
| Club identity | Direct source-ID resolution; rename validity windows; ambiguous aliases; cross-provider mappings; explicit rejection of national IDs/FIFA-code assumptions |
| Club model | Rolling date cutoffs; fold replay; cold-start clubs; probability normalization; calibration; national release rejection; byte-stable release verification |
| UCL state/rules | Synthetic 36-team schedules; every tie-break level; rank-zone boundaries; incomplete-evidence unresolved states; official-rank reconciliation |
| Simulation | Fixed-seed byte replay; completed-match conditioning; extra-time/penalty resolution; draw/path lifecycle states; probabilities sum to one |
| Payload adapter | Existing eight-section contract; unavailable enrichment states; correct club release/source/rules lineage; no rules logic in renderer |
| N-edition publisher | Registry sizes 1/2/3; duplicate routes; unsafe paths; missing/extra files; mixed batch IDs/schema; one-edition gate failure; rollback and read-back corruption |
| Regression | Existing Nations League and EURO routes remain valid; their payload semantics and route URLs do not change during the two-to-N migration |

## Dependency-Aware Build Order

### Phase 1 — Club and UCL data contracts

Create the club identity namespace, source/licence contract, accepted UCL current-state bundle, registry v2 projection, and source replay tests. Nothing downstream is trustworthy until club identities and permitted machine access are resolved.

### Phase 2 — Independent club forecast authority

Build club history, ratings/features, rolling evaluation, calibration, promotion gates, and the club release selector. The result is an approved, consumer-validated club release with no UCL tournament simulation yet.

### Phase 3 — UCL rules, state, and outcomes

Implement league-phase rankings and qualification zones first, then knockout topology and seeded deterministic simulation. Produce a validated UCL state/forecast/outcomes bundle whose lineage binds the accepted source, club release, and ruleset.

### Phase 4 — N-edition dashboards and operations

Generalize provider dispatch, payload validation, route inventory, batch manifests, targets branching, and promotion. First prove two-edition compatibility, then add the staged UCL route and enable the three-edition atomic batch. Extend freshness, replay, browser, regression, byte-limit, Git, and rollback gates to iterate over the registry.

**Ordering rationale:** data identity precedes model evidence; model authority and rules both precede outcome probabilities; a complete UCL bundle precedes public registration. The generic publisher can be developed in parallel with Phase 3 after registry v2 exists, but UCL must not become publishable until both tracks pass integration gates.

## Anti-Patterns to Avoid

### Reusing the national-team release because the feature columns match

It silently treats World Cup/EURO validation as club evidence. Enforce a model-domain discriminator and independent selector/root.

### Expanding `phase17_editions()` and adding another `if (edition_id == ...)`

This leaves two-edition assumptions in inventory counts, manifests, callbacks, source registries, and rollback tests. Drive every publication concern from one validated registry projection.

### Making the renderer understand Champions League rules

This duplicates ranking logic in JavaScript and makes audit/replay impossible. Rules produce typed rows; the renderer displays them.

### Using display names as permanent club identity

Club renames, punctuation, sponsors, and same-name collisions will corrupt history. Prefer source-scoped stable IDs with reviewed validity-window aliases.

### Publishing the two successful routes when UCL fails

This breaks the single-batch truth boundary. Keep the incumbent public root and record a blocked candidate outside the public inventory.

### Treating unavailable xG, injuries, or lineups as zero

Zero is evidence, not missingness. Preserve source presence, value presence, imputation, and active-in-fit as distinct states and show the gap in the payload.

## Scaling Considerations

Static traffic is not the hard problem; refresh correctness and simulation cost are. Three editions fit comfortably in the existing monolithic R/targets architecture. Branch per edition and optionally per simulation partition, then reduce deterministically. Optimize payload size and avoid publishing full score-distribution grids before introducing services or databases. A server-backed architecture is unwarranted unless live scoring or user-specific queries become requirements.

## Sources

- Existing project contracts: `R/dashboard/payload_contract.R`, `R/dashboard/production_provider.R`, `R/dashboard/publication.R`, `R/competition/edition_registry.R`, `R/competition/team_identity.R`, `R/release/release_contract.R`, and `R/benchmark/challenger_protocol.R` (HIGH confidence, inspected 2026-09-19).
- Existing milestone structure: `.planning/ROADMAP.md` Phases 13–17 (HIGH confidence, inspected 2026-09-19). The requested `.planning/milestones/v3.0-ROADMAP.md` path did not exist; the active roadmap contained the completed v3.0 content.
- [targets user manual: Dynamic branching](https://books.ropensci.org/targets/dynamic.html) (MEDIUM confidence via official documentation search, inspected 2026-09-19).
- [CRAN targets reference: `tar_pattern()`](https://search.r-project.org/CRAN/refmans/targets/html/tar_pattern.html) (MEDIUM confidence via official CRAN documentation search, inspected 2026-09-19).

---
*Architecture research for: xGelo v4.0 UEFA Champions League Forecast Dashboard*
*Researched: 2026-09-19*
