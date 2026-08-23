# Phase 16: EURO Qualifying Activation and Play-off Rules - Research

**Researched:** 2026-08-23  
**Domain:** UEFA EURO 2028 qualifying activation, qualification rules, cross-competition play-offs, and fail-closed R artifacts  
**Confidence:** HIGH for the published regulations and existing repository contracts; MEDIUM for future post-draw source availability and UEFA draw-operation details

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Shared dashboard rendering and responsive filtering remain Phase 17.
- Hourly launchd refresh, browser smoke checks, atomic cross-competition promotion, compact auto-commit, and push remain Phase 17.
- Full historical EURO qualifying editions and broader live-event evaluation remain future requirements.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-03 | EURO 2028 qualifying remains pre-draw and activates groups, fixtures, and simulations only after an official draw snapshot exists. | Activation gate, source-bundle requirements, pre-draw schema behavior, and post-draw correction transaction described below. |
| COMP-04 | Competition state applies official tie-breakers, cross-group rankings, host-place rules, play-off topology, and regulation-version checks. | Articles 15, 16, 17, 23, and 24 mapped to a versioned rules adapter and validation gates. |
| SIM-02 | EURO simulation reports direct qualification, host places, Nations League-linked play-off eligibility, and every valid topology. | Conditional host ledger, deduplicated eligibility pipeline, three official topology branches, and seeded simulation integration described below. |
| SIM-04 | Pre-draw, unresolved, and insufficient-source states are explicit and never fabricate groups, fixtures, standings, or probabilities. | State machine, suppression rules, negative cases, and validation map described below. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- [VERIFIED: codebase grep] R is the primary language and the project uses script-oriented R modules, direct `source()` composition, CSV/RDS/JSON contracts, and testthat coverage.
- [VERIFIED: codebase grep] `targets` is the project orchestration choice, but Phase 16 must leave shared dashboard rendering and hourly operations to Phase 17.
- [VERIFIED: codebase grep] The project is open-data-first, must not depend on paid feeds, and must not automate FotMob or other restricted scraping.
- [VERIFIED: codebase grep] The layer-separation rule keeps xG and Elo data combined only in the Integration layer; competition rules consume the shared state and approved model release rather than changing model training.
- [VERIFIED: codebase grep] Durable outputs carry stable IDs, source/release lineage, SHA-256 hashes, cutoff metadata, and machine-readable status/reason fields.
- [VERIFIED: codebase grep] Missing or unresolved inputs remain explicit and derived outputs are suppressed; fabricated EURO groups, fixtures, standings, and probabilities are prohibited.
- [VERIFIED: codebase grep] Tests should be run frequently with `testthat::test_dir("tests/testthat")`; focused Phase 16 tests should be added before broad regression execution.
- [VERIFIED: codebase grep] Planning documents are committed because `.planning/config.json` sets `commit_docs` to `true`.

## Summary

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] The operative 2026–28 regulations confirm that EURO qualifying has 12 groups of four or five, with home-and-away group matches; the 12 group winners and eight highest-ranking runners-up qualify directly, while the other four runners-up enter the play-offs. Two final-tournament places are reserved for host association teams that are not directly qualified, including hosts that entered the play-offs. The regulations, enforced 2026-07-29, are the rules authority for implementation; UEFA's 2025 format announcement is useful confirmation of the high-level format but is no longer sufficient by itself for detailed behavior.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] The hardest implementation fact is that the play-off format is conditional, not one bracket. Both reserved host places used means 8 teams, two four-team paths, and two qualifying places; one used means 12 teams, three four-team paths, and three places; none used means 8 teams in four seeded-versus-unseeded home-and-away ties and four places. The same article defines allocation order, Nations League fallback, draw pots, and host separation constraints. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-17-Match-system-play-offs-Online] Article 17 defines single-leg semi-finals/finals for the two- or three-path branches and two-leg aggregate ties for the four-tie branch.

[VERIFIED: codebase grep] The repository already has the correct foundations: Phase 13 source bundles and publication hashes, Phase 13 candidate-isolation and transaction code, Phase 14 schema-valid EURO `pre_draw` empties, edition-scoped state manifests, and Phase 15 transition outcomes with stable IDs, eligibility fields, ruleset hashes, and unresolved-state fields. Planning should add EURO-specific rules and outcomes beside those seams rather than put rule logic in the renderer or mutate Phase 15's Nations League contracts.

**Primary recommendation:** Implement a versioned `uefa_euro_2026_28` rules adapter plus an edition-scoped EURO qualification ledger/simulator that accepts only a complete post-draw five-resource source bundle, consumes a complete Phase 15 Nations League eligibility handoff by `team_id`, evaluates the host ledger before ranking runners-up, and enumerates the three Article 16 topology branches per simulation outcome; keep all incomplete inputs explicitly unresolved and probability-free.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pre-draw/post-draw lifecycle and bundle acceptance | API / Backend | Database / Storage | [VERIFIED: codebase grep] `edition_registry.R`, `publication_hashes.R`, and `publication_transaction.R` own lifecycle, hashes, candidate validation, and promotion; the static dashboard only consumes the result. |
| Official groups, teams, fixtures, and kickoff validation | Database / Storage | API / Backend | [VERIFIED: codebase grep] The five-resource source bundle and normalized Phase 14 tables are the durable input boundary; rules must not infer missing source rows. |
| EURO group standings and tie-break ordering | API / Backend | Database / Storage | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-15-Equality-of-points-qualifying-group-stage-Online] Article 15 is competition logic applied to completed results, not presentation logic. |
| Overall European Qualifiers rankings and best runners-up | API / Backend | Database / Storage | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online] Cross-group ordering has group-size-specific exclusions and a defined tie-break chain. |
| Host-reserved-place allocation | API / Backend | Database / Storage | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] Host capacity changes direct/play-off allocation and must be recorded as a ledger, not inferred by the renderer. |
| Nations League-linked play-off eligibility | API / Backend | Database / Storage | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] Eligibility is a cross-edition rules join on the accepted Phase 15 ranking/outcome handoff. |
| Qualification simulation and topology enumeration | API / Backend | Database / Storage | [VERIFIED: codebase grep] Phase 15 owns the established seeded simulation pattern; EURO simulation should consume immutable Phase 14 forecast inputs and write replayable outcome artifacts. |
| Dashboard display of statuses and warnings | Browser / Client | API / Backend | [VERIFIED: codebase grep] Phase 17 owns shared rendering; Phase 16 must expose compact payload fields and reason enums but not build the common UI. |

