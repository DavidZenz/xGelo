# Phase 15: Nations League Rules and Outcomes - Research

**Researched:** 2026-08-22  
**Domain:** UEFA Nations League 2026/27 competition rules, rankings, and Monte Carlo outcome projections  
**Confidence:** HIGH for official topology and rules; MEDIUM for the design of future source/stage inputs; HIGH for repository integration points

## User Constraints

[VERIFIED: codebase grep] No Phase 15 `*-CONTEXT.md` exists, so there are no additional phase-specific locked decisions, discretion areas, or deferred ideas to copy here. The authoritative scope is the user-provided Phase 15 objective, `COMP-02`, `SIM-01`, the roadmap success criteria, and the existing Phase 13/14 contracts.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-02 | The 2026/27 Nations League registry represents Leagues A-D, published groups, league-phase fixtures, and downstream knockout or play-off stages. | Official Articles 12-13 define the stages and league/group topology; the accepted bundle already contains the 14 published groups and 156 league-phase fixtures. The plan must add an explicit stage/topology representation and keep future official stage fixtures distinct from projected slots. |
| SIM-01 | The Nations League simulator reports projected standings, League A quarter-final and title paths, direct promotion/relegation, and applicable promotion/relegation play-offs. | Articles 15-19 define group ordering, cross-group comparison, interim rankings, transitions, play-off eligibility, and League A knockout resolution. Phase 14 provides cutoff-safe forecasts, score distributions, form, provenance, and deterministic batch seams for the simulator. |

## Summary

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-12-Competition-stages-Online] The official 2026/27 competition has a league phase of 14 groups: four groups of four in each of Leagues A, B, and C, and two League D groups whose size may be three or four. The League A knockout stage contains quarter-finals followed by a finals tournament with semi-finals, a third-place match, and a final. The next-edition play-offs are A/B, B/C, and C/D.

[VERIFIED: codebase grep] The accepted Nations League bundle currently contains the official 2026/27 published groups, 156 league-phase fixtures, and 156 scheduled result rows. It has 14 groups, 54 resolved team identities, zero completed results, zero standings rows, zero competition-form rows, and 156 available Phase 14 fixture forecasts as of the checked worktree. This means Phase 15 must support a truthful scheduled state now and become outcome-complete as UEFA publishes results and later-stage fixtures.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] The core modeling boundary is not a generic group table. UEFA has group standings, individual-league rankings, interim overall rankings, final overall rankings, direct transitions, and drawn two-leg ties. The simulator must implement these as separate stages and retain the ruleset version/hash with every projection.

**Primary recommendation:** Add a dedicated, data-driven Nations League rules adapter and outcome simulator that consumes the Phase 14 candidate, keeps its eleven-artifact state bundle intact, and writes a separate hashed Phase 15 outcomes bundle with explicit `official`, `projected`, `unresolved`, and `suppressed` statuses.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Official group/fixture/result ingestion | Database / Storage | API / Backend | [VERIFIED: codebase grep] Phase 13 accepted snapshots and `R/competition/uefa_nations_league_adapter.R` own source-shaped data, hashes, and identity lineage. |
| Cutoff-safe league standings | API / Backend | Database / Storage | [VERIFIED: codebase grep] `phase14_compute_standings()` owns universal arithmetic and requires a ruleset adapter for official ordering. |
| Nations League tie-break and cross-group ranking | API / Backend | Database / Storage | [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-15-Equality-of-points-league-phase-Online] and Article 19 define stateful ranking rules that must remain server-side/derived, not browser heuristics. |
| Match forecasts and form | API / Backend | Database / Storage | [VERIFIED: codebase grep] Phase 14 `forecast_layer.R`, `form.R`, and state candidates already produce the shared, cutoff-safe inputs. |
| League A paths and promotion/relegation projections | API / Backend | Database / Storage | [VERIFIED: codebase grep] These are derived simulation outputs with model, source, seed, and ruleset lineage; they should not be recomputed by a static renderer. |
| Dashboard-ready outcomes payload | CDN / Static | API / Backend | [VERIFIED: codebase grep] The project publishes static bundles under `outputs/competition`; Phase 17 owns shared rendering and atomic publication. |

## Official Rules Research

### Topology and Published 2026/27 Groups

[CITED: https://www.uefa.com/uefanationsleague/news/0298-1d6ef1acfaef-b54fcf1da859-1000--2026-27-uefa-nations-league-all-you-need-to-know/] The published groups are:

| League | Groups | Published team count | League-phase matches per team |
|---|---:|---:|---:|
| A | A1-A4 | 16 | 6 |
| B | B1-B4 | 16 | 6 |
| C | C1-C4 | 16 | 6 |
| D | D1-D2 | 6 in the accepted 2026/27 snapshot | 4 |

[VERIFIED: codebase grep] The accepted `groups.csv` has four A, four B, four C, and two D rows. The accepted fixture counts by group are 12 for each A/B/C group and 6 for each D group, which matches the published 4-team double round robin and 3-team double round robin.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-13-Group-formation-league-phase-Online] Article 13 allocates the top 16 access-list teams to A, ranks 17-32 to B, ranks 33-48 to C, and the remaining teams to D; group composition is determined by an access-list-seeded draw. The implementation must derive the team universe from the accepted edition bundle and access-list metadata rather than hardcoding a permanent team list.

[CITED: https://www.uefa.com/uefanationsleague/news/02a2-1fea18abbcbc-456e846509e7-1000--2026-27-uefa-nations-league-all-the-league-phase-fixtures/] UEFA publishes the league-phase fixture list and identifies matchdays 1-6. The current accepted source endpoint is the UEFA match API URL recorded in `data/competition/registries/source_artifacts.csv`, while the human-readable fixture page is the registry's source reference.

### League-Phase Standings and Tie-Breakers

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-14-Match-system-league-phase-Online] League matches are home-and-away against every other team in the group; a win gives three points, a draw one, and a defeat zero.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-15-Equality-of-points-league-phase-Online] When teams in one group finish level on points, apply this exact ordered list:

1. Points in matches between the tied teams.
2. Goal difference in matches between the tied teams.
3. Goals scored in matches between the tied teams.
4. Reapply criteria 1-3 only to the matches between the remaining tied teams if a subset remains tied.
5. Overall group goal difference.
6. Overall group goals scored.
7. Overall group away goals scored.
8. Overall group wins.
9. Overall group away wins.
10. Lower disciplinary-points total, where a red card is 3 points, a yellow card is 1 point, and an expulsion for two yellows is 3 points.
11. Higher position in the 2026/27 Nations League access list.

[VERIFIED: codebase grep] `phase14_compute_standings()` intentionally computes universal played/W/D/L/goals/goal-difference/points and invokes a supplied adapter for competition-specific ordering. It is therefore the correct reducer seam, but the existing `R/forecast/tournament.R::rank_group_table()` is not a valid Nations League ranker: it has a random fallback tie-breaker and only a reduced head-to-head implementation.

### Cross-Group and Interim Overall Rankings

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] Individual league rankings compare teams by group position first, then points, goal difference, goals scored, away goals, wins, away wins, disciplinary points, and access-list position. For leagues with different-sized groups, results against fourth-placed teams are excluded when comparing teams placed first, second, or third; all results are included when comparing fourth-placed teams.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] The interim overall ranking places A teams in ranks 1-16, B in 17-32, C in 33-48, and D in 49-55 according to their individual-league rankings. The regulation's 49-55 range differs from the currently accepted 54-team published snapshot, so the implementation must be cardinality-aware and must not assume that rank 55 is always present.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] In the comparison function, use a rank-aware match filter: for a team in position 1-3, remove results against the fourth-placed team of its own group only when such a team exists; for a team in position 4, retain all results. Do not remove a team's matches against another team merely because the other group has a different size.

### Promotion, Relegation, and Play-Offs

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] Direct transitions are:

| Outcome | Official rule |
|---|---|
| Direct promotion | Four group winners in B promote to A; four group winners in C promote to B; two D group winners promote to C. |
| Direct relegation | Four A fourth-placed teams relegate to B; four B fourth-placed teams relegate to C; C interim ranks 47 and 48 relegate to D. |
| A/B play-offs | A third-placed teams ranked 9-12 play B runners-up ranked 21-24; winners go to A and losers to B. |
| B/C play-offs | B third-placed teams ranked 25-28 play C runners-up ranked 37-40; winners go to B and losers to C. |
| C/D play-offs | Best C fourth-placed teams ranked 45-46 play D runners-up ranked 51-52, if contested; winners go to C and losers to D. |

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-16-Match-system-play-offs-Online] All play-offs are drawn with higher-league teams seeded and lower-league teams at home in the first leg. Each tie is two legs and the greater aggregate score wins; tied aggregates use Article 18 extra time and penalties.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-16-Match-system-play-offs-Online] The C/D play-offs are not played if any due participant qualifies for the EURO 2028 qualifying play-offs in March 2028. In that case, the rules retain C ranks 46-47 and D ranks 50-51 for the next edition. This is an explicit external-state branch and must be represented as a rule condition, not inferred from a missing fixture list.

### League A Quarter-Finals and Finals

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-17-Match-system-League-A-knockout-stage-Online] The four League A group winners and four runners-up enter the quarter-finals. Winners are seeded, each is drawn against a runner-up from a different group, and the runner-up hosts the first leg. Quarter-finals are two-legged aggregate ties.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-17-Match-system-League-A-knockout-stage-Online] Semi-finals, the third-place match, and the final are single-leg matches at designated venues. Semi-final pairings are drawn; the winners meet in the final and the losers meet in the third-place match. If a host association is a semi-finalist, UEFA's administrative Team A/Semi-final 1 rule affects the final and third-place ordering.

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-18-Extra-time-and-penalty-shoot-outs-Online] A tied aggregate after the second leg goes to two 15-minute extra-time periods, then penalties if still tied. A tied semi-final or final goes to extra time and penalties; a tied third-place match goes directly to penalties.

## Existing Data and Provenance Contract

### Accepted Source Fields

[VERIFIED: codebase grep] The Phase 13 source contract requires exactly five structured resource classes: `fixtures`, `groups`, `standings`, `results`, and `status`. Unknown resource classes are rejected by `phase13_validate_structured_resource_names()` and `phase13_validate_source_bundle()`.

[VERIFIED: codebase grep] Every accepted artifact carries `artifact_id`, `bundle_id`, `edition_id`, `artifact_type`, `source_url`, `retrieved_at_utc`, byte count, `raw_sha256`, `parser_commit_sha`, `fallback_status`, `review_state`, local raw path, and row hash. The bundle requires one edition-wide fallback status, one parser identity, an accepted state, complete resource coverage, and self/content hashes.

[VERIFIED: codebase grep] The current Nations League source bundle is `nl-2026-27-official-uefa-v2`, accepted on `2026-08-17T20:48:22Z`, official rather than reviewed fallback, with parser commit prefix `d322121`. All five artifacts point to `https://match.uefa.com/v5/matches?competitionId=2014&seasonYear=2027&offset=0&limit=200` and share the same raw-byte hash in the registry.

[VERIFIED: codebase grep] `R/competition/uefa_nations_league_adapter.R` currently validates a non-empty JSON array, competition 2014, season year 2027, fixture ID, status, kickoff, group, home team, and away team; it adapts fixture/group/team records and deliberately emits empty standings plus score-free scheduled results when the endpoint has no completed results.

### Missing Inputs for Full Rules and Outcomes

[VERIFIED: codebase grep] The current accepted fixture schema has no general `stage_id`, `round_id`, `leg_number`, `matchday`, `participant_slot`, `pairing_draw_id`, or downstream-stage fields. The current groups schema has no team-membership rows; membership is recoverable from fixture rows but should be made explicit in the Phase 15 topology payload.

[VERIFIED: codebase grep] The accepted standings artifact is empty and the accepted results rows are all `match_status=scheduled`, with missing score fields and `counts_for_standings=FALSE`, so no completed league-phase standings or official ranks are currently available.

[VERIFIED: codebase grep] The current accepted source contract does not carry access-list positions, disciplinary card totals, downstream knockout/play-off fixtures, EURO play-off eligibility, official draw pairings, or downstream results. These fields are required to fully resolve UEFA criteria 10-11, official interim ranking comparisons, C/D cancellation, and completed stage outputs.