## Confirmed UEFA Rules (as of 2026-08-23)

### Qualifying structure and hosts

- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-13-Group-formation-qualifying-group-stage-Online] All teams, including England, Republic of Ireland, Scotland, and Wales, enter the qualifying draw; they are drawn into 12 groups of four or five. The four host teams and Northern Ireland are drawn into separate groups. The draw is seeded from the interim overall 2026/27 Nations League rankings, and specific Nations League knockout/play-off placeholders affect group-size constraints.
- [CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/] UEFA announced on 2026-07-16 that the qualifying draw will take place in Belfast on Sunday 2026-12-06. The same announcement says the qualifying group stage is expected to begin in March 2027 and end in November 2027, with play-offs planned for March 2028.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] The group system is home-and-away, with three points for a win and one for a draw. Direct qualification is the 12 group winners plus the eight best runners-up by the Article 23 overall ranking. The remaining four runners-up enter the play-offs.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] Two places are reserved for host association teams that are not directly qualified, including hosts that qualified for the play-offs. If more than two hosts need the reserved treatment, the two highest-ranked such hosts by Article 23 are covered. If zero or one host uses a reserved place, the unused place or places move into the play-offs.

### Tie-breakers and cross-group ranking

- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-15-Equality-of-points-qualifying-group-stage-Online] Equal points inside a qualifying group are resolved in this order: points in matches among the tied teams; goal difference in those matches; goals scored in those matches; recursive application to the remaining tied subset; then all-group goal difference, all-group goals, all-group away goals, wins, away wins, disciplinary points, and higher interim overall Nations League ranking.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online] Overall European Qualifiers rankings are created after the group stage. For groups of five, matches against the fifth-placed team are excluded when ranking group winners, runners-up, third-placed teams, and fourth-placed teams; all matches remain included for ranking fifth-placed teams. The cross-group criteria are group position, points, goal difference, goals, away goals, wins, away wins, disciplinary points, and interim Nations League ranking.
- [VERIFIED: codebase grep] The project must therefore retain match-level evidence or enough derived fields to reproduce the Article 15 tied-subset calculation and Article 23 exclusion set. A generic points sort or a single common match count is insufficient for groups of mixed size.

### Play-off eligibility and all valid topologies

| Host reserved places used | Entrants | Structure | Places | Match rule |
|---|---:|---|---:|---|
| 2 | 8 | 2 paths of 4; each path has 2 semi-finals and 1 final | 2 | Single-leg knockout; pot 1 and pot 2 semi-final hosts; winners of pot-1 semi-finals host finals. |
| 1 | 12 | 3 paths of 4; each path has 2 semi-finals and 1 final | 3 | Same single-leg path rules. |
| 0 | 8 | 4 seeded-vs-unseeded ties | 4 | Home-and-away; seeded team hosts the second leg; aggregate goals decide, then Article 22 tie resolution. |

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] The allocation algorithm is: reserve two to four play-off places for the lowest-ranked qualifying-group runners-up; fill the remaining four to nine places from non-qualified, non-play-off-qualified group winners of Nations League Leagues A, B, and C by interim overall Nations League ranking; if that is insufficient, use the highest-ranked eligible League D group winner; then use the highest-ranked remaining teams in the interim overall Nations League ranking that are not already qualified for the final tournament or play-offs.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] For two- or three-path formats, rank runners-up first by Article 23 position and Nations League entrants second by their interim Nations League ranking, divide into four equal pots, and pair pot 1 versus pot 4 plus pot 2 versus pot 3 within each path. For the four-tie format, all runners-up go to seeded pot 1 first, the highest-ranked Nations League entrants fill remaining seeded slots, and the rest go to pot 2.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] The draw separates two host association teams into separate paths or ties. If possible, Northern Ireland is placed in a path or tie without a host association team. UEFA may approve additional draw principles and conditions, so the adapter must represent those as source-controlled constraints rather than silently inventing them.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-17-Match-system-play-offs-Online] A two-leg tie uses aggregate goals and the second leg is hosted by the seeded team. Single-leg matches use extra time and penalties under Article 22 if required. The simulator must model the topology-specific match resolution rather than reuse one generic single-match or two-leg bracket.

### Nations League-linked input

- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] EURO eligibility explicitly references the interim overall 2026/27 Nations League rankings and non-qualified group winners from Leagues A-C, with League D and broader ranking fallback.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] Nations League Article 19 defines the interim overall ranking bands: League A ranks 1-16, B ranks 17-32, C ranks 33-48, and D ranks 49-55 after the league phase. This is the ranking namespace the EURO rules adapter must consume, not a final post-knockout ranking unless UEFA's EURO rules revision says otherwise.
- [VERIFIED: codebase grep] Phase 15 already publishes `transition_outcomes` with `eligibility_status`, `cd_playoff_status`, unresolved/cancellation fields, source bundle identity, model lineage, ruleset version, ruleset hash, and simulation seed. Phase 16 should consume the accepted Phase 15 handoff by stable `team_id`; it should not join on display names or reconstruct Nations League rankings from EURO rows.