[ASSUMED] UEFA will publish later-stage pairings/results through a source surface that can be accepted without replacing the five-resource Phase 13 contract. If the official source requires a sixth resource class, the planner must either extend the source contract deliberately or store an independently hashed rules/stage capture outside the accepted structured bundle; it must not silently add an unknown class.

### Form and Forecast Handoff

[VERIFIED: codebase grep] Phase 14's state bundle keeps `state/competition_form.csv`, `state/all_international_form.csv`, and `state/model_form.csv` separate. The current NL durable output has zero competition/all-international display-form rows because there are no completed accepted results in the edition snapshot; model form rows are present but national-team xG is explicitly inactive/unavailable.

[VERIFIED: codebase grep] Phase 14 forecast rows carry calibrated `p_home`, `p_draw`, and `p_away`, expected goals, modal score, a G=40 score grid, suppression status, model/release/calibrator identities, model and feature cutoffs, source bundle hashes, ruleset version, form/history hashes, and generated time. Phase 15 should consume these rows and preserve their lineage rather than calling the legacy model or recalculating forecasts.

[VERIFIED: codebase grep] The current `local/score_distributions.rds` and `state/forecasts.csv` are separate from the calibrated 1X2 values. The plan must define how the simulator samples scorelines so it cannot sample an uncalibrated score grid while claiming calibrated competition outcomes: use the calibrated outcome simplex with a documented conditional scoreline distribution, or document and test a calibrated reweighting of the grid.

## Standard Stack

### Core

| Library / module | Version | Purpose | Why standard |
|---|---|---|---|
| R | 4.6.1 | Rules, standings, simulation, and payload generation | [VERIFIED: local environment] The project is R-first and the installed runtime is R 4.6.1. |
| Phase 14 competition modules | repository revision | Canonical matches, cutoff-safe standings, form, forecasts, and provenance | [VERIFIED: codebase grep] These are the completed shared contracts and the phase dependency. |
| `digest` | 0.6.39 | Row/table/ruleset/output SHA-256 hashes | [VERIFIED: local environment] It is installed and already used by Phase 13/14 hashing code. |
| `jsonlite` | 2.0.0 | UEFA JSON adapter boundary | [VERIFIED: local environment] It is installed and already used by the Nations League adapter. |

### Supporting

| Library / module | Version | Purpose | When to use |
|---|---|---|---|
| `testthat` | 3.3.2 | Focused Phase 15 contract and simulation tests | [VERIFIED: local environment] Use for all rules, edge-case, deterministic replay, and production smoke tests. |
| `dplyr` | 1.2.1 | Existing table manipulation in legacy tournament code | [VERIFIED: local environment] Reuse only where it matches existing code; rules should remain explicit and auditable. |
| `R/competition/standings.R` | Phase 14 | Universal arithmetic and ruleset-adapter seam | [VERIFIED: codebase grep] Use `phase14_compute_standings()` and `phase14_reconcile_standings()` rather than duplicating metric reduction. |
| `R/competition/forecast_layer.R` | Phase 14 | Forecast and score-distribution handoff | [VERIFIED: codebase grep] Use `phase14_build_fixture_forecasts()` outputs as the single model authority. |

**Installation:** [VERIFIED: local environment] No new external package is required or recommended for Phase 15.

## Architecture Patterns

### System Architecture Diagram

```text
Accepted UEFA bundle + accepted international history + Phase 14 candidate
        |
        v
Canonical fixtures/results -> cutoff-safe group standings -> UEFA Article 15 group rank
        |                                      |
        |                                      v
        |                          Article 19 individual league ranking
        |                                      |
        |                                      v
        |                            interim overall ranking
        |                         /          |          \
        v                        v          v           v
Open fixture forecasts   direct transitions  drawn A/B/B/C/C/D play-offs
and form lineage                 |          (two legs; lower league home first)
                                v
                         League A QF draw
                         (winners seeded vs different-group runners-up)
                                |
                                v
                     two-leg QF aggregate + ET/penalties
                                |
                                v
                   semi-final draw -> single-leg semi-finals
                         /                         \
                        v                           v
                 third-place match                 final
                                |
                                v
           hashed Phase 15 stage definitions, projected paths, team outcomes,
           official/unresolved status, and dashboard-ready payload
```

[VERIFIED: codebase grep] The diagram follows existing tier boundaries: Phase 14 owns the candidate and forecast state; Phase 15 owns rules and outcomes; Phase 17 owns rendering and atomic publication.

### Recommended Project Structure

```text
R/competition/
├── uefa_nations_league_adapter.R       # existing source adapter; extend only for accepted source fields
├── uefa_nations_league_rules.R         # new: immutable 2026/27 topology/rules and pure selectors
├── uefa_nations_league_simulation.R    # new: sampled league phase, draws, ties, and outcome aggregation
├── uefa_nations_league_outcomes.R      # new: schemas, manifests, status/provenance, payload projection
├── standings.R                         # existing universal reducer; adapter seam consumed by rules module
├── form.R                              # existing cutoff-safe display/model form
├── forecast_layer.R                    # existing calibrated forecast and score-grid handoff
└── state_bundle.R                      # existing Phase 14 candidate; preserve eleven-artifact contract
scripts/
└── build_nations_league_outcomes.R     # new: Phase 14 candidate -> Phase 15 outcomes bundle entrypoint
tests/testthat/
└── test_phase15_nations_league.R       # new: rules, ranking, stage, simulation, lineage, replay acceptance
```

[ASSUMED] The planner should keep Phase 14's eleven-artifact `state_artifacts` inventory unchanged and write Phase 15 derived outputs in a sibling `outcomes/` bundle under `outputs/competition/uefa_nations_league_2026_27/`. This avoids breaking the exact-inventory validator while giving Phase 17 a stable merged payload boundary.

### Pattern 1: Data-Driven Ruleset Adapter

**What:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-12-Competition-stages-Online] Represent topology, selectors, pairing policy, leg count, home-order policy, aggregate resolution, and downstream destination as data plus small pure functions.

**When to use:** [VERIFIED: codebase grep] Use whenever `phase14_compute_standings()` needs official ordering or when simulation must branch on stage eligibility.