## Activation Boundary and State Machine

[VERIFIED: codebase grep] The current accepted EURO state is structurally empty but schema-valid: Phase 13/14 tests assert `lifecycle_state = pre_draw`, `forecast_status = pre_draw`, zero rows for fixtures, results, groups, standings, competition form, and forecast artifacts, and no score distributions. Preserve this behavior until a candidate source bundle passes the complete activation gate.

Recommended states and transitions:

```text
pre_draw
  | official draw date reached AND complete official draw/schedule bundle validates
  v
scheduled / active
  | first accepted completed result
  v
in_progress
  | all qualifying-stage results and official outcomes complete
  v
complete

any accepted state -- candidate refresh fails --> same last accepted state + blocked/revision warning
any accepted state -- new rules/source revision validates --> replacement accepted atomically
incomplete post-draw candidate --> candidate isolated; no public state change
```

[VERIFIED: codebase grep] The lifecycle values `pre_draw`, `scheduled`, `in_progress`, and `complete` already exist in `R/competition/edition_registry.R`; the `blocked` flag is an overlay and must not erase the last accepted output identity. [VERIFIED: codebase grep] `R/competition/publication_transaction.R` already provides candidate isolation, target validation, promotion, and rollback boundaries.

Activation must require all of the following:

1. [VERIFIED: codebase grep] A registered `edition_id`, official status, source bundle ID, ruleset version, and source-bundle manifest with valid content and row hashes.
2. [VERIFIED: codebase grep] Non-empty official groups with stable team identities and no unresolved team mapping.
3. [VERIFIED: codebase grep] A complete fixture/schedule resource covering every official pairing, with unique stable fixture IDs, stable home/away team IDs, and non-missing `kickoff_confirmed` plus `confirmed_kickoff_at_utc` for every pairing. This is the project decision D-02; do not weaken it because UEFA may publish pairings before final kickoff times.
4. [VERIFIED: codebase grep] Edition-consistent source lineage, registry revision, and ruleset/hash metadata.
5. [VERIFIED: codebase grep] Empty standings/results are allowed at initial activation; they must remain exact schema-valid empties and the state builder must not invent zero-score matches or provisional rankings.

Post-draw corrections must be staged as a new source bundle, validated against the full gate, and only then replace the active bundle. During validation, the last accepted bundle remains public and receives the existing visible blocked/revision warning fields.

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|---|---:|---|---|
| R | 4.6.1 | Rules adapters, state construction, deterministic simulation, and artifact writing | [VERIFIED: local environment] The project is R-first and the installed runtime is R 4.6.1. |
| Existing Phase 13/14/15 R modules | repository contracts | Source bundles, identity, state, hashes, transactions, and Nations League handoff | [VERIFIED: codebase grep] These are locked project seams and already have focused test coverage. |
| `digest` | 0.6.39 | SHA-256 rules/source/output hashes | [VERIFIED: local environment] Existing code calls `digest` for source, row, manifest, and ruleset identities. |
| `jsonlite` | 2.0.0 | JSON source manifests or compact status payloads where existing contracts require JSON | [VERIFIED: local environment] Existing project dependencies include JSON contract handling. |

### Supporting

| Component | Version | Purpose | When to Use |
|---|---:|---|---|
| `testthat` | 3.3.2 | Focused Phase 16 unit/contract/integration tests | [VERIFIED: local environment] Use for all new rule, activation, topology, and suppression coverage. |
| `yaml` | 2.3.12 | Existing planning/config or manifest support if an existing module requires it | [VERIFIED: local environment] Do not add it solely for Phase 16. |
| `data.table` | 1.18.2.1 | Existing data manipulation support if current modules already use it | [VERIFIED: local environment] Prefer existing base/data-frame patterns in the competition contracts; do not introduce a new data layer. |

**Installation:** No new external package installation is recommended for this phase. [VERIFIED: local environment] All packages named above are already installed; the package-legitimacy gate is not triggered because the phase should reuse the existing stack.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Existing R rules/state contracts | A new web/API service or frontend rules implementation | [VERIFIED: codebase grep] This would split authority, bypass file-backed hashes, and conflict with the static-dashboard architecture. Do not use. |
| Explicit topology enumeration | One hardcoded playoff bracket | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] The official format has three valid branches, so a single bracket cannot represent the rules. |
| Phase 15 stable-ID handoff | Display-name matching or recomputed Nations League ranks | [VERIFIED: codebase grep] Name matching is not the established identity contract and recomputation risks cross-edition drift. |

## Architecture Patterns

### System Architecture Diagram

```text
Official UEFA regulations + draw announcement + post-draw source bundle
        + accepted Phase 15 Nations League transition outcomes
        + canonical team identity + approved Phase 14 model release
                              |
                              v
                  source adapter / bundle validator
                  (URL, retrieval, raw hash, parser, fallback,
                   official status, groups, fixtures, kickoff gate)
                              |
              +---------------+----------------+
              |                                |
              v                                v
       pre_draw guard                     active EURO state
       zero-row schemas                   standings/results/form
       unavailable forecast               fixture forecasts
              |                                |
              +---------------+----------------+
                              v
                    EURO qualification rules adapter
                    (Article 15 ties -> Article 23 ranks
                     -> direct qualifiers -> host ledger
                     -> runner-up/NL eligibility -> topology)
                              |
                              v
                 seeded deterministic simulator
                 (scenario-specific topology + tie resolution)
                              |
                              v
          compact qualification ledger + outcome artifacts + manifest
                              |
                              v
                    Phase 17 shared dashboard payload
```

### Recommended Project Structure

```text
R/competition/
├── uefa_euro_rules.R          # Article 13-17, 23-24 constants and validators
├── uefa_euro_simulation.R     # seeded qualification/topology simulation
├── uefa_euro_outcomes.R       # durable qualification ledger and manifest
├── source_contracts.R         # existing five-resource schemas and provenance
├── state_bundle.R              # existing edition-scoped state construction
├── publication_hashes.R        # existing structural/hash validation
└── publication_transaction.R   # existing candidate isolation and promotion
tests/testthat/
└── test_phase16_euro_qualifying.R
```

[ASSUMED] The exact three new R filenames and outcome artifact names are discretionary; the planner should preserve the existing `R/competition/` and `tests/testthat/` ownership boundaries even if it selects different names.

### Pattern 1: Fail-closed activation gate

**What:** Treat post-draw activation as a validation result, not as a calendar-based toggle. The official draw date is a display/source fact; activation requires a complete accepted bundle.

**When to use:** Every source refresh and every post-draw correction.

**Example:**

```r
validate_euro_activation <- function(status, groups, fixtures, team_registry) {
  checks <- c(
    official_status = identical(status$competition_status, "scheduled"),
    groups_present = nrow(groups) > 0L,
    teams_resolved = all(groups$team_id %in% team_registry$team_id),
    fixtures_present = nrow(fixtures) > 0L,
    fixture_ids_unique = !anyDuplicated(fixtures$fixture_id),
    kickoff_confirmed = all(fixtures$kickoff_confirmed %in% TRUE),
    kickoff_values_present = all(nzchar(fixtures$confirmed_kickoff_at_utc))
  )
  if (!all(checks)) return(list(status = "unavailable", reason = names(checks)[!checks]))
  list(status = "active", reason = "complete_official_draw_schedule_bundle")
}
```

[VERIFIED: codebase grep] The field names shown are based on the existing Phase 14 source schema and the project decisions; the exact function and enum names remain discretionary. The planner should add negative tests for every failed check and assert the last accepted bundle is unchanged.

### Pattern 2: Ordered qualification ledger

**What:** Make each allocation step an auditable row or stage: direct group winner, best runner-up, host reservation, runner-up play-off, Nations League A-C, League D fallback, broader Nations League fallback, and final topology placement.

**When to use:** Both deterministic state output and each simulation run.

**Example:**

```r
allocate_euro_places <- function(group_rankings, host_ids, nl_eligibility, rules) {
  direct <- select_group_winners_and_best_runners_up(group_rankings, rules)
  hosts <- allocate_reserved_host_slots(direct, host_ids, group_rankings, rules)
  playoff_pool <- allocate_playoff_entrants(
    remaining_runners_up = hosts$remaining_runners_up,
    nl_eligibility = nl_eligibility,
    topology_places = 4L - hosts$reserved_slots_used
  )
  list(direct = direct, hosts = hosts, playoff_pool = playoff_pool)
}
```

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] Direct places and host reservations must be represented separately. [VERIFIED: codebase grep] This follows the repository's existing durable-row and reason-field pattern.

### Pattern 3: Ruleset and source revision lineage

**What:** Hash the canonical rules object and accepted source bundle, carry both through every qualification/output row, and treat any official rule or topology revision as a new candidate.

**When to use:** Every published outcome and every replay.

[VERIFIED: codebase grep] Phase 15 already uses `ruleset_version`, `ruleset_sha256`, `source_bundle_id`, `source_bundle_sha256`, `simulation_seed`, and parent hashes in its outcome schemas. Reuse that shape for EURO; do not put an unversioned rules constant inside a simulator.

### Anti-Patterns to Avoid

- **Calendar-only activation:** [VERIFIED: codebase grep] A date check cannot prove groups, stable teams, fixture IDs, or confirmed kickoffs exist. Use the complete bundle gate.
- **One topology selected at code-load time:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] Topology depends on host reserved-place usage; select it per accepted state or simulation scenario.
- **Host-as-direct-qualifier shortcut:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] A host can qualify directly, enter the play-offs, or use a reserved place; collapsing these cases double-counts capacity.
- **Projecting pre-draw teams or fixtures:** [VERIFIED: codebase grep] Phase 14 intentionally emits zero-row EURO structures before the draw. Keep that contract.
- **Nations League display-name join:** [VERIFIED: codebase grep] Phase 15's contract is keyed by stable `team_id`; names are source display fields only.
- **Generic cross-group ranking:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online] Groups of five require excluding fifth-place matches for ranks 1-4.
- **Publishing a candidate bundle in place:** [VERIFIED: codebase grep] Existing publication transactions preserve the accepted bundle during validation; follow that pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Source provenance and raw-byte identity | Ad hoc URL or timestamp fields | Existing Phase 13 source artifact, manifest, and SHA-256 helpers | [VERIFIED: codebase grep] Existing contracts preserve URL, retrieval time, raw hash, parser/fallback metadata, and accepted bundle identity. |
| Stable team/fixture identity | String normalization inside the rules engine | Phase 13/14 team identity and normalized fixture contracts | [VERIFIED: codebase grep] Rules require canonical IDs and preserve source display names separately. |
| Atomic candidate publication | Direct writes into `data/competition/accepted` | `publication_transaction.R` candidate isolation and promotion | [VERIFIED: codebase grep] This preserves the last accepted bundle during correction failure. |
| Group standings/tied-subset arithmetic | A points-only sort | Existing standings reducer extended with Article 15 tokens | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-15-Equality-of-points-qualifying-group-stage-Online] UEFA requires head-to-head recursion and disciplinary/Nations League fallbacks. |
| Nations League eligibility | Recompute the prior competition from EURO inputs | Accepted Phase 15 transition outcomes and ranking lineage | [VERIFIED: codebase grep] Phase 15 already carries eligibility, cancellation, hashes, and stable IDs. |
| Probability sampling and tie resolution | A second random sampler or unseeded `sample()` calls | Phase 15 seeded simulation helpers and explicit topology-specific resolution | [VERIFIED: codebase grep] Existing code preserves deterministic seeds and restores RNG state. |