**Recommended shape:**

```r
uefa_nl_2026_27_rules <- function() {
  list(
    ruleset_version = "uefa-nations-league-2026-27-v2",
    league_phase = list(
      leagues = c(A = 4L, B = 4L, C = 4L, D = 2L),
      team_counts = c(A = 16L, B = 16L, C = 16L, D = NA_integer_),
      matches_per_team = c(A = 6L, B = 6L, C = 6L, D = NA_integer_)
    ),
    group_tiebreak = c("h2h_points", "h2h_goal_difference", "h2h_goals",
                       "h2h_reapply", "goal_difference", "goals",
                       "away_goals", "wins", "away_wins", "discipline",
                       "access_list"),
    cross_group = list(exclude_fourth_for_positions = 1:3),
    stages = list(
      quarter_final = list(legs = 2L, seeded = TRUE, different_group = TRUE,
                          lower_seed_first_leg_home = TRUE, tie_break = "et_penalties"),
      semi_final = list(legs = 1L, draw = TRUE, tie_break = "et_penalties"),
      third_place = list(legs = 1L, tie_break = "penalties"),
      final = list(legs = 1L, tie_break = "et_penalties")
    )
  )
}
```

[ASSUMED] The exact list names above are a recommended implementation shape, not an existing repository API; the planner should lock the schema before coding and hash its canonical serialization.

### Pattern 2: Stage Slots Are Not Official Fixtures

[CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-17-Match-system-League-A-knockout-stage-Online] Store stage definitions and empty participant slots immediately, but only mark a stage match `official` when UEFA publishes its fixture/pairing. Store simulated participant assignments as `projected` with a draw-policy identifier. Store unresolved slots without invented team IDs.

Recommended status values are `official`, `projected`, `unresolved`, `completed`, and `suppressed`; [ASSUMED] these values should be finalized in the Phase 15 output schema and used consistently in the Phase 17 payload.

### Pattern 3: Separate Fixed Historical Outcomes from Sampled Open Fixtures

[VERIFIED: codebase grep] For each Monte Carlo iteration, copy accepted completed results into the simulated state, sample only eligible open fixture outcomes from the Phase 14 forecast handoff, rank every group using the Nations League adapter, then resolve transitions and stage draws. This preserves the Phase 14 point-in-time rule and prevents future actual results from entering pre-match features.

### Anti-Patterns to Avoid

- **Generic World Cup bracket reuse:** [VERIFIED: codebase grep] `simulate_tournament()` assumes a fixed fixture list, two advancing teams per group, and a one-match knockout shortcut; Nations League has no generic round-of-16 bracket, has two-leg QFs/play-offs, and has rules-dependent participant selectors.
- **Random tie-break fallback:** [VERIFIED: codebase grep] `rank_group_table()` uses `runif()` when no tie-break value exists; this is unacceptable for official UEFA ranking and deterministic replay.
- **Using official standings as future model inputs:** [VERIFIED: codebase grep] Phase 14 requires evidence and feature cutoffs; a simulated or later-published table may only affect the competition outcome layer, never an already generated pre-match forecast.
- **Treating missing downstream fixtures as fabricated placeholders:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-17-Match-system-League-A-knockout-stage-Online] The rules define valid future slots, but a published pairing is a separate source fact; keep those states distinct.
- **Hardcoding a 54-team League D rank range:** [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] The regulation text exposes ranks through 55 while the current accepted snapshot resolves 54 teams; derive cardinality and validate the source universe.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Universal match arithmetic | A second W/D/L/points reducer | [VERIFIED: codebase grep] `phase14_compute_standings()` | It already enforces evidence cutoff, score completeness, snapshot keys, and hashes. |
| Official group ordering | A simplified points/goal-difference sort | [CITED: UEFA Article 15] A dedicated Nations League adapter passed through the Phase 14 seam | UEFA requires recursive head-to-head, discipline, and access-list criteria. |
| Cross-group ranking | Compare raw group totals across all groups | [CITED: UEFA Article 19] Rank-aware exclusion of fourth-place results plus official comparison criteria | League D/group-size handling otherwise changes promotion/play-off eligibility. |
| Match probabilities | Refit or call legacy models | [VERIFIED: codebase grep] Phase 14 calibrated forecast rows and release resolver | Model identity, calibration, cutoff, and source lineage are already frozen. |
| Knockout winner probabilities | Treat every tied 90-minute result as an even random draw | [CITED: UEFA Article 18] Explicit two-leg aggregate, extra-time, and penalty resolution using the shared forecast route | Two-leg ties and single-leg finals have different resolution rules. |
| Source provenance | Add a loose CSV without hashes | [VERIFIED: codebase grep] Phase 13 artifact/bundle fields and a Phase 15 outcomes manifest | Later publication and audit require source bundle, raw/content hashes, parser identity, and ruleset identity. |
| Stage draw constraints | Encode one guessed bracket | [CITED: UEFA Article 16 and Article 17] Rules-driven legal draw sampler with a persisted draw-policy/hash | Pairings are not official before the draw and different-group/seed constraints must hold. |

**Key insight:** [CITED: UEFA Articles 15-19] Nations League outcomes are a state machine with several ranking universes and different match-resolution rules. A generic tournament simulator can produce plausible probabilities while being structurally wrong.

## Common Pitfalls

### Pitfall 1: Fourth-Place Exclusion Applied Globally

**What goes wrong:** [CITED: UEFA Article 19] A comparison helper removes every result against a fourth-place team, including the ranking of fourth-placed teams or groups with only three teams.

**Why it happens:** [VERIFIED: codebase grep] The current accepted snapshot has two three-team D groups, while the regulation describes a topology that may contain groups of different sizes.

**How to avoid:** [CITED: UEFA Article 19] Apply the exclusion per team position and only when the team has a fourth-placed group opponent; retain an audit column listing counted match IDs.

**Warning signs:** [VERIFIED: codebase grep] D ranking includes a missing team, individual league ranking totals have different match counts for equal positions, or C/D play-off eligibility changes when a fourth-place row is absent.

### Pitfall 2: Missing Cards or Access List Silently Become Random Ordering

**What goes wrong:** [CITED: UEFA Article 15] Tied teams are resolved with a synthetic/random fallback instead of discipline and access-list fields.

**How to avoid:** [VERIFIED: codebase grep] Add explicit `ordering_status`, `blocked`, `suppression_reason`, and `missing_rule_input` values. Permit provisional projections only when the result is clearly labeled and the exact tie-break cannot yet affect a published decision; otherwise fail closed.

### Pitfall 3: Calibrated 1X2 and Score Grid Disagree

**What goes wrong:** [VERIFIED: codebase grep] Current Phase 14 rows expose calibrated 1X2 but a separate analytic Negative Binomial score grid. Sampling the grid directly can produce uncalibrated W/D/L frequencies.

**How to avoid:** [ASSUMED] Use calibrated W/D/L probabilities for outcome sampling and conditionally sample scorelines within W/D/L, or implement and test an explicit grid reweighting step whose output simplex equals the calibrated probabilities.

### Pitfall 4: Two-Leg Tie Modeled as Two Independent One-Match Knockouts

**What goes wrong:** [CITED: UEFA Articles 16-18] The simulator awards a tie after a single match or resolves each leg independently without aggregate goals and second-leg extra time/penalties.

**How to avoid:** [CITED: UEFA Article 16] Model the two legs with correct home order, carry aggregate goals into the second-leg resolver, and use Article 18 only at the specified tie boundary.

### Pitfall 5: Future Competition Results Leak into Form or Forecasts

**What goes wrong:** [VERIFIED: codebase grep] Simulated standings or a later actual result is joined to Phase 14 feature inputs for a pre-match forecast.

**How to avoid:** [VERIFIED: codebase grep] Keep forecast generation before simulation and validate `feature_cutoff_utc`, `model_data_cutoff`, and contributing history hashes. Simulation consumes forecast artifacts; it never mutates their feature inputs.

### Pitfall 6: Official and Projected Stage Rows Are Mixed

**What goes wrong:** [ASSUMED] A static payload shows a projected quarter-final pairing as if it were an official UEFA fixture.

**How to avoid:** [ASSUMED] Carry `stage_status`, `source_artifact_id`, `projection_run_id`, and `draw_policy_id`; only official rows may have an official source artifact and source fixture ID.

## Code Examples

### Correct Phase 14 Handoff

```r
# Source: repository R/competition/standings.R and R/competition/state_bundle.R
group_table <- phase14_compute_standings(
  matches = canonical_results,
  edition_id = "uefa_nations_league_2026_27",
  group_id = "2014191",
  state_cutoff_utc = state_cutoff_utc,
  source_bundle_id = source_bundle_id,
  ruleset_adapter = uefa_nl_rank_group
)
```

[VERIFIED: codebase grep] This preserves the existing snapshot key and makes the Nations League ranker explicit.

### Legal Projection Row Contract

```r
# Source: recommended Phase 15 boundary; exact names require plan lock.
data.frame(
  edition_id = edition_id,
  team_id = team_id,
  stage_status = "projected",
  quarter_final_probability = p_qf,
  semi_final_probability = p_sf,
  final_probability = p_final,
  champion_probability = p_champion,
  direct_promotion_probability = p_direct_promotion,
  direct_relegation_probability = p_direct_relegation,
  playoff_eligibility_probability = p_playoff_eligibility,
  playoff_win_probability = p_playoff_win,
  playoff_loss_probability = p_playoff_loss,
  simulation_count = n_simulations,
  simulation_seed = seed,
  ruleset_version = ruleset_version,
  ruleset_sha256 = ruleset_sha256,
  source_bundle_id = source_bundle_id,
  model_release_id = model_release_id
)
```

[ASSUMED] These columns are a recommended output contract for `SIM-01`; the planner should add exact schema/hash tests before implementation.

## Recommended Plan Decomposition

1. **Ruleset and stage schema:** Create immutable 2026/27 topology/rule definitions, canonical ruleset hashing, stage status enums, source/projection slot schemas, and tests for the 14 groups, current group sizes, match counts, stage list, and no fabricated downstream fixture IDs.
2. **Official ranking adapter:** Implement Article 15 group ordering, recursive tied-subset behavior, disciplinary/access-list fields, Article 19 individual-league comparisons, fourth-place exclusion, interim ranking bands, and direct/play-off selectors using `phase14_compute_standings()`; add adversarial synthetic ranking fixtures.
3. **Outcome simulator:** Add fixed completed-result handling, calibrated open-fixture sampling, legal draw samplers, two-leg aggregate resolution, single-leg ET/penalty resolution, direct transitions, A/B/B/C/C/D play-offs, C/D cancellation branch, and per-team probabilities with deterministic seeds.
4. **Outcome bundle and entrypoint:** Add `scripts/build_nations_league_outcomes.R` plus an outcomes manifest and sibling `outcomes/` artifact set. Consume the Phase 14 candidate once, preserve all state artifacts, attach source/model/form/ruleset lineage, and fail closed on missing rule inputs or unresolved source state.
5. **Production acceptance:** Run the current accepted 2026/27 bundle through the new entrypoint, assert 54 teams/14 groups/156 fixtures, assert scheduled-state truthfulness, and exercise a synthetic completed-result/stage fixture that produces non-zero projected paths without changing Phase 14 forecast hashes.

[ASSUMED] The decomposition is the original five implementation waves plus a small Wave 0 harness; the bundle contract and CLI/output generation remain separate so the exact Phase 14 inventory and source-contract boundaries are independently testable.

## Acceptance Tests

### COMP-02

- [CITED: UEFA Article 12 and official draw page] Accepted production topology exposes A1-A4, B1-B4, C1-C4, D1-D2, League A/B/C groups of four, and current League D groups of three.
- [VERIFIED: codebase grep] Production topology exposes 156 accepted league-phase fixtures and 54 unique stable team IDs with no foreign edition rows.
- [CITED: UEFA Articles 12, 16, and 17] Stage definitions include League A quarter-finals, semi-finals, third-place match, final, A/B play-offs, B/C play-offs, and C/D play-offs, each with leg count, pairing policy, home-order policy, and tie-break policy.
- [ASSUMED] Before UEFA publishes a downstream pairing, stage slots are present with `unresolved`/`projected` status and no fake official fixture ID; after source publication, official rows retain source artifact lineage.
- [VERIFIED: codebase grep] Rebuilding the outcomes bundle with reversed input row order produces identical ruleset, stage, outcome, and manifest hashes.