**Key insight:** The difficult part is not drawing a bracket; it is preserving authority across two editions while host usage changes the number and shape of play-offs. Reusing the existing source, identity, hash, transaction, and simulation seams prevents the most dangerous failures: duplicated host capacity, stale Nations League eligibility, and public partial bundles.

## Common Pitfalls

### Pitfall 1: Treating the 2025 announcement as the complete rules source

**What goes wrong:** The high-level announcement omits detailed ranking, potting, tie resolution, and fallback clauses.  
**Why it happens:** The announcement says remaining details would be published later. [CITED: https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/]  
**How to avoid:** Pin the 2026–28 regulations and article-level ruleset hash as runtime authority; use announcements only for discovery/date context.  
**Warning signs:** Ruleset version is absent, or code behavior cannot name Article 15/16/17/23.

### Pitfall 2: Activating on draw completion before the schedule is complete

**What goes wrong:** Groups appear, but fixtures lack stable IDs or confirmed kickoffs and become forecast-eligible prematurely.  
**Why it happens:** UEFA compiles the fixture list after the draw, and source pages can publish in stages. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-24-Match-dates-and-fixtures-Online]  
**How to avoid:** Enforce D-01/D-02 as one bundle gate; keep a candidate isolated until every pairing passes.  
**Warning signs:** Any missing kickoff, duplicate fixture ID, unresolved team, or mixed bundle revision.

### Pitfall 3: Double-counting hosts

**What goes wrong:** A host counted as a direct qualifier and also as a reserved slot, changing the number of available play-off places.  
**Why it happens:** Direct qualification and host reservation are separate rule paths. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online]  
**How to avoid:** Maintain an allocation ledger with `direct`, `host_reserved`, `host_reserved_slot_status`, and `consumes_capacity` fields.  
**Warning signs:** Reserved-slot count is derived from team labels rather than a ledger transition.

### Pitfall 4: Hardcoding the number of play-off teams

**What goes wrong:** A simulator always emits eight teams or always emits single-leg paths.  
**Why it happens:** The official announcement describes the format compactly, while Article 16 branches on host slots. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online]  
**How to avoid:** Enumerate `reserved_slots_used = 2, 1, 0` and validate entrant/place counts and match topology for each branch.  
**Warning signs:** No topology ID in output, or a topology table with only one shape.

### Pitfall 5: Ranking five-team groups on all matches

**What goes wrong:** Best runners-up are unfairly compared using matches against fifth place.  
**Why it happens:** The group standings and overall rankings have different scopes. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online]  
**How to avoid:** Carry the excluded fifth-place match IDs in ranking evidence and test group-size mixtures.  
**Warning signs:** Cross-group ranking uses a single `points` column without an exclusion set.

### Pitfall 6: Using final Nations League rankings for EURO eligibility

**What goes wrong:** Eligibility is shifted by post-league knockout results or by display order.  
**Why it happens:** UEFA Article 16 names the interim overall ranking, while Phase 15 also produces final outcomes. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online]  
**How to avoid:** Require the Phase 15 handoff to declare the ranking stage and source/rules hashes; reject a final-only or incomplete handoff.  
**Warning signs:** Eligibility code reads `final_overall_rank` without checking `ranking_stage`.

### Pitfall 7: Assuming extra draw conditions are known

**What goes wrong:** The implementation publishes a bracket that violates a later UEFA-approved draw constraint.  
**Why it happens:** Article 16 says additional principles and conditions may apply subject to Executive Committee approval. [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online]  
**How to avoid:** Model draw constraints as versioned source inputs; return `unsupported_topology` or `unresolved_draw_conditions` rather than guessing.  
**Warning signs:** Draw policy is hardcoded but has no source artifact or hash.

### Pitfall 8: Mixing candidate and accepted revisions

**What goes wrong:** New UEFA corrections replace groups or fixtures partially, so standings, forecasts, and qualification logic use different snapshots.  
**Why it happens:** Source pages may change independently and the project has explicit revision/rollback requirements. [VERIFIED: codebase grep]  
**How to avoid:** Build all edition artifacts from one candidate bundle ID and promote atomically after full validation.  
**Warning signs:** Child artifact source hashes disagree, or the active registry points to a candidate directory.

### Pitfall 9: Showing pre-draw probabilities

**What goes wrong:** Users interpret projected groups or hypothetical host paths as official qualifying probabilities.  
**Why it happens:** The simulator can technically sample teams before the draw, but D-14/D-15 prohibit it. [VERIFIED: codebase grep]  
**How to avoid:** Keep all qualification probability tables empty or `unavailable` with edition-level reason `pre_draw`; do not emit projected teams.  
**Warning signs:** Any pre-draw row contains a team, fixture, group, path, or probability.

## Code Examples

Verified patterns from project/official sources:

### Topology branch contract

```r
euro_playoff_topologies <- function() {
  data.frame(
    reserved_slots_used = c(2L, 1L, 0L),
    entrant_count = c(8L, 12L, 8L),
    qualifying_places = c(2L, 3L, 4L),
    topology_id = c("two_paths_single_leg", "three_paths_single_leg", "four_home_away_ties"),
    stringsAsFactors = FALSE
  )
}
```

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] These are the three official branch cardinalities; the table must remain ruleset-versioned and should be validated against source-supplied topology metadata where available.