### SIM-01

- [CITED: UEFA Articles 15 and 19] Synthetic tied groups verify all 11 tie-break criteria, recursive tied-subset reapplication, fourth-place exclusion, and missing-fourth handling.
- [CITED: UEFA Articles 16-18] Synthetic two-leg ties verify lower-league first-leg home assignment, aggregate scoring, second-leg ET/penalty resolution, and single-leg final/third-place resolution.
- [CITED: UEFA Articles 17 and 19] QF draw tests reject same-group winner/runner-up pairings, ensure all eight A teams are used once, and map QF winners/losers to the correct interim/final rank bands.
- [CITED: UEFA Article 19] With deterministic synthetic outcomes, direct promotion/relegation and all applicable play-off eligibility probabilities sum correctly per team and across league transition classes.
- [VERIFIED: codebase grep] Every simulated run carries a fixed seed, simulation count, ruleset version/hash, source bundle identity, approved model release identity, and input/output hashes.
- [VERIFIED: codebase grep] A regression asserts Phase 14 forecast rows and hashes are unchanged before and after outcome simulation, proving no forecast-time leakage from simulated future results.
- [ASSUMED] A calibrated simulation test should assert empirical W/D/L frequencies converge to the selected calibrated probability view within a tolerance justified by the sample count.

## State of the Art

| Old approach | Current approach | When changed | Impact |
|---|---|---|---|
| Generic `rank_group_table()` with random fallback | [CITED: UEFA Articles 15 and 19] Explicit ruleset adapter with deterministic official criteria | Phase 15 | Official rank and transition probabilities become reproducible. |
| Fixed bracket with one-match knockout shortcut | [CITED: UEFA Articles 16-18] Stage graph with two-leg and single-leg resolution policies | Phase 15 | QF and promotion/play-off paths match the edition rules. |
| Model calls inside tournament simulation | [VERIFIED: codebase grep] Phase 14 release-active forecast batch consumed as immutable input | Phase 14 handoff | Forecast provenance and point-in-time safety remain auditable. |
| Treat future stage pairings as known | [ASSUMED] Separate official source rows from legal projected draw slots | Phase 15 design | Current scheduled state remains truthful before later UEFA draws. |

**Deprecated/outdated:**

- [VERIFIED: codebase grep] `R/forecast/tournament.R::rank_group_table()` is not an official Nations League ranker and must not be used for COMP-02/SIM-01.
- [VERIFIED: codebase grep] `simulate_tournament()` is a useful legacy test pattern but does not model Nations League stage dependencies, aggregate ties, or official transition bands.

## Project Constraints (from AGENTS.md)

- [VERIFIED: AGENTS.md] Keep R as the primary language and preserve the existing targets/open-data-first architecture.
- [VERIFIED: AGENTS.md] Use canonical team identity and FIFA codes as primary keys; avoid unresolved or ambiguous names.
- [VERIFIED: AGENTS.md] Prevent temporal leakage: rolling/form features use only matches before the prediction date.
- [VERIFIED: AGENTS.md] Use the Negative Binomial forecast path rather than Poisson for football goal models.
- [VERIFIED: AGENTS.md] Use manual/reviewed caches for restricted sources; do not add automated FotMob scraping.
- [VERIFIED: AGENTS.md] Set deterministic seeds at script boundaries and run `testthat::test_dir("tests/testthat")` as the project-wide test command.
- [VERIFIED: AGENTS.md] Do not modify unrelated user changes, skip branches, or publish large raw response bodies.

## Runtime State Inventory

[VERIFIED: codebase grep] This is not a rename/refactor/migration phase, so runtime-state inventory is not applicable. No stored keys, live service registrations, OS registrations, secret renames, or installed-artifact renames are in scope.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---:|---:|---|
| R | Rules, simulation, tests | yes | 4.6.1 | none needed |
| R `testthat` | Focused and full regression | yes | 3.3.2 | none needed |
| R `digest` | SHA-256 lineage | yes | 0.6.39 | none; required by existing contracts |
| R `jsonlite` | UEFA adapter/replay | yes | 2.0.0 | none; required by existing adapter |
| R `dplyr` | Existing legacy simulation helpers | yes | 1.2.1 | base R for new rules code if needed |
| UEFA network/API | Future source refresh | not verified as live dependency in this session | — | Use accepted local raw bytes and reviewed fallback; fail closed when a new official snapshot is required |

[VERIFIED: local environment] R and the required installed packages are available. The focused test run passed Phase 14 form, forecast, and Nations League production checks; Phase 14 standings had one pre-existing row-name-attribute failure at `tests/testthat/test_phase14_standings.R:686`, and the long state-bundle test was stopped after extended runtime rather than treated as a Phase 15 blocker.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | [VERIFIED: local environment] `testthat` 3.3.2 |
| Config file | [VERIFIED: codebase grep] No dedicated Phase 15 test config; use repository `tests/testthat` conventions |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test type | Automated command | File exists? |
|---|---|---|---|---|
| COMP-02 | Official 2026/27 topology and published groups/fixtures load without foreign rows | integration | Phase 15 test file, production topology block | no; Wave 0 |
| COMP-02 | Stage definitions encode all official downstream stages without fabricated official fixtures | unit/integration | Phase 15 test file, stage schema block | no; Wave 0 |
| COMP-02 | Article 15/19 group and cross-group ranks are exact for adversarial ties and D group sizes | unit | Phase 15 test file, ranking block | no; Wave 0 |
| SIM-01 | Deterministic simulations produce standings, A QF/title paths, transition, and applicable play-off probabilities | integration | Phase 15 test file, simulator block | no; Wave 0 |
| SIM-01 | Aggregate/ET/penalty and C/D cancellation paths are resolved per rules | unit | Phase 15 test file, stage-resolution block | no; Wave 0 |
| SIM-01 | Simulation leaves Phase 14 forecasts and feature lineage unchanged | regression | Phase 15 test file, no-leakage block | no; Wave 0 |