### Cross-group ranking evidence

```r
rank_for_euro_overall <- function(standings, fixtures) {
  # For group positions 1:4 in a five-team group, remove fifth-place matches.
  standings$counted_match_ids <- derive_article23_counted_matches(standings, fixtures)
  standings <- derive_article15_group_position(standings, fixtures)
  order_article23(standings)
}
```

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online] The implementation needs evidence columns for counted/excluded matches; the helper names are illustrative and are not existing APIs.

### Pre-draw suppression

```r
euro_pre_draw_output <- function(edition_row, source_bundle) {
  list(
    lifecycle_state = "pre_draw",
    forecast_status = "pre_draw",
    forecast_reason = "awaiting_official_draw_and_schedule",
    official_draw_date = edition_row$official_draw_date,
    groups = schema_empty("groups"),
    fixtures = schema_empty("fixtures"),
    standings = schema_empty("standings"),
    qualification_probabilities = schema_empty("qualification_probabilities"),
    source_bundle_id = source_bundle$source_bundle_id
  )
}
```

[VERIFIED: codebase grep] This extends the exact empty-output behavior already asserted by Phase 14 tests. It must not be used for a partially accepted post-draw bundle; that case remains candidate-isolated and emits an unavailable/blocked validation result.

## State of the Art

| Old approach | Current approach | When changed | Impact |
|---|---|---|---|
| High-level 2025 announcement only | Enforced 2026–28 regulations with Article 13-17 and 23-24 details | [CITED: https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/] Announcement 2025-05-21; regulations enforcement 2026-07-29 | Plans can lock exact tie-breakers, host ledger behavior, allocation order, and topology formats. |
| Single conceptual play-off path | Three host-dependent official topology branches | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] Current regulation edition | Simulator and output schema must be topology-polymorphic. |
| Calendar/date-only pre-draw handling | Complete official draw-and-schedule bundle gate | [VERIFIED: codebase grep] Phase 16 context and existing Phase 13/14 contracts | Draw date alone cannot activate forecasts. |

**Deprecated/outdated:**

- [CITED: https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/] Treat the 2025 announcement's promise that detailed regulations would be published later as historical context, not a reason to leave current rule behavior unresolved.
- [VERIFIED: codebase grep] Treat any projected or hypothetical pre-draw bracket as incompatible with the locked Phase 16 contract, even if a simulation could generate one.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | [ASSUMED] The exact post-draw UEFA page or export endpoint for the complete draw-and-schedule bundle cannot be fixed before UEFA publishes it and may differ from current navigation paths. | Sources / Activation Boundary | The acquisition adapter may need a small source URL/config update after the draw; do not hardcode an unverified endpoint now. |
| A2 | [ASSUMED] UEFA's future operational draw procedure may add constraints beyond the Article 16 principles that are currently published. | Play-off eligibility and topology | A later source/rules revision may be required before publishing official path assignments. |
| A3 | [ASSUMED] Phase 15's accepted transition outcome handoff will be the durable cross-competition source at execution time, subject to its own validation status. | Nations League-linked input | If the handoff is absent or incomplete, EURO play-off eligibility must stay unresolved and probability outputs must be suppressed. |
| A4 | [ASSUMED] The exact compact EURO outcome filenames and enum spellings are still discretionary because this phase has no implementation yet. | Architecture Patterns | Planner must lock names consistently across R, tests, manifests, and Phase 17 payload consumers. |

## Open Questions (RESOLVED)

The five planning questions below are resolved at the contract level on 2026-08-23. Future UEFA content can revise an accepted bundle only through the existing manifest, hash, and candidate-validation boundary; it does not change these implementation obligations.

1. **What exact UEFA artifacts will contain the full draw-and-schedule bundle after 2026-12-06?**
   - Resolution: Keep acquisition manifest/config-driven and retain the URL or resource locator discovered by the registered adapter. Do not hardcode an unknown future endpoint. The accepted source bundle must retain raw snapshot metadata and validate all five required resource classes, matching provenance/hashes, stable identities, complete official groups and fixtures, and confirmed kickoff timestamps before activation.
   - Planned proof: Phase 16 source-bundle tests exercise missing resources, incomplete kickoff metadata, invalid hashes, and a valid complete post-draw candidate without making a network call.

2. **Will UEFA publish additional play-off draw conditions before the paths are drawn?**
   - Resolution: Treat any additional condition as an accepted, versioned rules input with its own source artifact identity and canonical hash. A missing, partial, or unrecognised condition set returns `unresolved_draw_conditions` and `unsupported_topology`; the rules adapter and simulator suppress probabilities rather than selecting a familiar bracket.
   - Planned proof: Topology and simulation tests reject absent/incomplete draw-condition inputs and preserve the accepted prior rules revision during candidate validation.

3. **When should actual host-slot usage become deterministic?**
   - Resolution: Pre-draw and active-after-draw scenario status may be visible, including scenario-keyed host/topology rows, but actual host usage is deterministic only after the required completed standings/results resolve the covered host associations. The allocation ledger must never collapse unresolved scenario branches into one host count or bracket. Once resolved, select the two highest-ranked covered hosts when more than two host associations are present, consume only those two reserved places, and preserve all remaining/unused slots explicitly.
   - Planned proof: Tests cover an active bundle with real groups/confirmed kickoffs and zero completed results, zero/one/two used host slots, and a four-host synthetic case with deterministic top-two selection after completed results.