### Sampling Rate

- **Per task commit:** [ASSUMED] Run the focused Phase 15 test file; keep synthetic simulations small enough to complete in under 30 seconds.
- **Per wave merge:** [VERIFIED: AGENTS.md] Run the focused Phase 13/14 regressions plus the Phase 15 file.
- **Phase gate:** [VERIFIED: AGENTS.md] Run the full `tests/testthat` suite before `$gsd-verify-work`, while recording the known standings row-name and full-suite deferred failures separately.

### Wave 0 Gaps

- [ ] [ASSUMED] `tests/testthat/test_phase15_nations_league.R` - rules, ranking, stage resolution, simulation, and lineage acceptance.
- [ ] [ASSUMED] Synthetic 3-team and 4-team group fixtures with tied standings and disciplinary/access-list inputs.
- [ ] [ASSUMED] Synthetic stage fixtures covering two-leg QF/play-off, single-leg semi/final, aggregate tie, ET, penalties, and C/D cancellation.
- [ ] [ASSUMED] Explicit Phase 15 outcomes schema and fixture for deterministic replay hashes.

## Security Domain

[CITED: https://devguide.owasp.org/en/03-requirements/05-asvs/] OWASP ASVS groups relevant controls under authentication, session management, access control, validation/sanitization/encoding, stored cryptography, business logic, files/resources, and configuration. This phase is a local/static analytics build with no user authentication or session boundary, so input validation, business logic, file/resource, integrity, and configuration controls are the relevant categories.

### Applicable ASVS Categories

| ASVS category | Applies | Standard control |
|---|---|---|
| V2 Authentication | no | [VERIFIED: codebase grep] No authentication flow is added by Phase 15. |
| V3 Session Management | no | [VERIFIED: codebase grep] No server session or cookie state is part of this static-output phase. |
| V4 Access Control | no for runtime users; yes for publication ownership | [ASSUMED] Keep outcome writing inside the existing trusted local publication boundary; do not accept arbitrary output paths from source payloads. |
| V5 Input Validation, Sanitization and Encoding | yes | [VERIFIED: codebase grep] Reuse strict source schemas, enum validation, canonical IDs, numeric bounds, path validation, and fail-closed unknown stage/resource checks. |
| V6 Stored Cryptography | limited | [VERIFIED: codebase grep] Use existing SHA-256 integrity hashes for source, ruleset, model, and outcomes; no new secret/password cryptography is needed. |
| V11 Business Logic | yes | [CITED: OWASP ASVS taxonomy] Treat promotion/relegation, draw constraints, rank bands, C/D cancellation, and tie resolution as validated business rules with adversarial tests. |
| V12 Files and Resources | yes | [VERIFIED: codebase grep] Reuse validated relative raw paths and the compact committed-output boundary; never publish raw response bodies or follow untrusted paths. |

### Known Threat Patterns for R/static source bundles

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| Forged or mixed official/fallback source rows | Tampering | [VERIFIED: codebase grep] Phase 13 edition-wide fallback consistency, raw/content hashes, parser SHA, bundle self-hash, and accepted-state validation. |
| Unknown stage/resource injected into a payload | Tampering / Elevation | [ASSUMED] Reject unknown stage IDs/resource classes and require ruleset/schema version before projection. |
| Path traversal through local raw/output path | Tampering | [VERIFIED: codebase grep] Keep Phase 13 local raw path validation and constrain Phase 15 output paths under the registered competition bundle. |
| Future results influencing forecast features | Information disclosure / Tampering | [VERIFIED: codebase grep] Preserve Phase 14 feature cutoffs and assert forecast hashes are unchanged after simulation. |
| Random tie or draw behavior changing output | Repudiation / Tampering | [VERIFIED: codebase grep] Seed once at the entrypoint, derive stable per-run/per-stage seeds, and hash the ruleset, draw policy, and sampled input manifest. |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | Resolved: later-stage facts use a separate raw/accepted/manifest/registry capture boundary and do not expand the Phase 13 five-resource contract. | Planning Resolution 1 | A future official source revision must be admitted through that registered capture boundary or an explicitly planned schema change. |
| A2 | Resolved: Phase 15 preserves the Phase 14 eleven-artifact state inventory and writes a sibling outcomes bundle. | Planning Resolution / Architecture | A later shared-state contract would require a separately planned migration; this phase does not move artifacts. |
| A3 | Resolved: the nine-file outcomes schema, statuses, fixture forecast/form pass-through, and completed-score fields are the SIM-01 planning contract. | Planning Resolution / Validation | Later dashboard consumers must use the manifest and status contract rather than infer fields. |
| A4 | Resolved: calibrated 1X2 probabilities drive simulation outcome sampling with the named conditional score-grid policy. | Planning Resolution 3 | A calibrator release change requires the recorded model/calibrator lineage and seeded empirical test to be updated together. |
| A5 | Resolved: projected/unresolved stage slots are publishable before official pairings only with visible projection/draw-policy lineage and never as official rows. | Planning Resolution 2 | A later official capture supersedes projected rows through a new admitted source snapshot. |
| A6 | Resolved: the current accepted snapshot has 54 stable teams and dynamic ranking code must not hardcode Article 19 rank 55. | Planning Boundary | A future accepted roster change must update the source snapshot and rerun cardinality validation. |
| A7 | Resolved: deterministic legal draw sampling is enabled before official QF/semi draws, with projected status and policy lineage. | Planning Resolution 2 | Once official pairings arrive, the separate capture takes precedence and projected rows must not remain official. |

## Planning Resolutions

The research questions below are closed for Phase 15 planning. They remain explicit runtime states where the required external fact is not yet available; none is left as an implicit implementation choice.

1. **Source admission for access-list, discipline, and downstream stage facts — resolved by a separate capture boundary.** The current Phase 13 source bundle remains exactly `fixtures`, `groups`, `standings`, `results`, and `status`. Phase 15 admits later-stage official facts through `data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-stage-capture-v1/stage_capture.json`, normalized `data/competition/accepted/uefa_nations_league_2026_27/stage_capture.csv`, companion `stage_capture_manifest.csv`, and `data/competition/registries/stage_captures.csv`; `phase15_uefa_nl_read_stage_capture()` validates its own raw/content/parent hashes and does not add a sixth Phase 13 resource. Access-list and disciplinary inputs remain explicit inputs to the Article 15 adapter. The access-list contract carries `access_list_position`, `league_id`, `group_id`, `draw_pot`, `group_formation_status`, and `source_artifact_id`; `uefa_nl_validate_access_list()` and `uefa_nl_validate_group_formation()` validate admitted seeded assignments, while absent admitted metadata returns `unresolved_access_list` with `NA_integer_` positions rather than an inferred position. If discipline or another Article 15 input is absent, the adapter returns `ordering_status = blocked`, identifies `missing_rule_input`, and the state/outcomes layer emits unresolved or suppressed rows without a rank.
2. **Projection before official downstream draws — resolved in favor of explicit legal projections.** Phase 15 emits legal QF/semi draw paths before official pairings as `projected` slots carrying `projection_run_id` and `draw_policy_id`; such rows have no `source_fixture_id` or `source_artifact_id`. Once UEFA facts are admitted through the separate capture, rows may be `official` or `completed` only with source lineage. The current scheduled snapshot therefore exposes topology and auditable projected/unresolved state rather than inventing official pairings.
3. **Calibrated 1X2 and score-grid reconciliation — resolved by one named policy and empirical test.** `calibrated_1x2_conditional_score_grid` samples W/D/L from Phase 14 `p_home`, `p_draw`, and `p_away`, then samples a scoreline from the matching normalized score-grid category; it never treats the raw grid as the reported outcome simplex. A seeded test with seed `15017L`, 100000 draws, target `c(home = 0.45, draw = 0.25, away = 0.30)`, and maximum absolute empirical frequency error `0.01` is required before production acceptance.
4. **C/D EURO play-off dependency — resolved as an explicit unresolved external-state output.** Article 16 cancellation is applied only when an explicit `euro_playoff_eligibility` input says a participant qualifies; a complete supplied table with no qualifying participant permits the contested branch. The current EURO `pre_draw` registry state supplies no eligibility fact, so Phase 15 must emit `unresolved_external_eligibility`/`euro_playoff_eligibility_missing` and must not infer eligibility, cancellation, or contestability from absent EURO rows.
5. **Revision closeout contracts — resolved for implementation.** `uefa_nl_rank_final_overall()` owns Article 19.04's ten final-overall stage bands and Article 19.05's champion/runner-up/third/fourth overwrite. When explicit eligibility cancels C/D, C interim ranks 46/47 and D interim ranks 50/51 are retained with cancellation fields and no fabricated play-off probabilities. The exact ninth sibling artifact is `outputs/competition/uefa_nations_league_2026_27/outcomes/fixture_forecast_form.csv`, which passes through calibrated forecasts, both form scopes, and parent hashes. Production accepts only the registered durable outcomes root; temporary tests use only the explicit `phase15_test_output_root()` validator/registration path.

## Sources

### Primary (HIGH confidence)

- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-12-Competition-stages-Online] Article 12 competition stages; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-13-Group-formation-league-phase-Online] Article 13 league allocation and group formation; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-14-Match-system-league-phase-Online] Article 14 league match system; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-15-Equality-of-points-league-phase-Online] Article 15 tie-breakers; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-16-Match-system-play-offs-Online] Article 16 play-offs and C/D cancellation; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-17-Match-system-League-A-knockout-stage-Online] Article 17 League A knockout stage; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-18-Extra-time-and-penalty-shoot-outs-Online] Article 18 tie resolution; checked 2026-08-22.
- [CITED: https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/Article-19-Individual-league-interim-overall-and-final-overall-rankings-Online] Article 19 rankings and transitions; checked 2026-08-22.
- [CITED: https://www.uefa.com/uefanationsleague/news/0298-1d6ef1acfaef-b54fcf1da859-1000--2026-27-uefa-nations-league-all-you-need-to-know/] UEFA published groups and dates; checked 2026-08-22.
- [CITED: https://www.uefa.com/uefanationsleague/news/02a2-1fea18abbcbc-456e846509e7-1000--2026-27-uefa-nations-league-all-the-league-phase-fixtures/] UEFA league-phase fixture list; checked 2026-08-22.
- [CITED: https://editorial.uefa.com/resources/02a2-1fe81f47532b-33ea7fae9cab-1000/20260123_circular_2026_03_en_enclosure_1_unl_2627_league_phase_draw_procedure_en_1.pdf] UEFA league-phase draw procedure and access-list seeding; checked 2026-08-22.

### Secondary (MEDIUM confidence)

- [CITED: https://devguide.owasp.org/en/03-requirements/05-asvs/] OWASP ASVS category mapping used for the security-domain checklist; checked 2026-08-22.
- [VERIFIED: codebase grep] Phase 14 summaries, accepted bundle files, registries, source contracts, state/forecast/form modules, and focused tests listed throughout this brief.

### Tertiary (LOW confidence)

- [ASSUMED] The exact public presentation of projected versus unresolved rows may evolve in a later dashboard phase; Phase 15 treats the status, lineage, score, and manifest fields above as the implementation contract.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - [VERIFIED: local environment] Runtime and required packages are installed; [VERIFIED: codebase grep] Phase 14 modules are the locked dependency.
- Architecture: HIGH - [VERIFIED: codebase grep] Existing seams and exact artifact inventory are directly inspected; [RESOLVED: planning] the sibling outcomes bundle and separate stage-capture boundary are locked for Phase 15.
- Rules: HIGH - [CITED: UEFA Articles 12-19] Current official 2026/27 regulations checked on 2026-08-22.
- Pitfalls: HIGH - [CITED: UEFA rules] and [VERIFIED: codebase grep] existing generic simulator limitations and source gaps are concrete.
- Simulation calibration: MEDIUM - [VERIFIED: codebase grep] Phase 14 exposes separate calibrated 1X2 and score-grid fields; [RESOLVED: planning] Phase 15 uses the named conditional-score policy and seeded tolerance test.

**Research date:** 2026-08-22  
**Valid until:** 2026-08-29 for fast-moving official source availability; rules should be rechecked if UEFA publishes a regulation revision or later-stage draw.