4. **What exact Phase 15 artifact is the accepted EURO eligibility input?**
   - Resolution: Use a registered, validated Phase 15 outcomes adapter keyed by stable `team_id`. The handoff must include the canonical interim ranking projection with `ranking_scope = "interim_overall"` and `ranking_stage = "interim_overall"`, plus the accepted manifest/source/rules lineage required by the Phase 15 contract. The production anchors are `uefa_nl_rank_interim_overall()` at `R/competition/uefa_nations_league_rules.R:1467-1498` and `uefa_nl_sim_rank_capture()` at `R/competition/uefa_nations_league_simulation.R:1829-1857`; because the latter currently overwrites interim rows from final-ranking stages, Phase 16 must preserve or derive the canonical interim fields in its adapter rather than trusting a copied `ranking_stage`. The registered `outputs/competition/uefa_nations_league_2026_27/outcomes/projected_rankings.csv` is currently final-only/blocked and is a required rejection fixture, not a synthetic positive input. Final-only, wrong-stage, duplicate, missing, or unresolved rows produce `unresolved_external_eligibility` and suppress probabilities.
   - Planned proof: Phase 16 handoff tests read the registered Phase 15 output and manifest, accept only a complete Phase 15-native interim projection after normalization, and reject `final_overall`, `final_overall_pre_finals`, group-stage, missing, duplicate, and unresolved handoffs.

5. **How is the EURO lifecycle activated after the official bundle is accepted?**
   - Resolution: Keep `data/competition/registries/competition_editions.csv:3` at `pre_draw` through draw-date passage. Validate the complete official status/groups/fixtures bundle first, then use the sole authority `phase13_transition_competition_edition()` in `R/competition/edition_registry.R:435-459` to persist the canonical `pre_draw -> scheduled` transition and pass that transitioned row into the accepted-refresh path in `scripts/acquire_uefa_snapshot.R:2863-2921`. The pre-draw structural guard at `scripts/acquire_uefa_snapshot.R:2082-2087` remains active until acceptance; date alone never activates state.
   - Planned proof: Lifecycle tests exercise date-only, incomplete, missing-kickoff, complete accepted, and next-Phase-14-build cases through temporary registry/state roots and assert lifecycle, revision, row-hash, bundle, and state-path lineage.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---:|---|
| R / Rscript | Rules, state, simulation, tests | yes | 4.6.1 | None needed. |
| `testthat` | Focused and full validation | yes | 3.3.2 | None; planner should add Wave 0 test file if absent. |
| `digest` | Source/rules/manifest hashes | yes | 0.6.39 | None; existing contracts require it. |
| `jsonlite` | Existing JSON contracts | yes | 2.0.0 | Use existing file-backed CSV/RDS contracts where JSON is not needed. |
| Node/npm | Repository utility tooling only | yes | Node 26.6.0 / npm 11.18.0 | Not required for EURO rules execution. |
| UEFA live draw/schedule source | Post-draw activation | not yet available as a complete bundle | — | Remain `pre_draw` or candidate-isolated/unavailable; do not invent data. |

**Missing dependencies with no fallback:** None for pre-draw implementation and rules tests. The future official draw/schedule bundle is a required external input for post-draw activation, not an installable dependency.

**Missing dependencies with fallback:** The absent post-draw source has the explicit `pre_draw`/`unavailable` fallback mandated by D-13 through D-16.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | `testthat` 3.3.2 [VERIFIED: local environment] |
| Config file | Existing project testthat setup; new focused file is a Wave 0 gap [VERIFIED: codebase grep] |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R")'` |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| COMP-03 | Pre-draw remains zero-row/schema-valid; complete official draw/schedule candidate activates; incomplete candidate does not replace accepted state. | Contract/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R")'` | No - Wave 0 |
| COMP-04 | Article 15 group ties, Article 23 mixed-size ranking, Article 14 host allocation, and ruleset version/hash validation are exact. | Unit/contract | Same focused command | No - Wave 0 |
| SIM-02 | All three host-slot topology branches, allocation order, potting, seeded/aggregate resolution, and Phase 15 eligibility join are covered. | Unit/integration | Same focused command | No - Wave 0 |
| SIM-04 | Pre-draw, unresolved eligibility, unsupported topology, missing kickoff, invalid source bundle, and stale candidate all suppress derived rows/probabilities. | Negative/integration | Same focused command | No - Wave 0 |

### Sampling Rate

- **Per task commit:** `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R")'`
- **Per wave merge:** `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`
- **Phase gate:** Focused and relevant regressions pass, and the full suite has no failures beyond the Wave 0 baseline fingerprint before `$gsd-verify-work`; any persistent known failure is reported separately.

### Wave 0 Gaps

- [ ] `tests/testthat/test_phase16_euro_qualifying.R` - covers COMP-03, COMP-04, SIM-02, and SIM-04.
- [ ] Small synthetic fixtures for 12-group mixed-size ranking, four host associations, duplicate/unknown team IDs, missing kickoff, and all three topology branches.
- [ ] A synthetic Phase 15 eligibility handoff with valid, incomplete, duplicate, wrong-ranking-stage, and unresolved rows.
- [ ] A candidate-publication test proving the last accepted EURO bundle remains byte/hash unchanged when a post-draw correction fails.

## Security Domain

[CITED: https://devguide.owasp.org/en/03-requirements/05-asvs/] OWASP ASVS identifies input validation, stored cryptography, error/logging, data protection, files/resources, and configuration as relevant verification categories; this phase has no authentication or session surface, but it ingests untrusted external source artifacts and writes public derived files.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | [VERIFIED: codebase grep] Static file-backed pipeline has no user authentication boundary in this phase. |
| V3 Session Management | no | [VERIFIED: codebase grep] No session state is introduced. |
| V4 Access Control | no | [VERIFIED: codebase grep] No server-side authorization surface is introduced; publication control is repository/file transaction integrity. |
| V5 Input Validation | yes | Validate exact schemas, enum values, stable IDs, dates, kickoff confirmation, source hashes, rules revision, and parent bundle identity before acceptance. |
| V6 Cryptography | yes, narrow | [VERIFIED: codebase grep] Use existing `digest` SHA-256 helpers for source, rules, manifest, and parent identity; do not implement cryptography. |
| V7 Error Handling and Logging | yes | Preserve machine-readable failure reason, candidate/accepted bundle identity, source URL, retrieval time, and revision warning without exposing partial outputs. |
| V12 Files and Resources | yes | Reject path traversal/symlinks and use existing trusted-root/candidate transaction checks. |
| V14 Configuration | yes | Validate edition, ruleset, source bundle, model release, and output-root pins before build. |

### Known Threat Patterns for R/file-backed pipeline

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Malformed or adversarial source CSV/JSON | Tampering | Exact schema, enum, hash, uniqueness, and source-provenance validation before normalization. |
| Stale or mixed EURO/Nations League bundles | Tampering / Repudiation | Bind all outputs to edition IDs, source bundle hashes, Phase 15 parent hashes, and ruleset versions. |
| Candidate path escape or symlink | Elevation of privilege | Reuse Phase 13 trusted-root containment and symlink rejection before promotion. |
| Fabricated pre-draw data | Information disclosure / Integrity | Zero-row schemas, explicit status/reason fields, and tests that reject any pre-draw structural rows/probabilities. |
| RNG or draw-policy drift | Repudiation | Seeded runs, explicit draw-policy identity/hash, deterministic replay tests, and simulation metadata. |

## Sources

### Primary (HIGH confidence)

- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-13-Group-formation-qualifying-group-stage-Online] Article 13 group formation and host/Northern Ireland draw constraints; accessed 2026-08-23. Current 2026–28 regulations, enforcement date 2026-07-29.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online] Article 14 direct qualification and host-reserved places; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-15-Equality-of-points-qualifying-group-stage-Online] Article 15 qualifying-group tie-breakers; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online] Article 16 all three play-off topologies, allocation, draw pots, and host constraints; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-17-Match-system-play-offs-Online] Article 17 single-leg and two-leg play-off resolution; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-23-Overall-European-Qualifiers-rankings-Online] Article 23 cross-group rankings and group-of-five exclusions; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-24-Match-dates-and-fixtures-Online] Article 24 post-draw fixture compilation and scheduling principles; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Annex-A-2026-28-National-Team-Match-Calendar-Online] Annex A national-team match calendar; accessed 2026-08-23. Current 2026–28 regulations.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] Nations League Article 19 interim ranking bands and ranking lineage; accessed 2026-08-23. Current 2026/27 regulations.
- [CITED: https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/] UEFA Executive Committee high-level qualification-system announcement; published 2025-05-21, accessed 2026-08-23. Limitation: high-level announcement predates the detailed regulations.
- [CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/] UEFA official draw-date announcement; published/updated 2026-07-16, accessed 2026-08-23. Limitation: it confirms timing and high-level stages, not the future draw payload or final fixture IDs.
- [CITED: https://www.uefa.com/euro2028/about/] UEFA EURO 2028 hub linking the competition regulations and official qualification-system information; accessed 2026-08-23. Limitation: dynamic navigation is not a stable data API.

### Secondary (MEDIUM confidence)

- [VERIFIED: codebase grep] `.planning/research/SUMMARY.md` and `.planning/research/ARCHITECTURE.md` - existing project source volatility, pre-draw, source-adapter, state, payload, and publication boundaries.
- [VERIFIED: codebase grep] `R/competition/edition_registry.R`, `R/competition/source_contracts.R`, `R/competition/publication_hashes.R`, `R/competition/publication_transaction.R`, and `R/competition/state_bundle.R` - current source, lifecycle, activation, hash, and transaction contracts.
- [VERIFIED: codebase grep] `R/competition/uefa_nations_league_outcomes.R`, `R/competition/uefa_nations_league_rules.R`, and `R/competition/uefa_nations_league_simulation.R` - Phase 15 stable-ID handoff, rules hashes, outcome schema, and deterministic simulation patterns.
- [VERIFIED: codebase grep] `tests/testthat/test_phase13_publication_integration.R`, `tests/testthat/test_phase13_publication_hashes.R`, and `tests/testthat/test_phase14_state_bundle.R` - existing EURO pre-draw and candidate-publication assertions.

### Tertiary (LOW confidence)

- [ASSUMED] Future UEFA post-draw page/export paths, operational revision identifiers, and any additional draw conditions not yet published as of 2026-08-23 require validation when the source bundle becomes available.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - [VERIFIED: local environment] installed R/runtime packages and [VERIFIED: codebase grep] locked project modules; no new dependency recommended.
- Architecture: HIGH - [VERIFIED: codebase grep] Phase 13-15 contracts directly inspected and decisions copied from CONTEXT.md.
- UEFA rules: HIGH - [CITED: UEFA 2026–28 regulations] current Articles 13-17, 23, 24 and the 2026/27 Nations League Article 19 were checked on 2026-08-23.
- Future source artifacts: MEDIUM/LOW - official date is confirmed, but the post-draw data bundle and any additional operational draw conditions do not yet exist in the repository and may change.
- Simulation design: MEDIUM - [VERIFIED: codebase grep] Phase 15 seeded patterns are concrete; EURO-specific output names and scenario representation remain discretionary.

**Research date:** 2026-08-23  
**Valid until:** 2026-08-30 for source availability; recheck immediately when UEFA publishes the draw, schedule, source revision, or additional play-off draw procedure.
