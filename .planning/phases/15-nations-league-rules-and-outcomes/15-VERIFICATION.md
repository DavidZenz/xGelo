---
phase: 15-nations-league-rules-and-outcomes
verified: 2026-08-22T15:24:24Z
status: passed
score: 38/38 must-haves verified
behavior_unverified: 0
overrides_applied: 0
prohibitions_verified: 16
prohibitions_flagged: 0
re_verification:
  previous_status: gaps_found
  previous_score: 37/38
  gaps_closed:
    - "All 16 Phase 15 prohibition entries are structured with status=verified and verification=test, and each is covered by the independently passing bounded tests."
    - "Unresolved and suppressed team-path rows now suppress all ten path-probability fields, with a regression covering unresolved, suppressed, and projected aggregation."
  gaps_remaining: []
  regressions: []
gaps: []
---

# Phase 15: Nations League Rules and Outcomes Verification Report

**Phase Goal:** Users can inspect the full 2026/27 Nations League competition state and projections under the official edition rules.
**Verified:** 2026-08-22T15:24:24Z
**Status:** passed
**Re-verification:** Yes, rerun after the unresolved-path suppression fix, exact sibling allowlist commit `02bcacb`, and plan prohibition metadata normalization

## Verification Basis

All seven Phase 15 PLAN files and all seven SUMMARY files were read, together with `15-REVIEW.md`, `15-REVIEW-FIX.md`, `15-VALIDATION.md`, `15-SECURITY.md`, `ROADMAP.md`, and `REQUIREMENTS.md`. The result below is based on the merged R source, CLI, focused tests, accepted source snapshot, stage-capture boundary, and durable output files, not on SUMMARY claims alone. The cross-phase inventory changes in `ad4e24c` and `02bcacb` were rechecked in source, output, and the Phase 14 probe.

The four ROADMAP success criteria are included in the 38 deduplicated PLAN truths below. No verification override was present or needed. The 16 current prohibition entries are structured test-tier entries (`statement`, `status: verified`, `verification`) and were checked against the listed passing tests.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The 2026/27 output represents Leagues A-D, published groups, league fixtures, current results, and downstream knockout/play-off stages under the official source boundary. | VERIFIED | The accepted source has 14 groups (A/B/C: 4 each; D: 2), 156 fixtures, 54 stable teams, and 156 scheduled result rows with no goals. The output topology contains 14 groups plus all eight league/downstream stage definitions. The separately registered stage capture is `empty` and `valid_empty`, so no completed or official downstream rows are fabricated. `R/competition/uefa_nations_league_rules.R:116`, `R/competition/uefa_nations_league_rules.R:302`, `tests/testthat/test_phase15_nations_league.R:2342`, `outputs/competition/uefa_nations_league_2026_27/outcomes/competition_topology.csv` |
| 2 | Tables and overall rankings implement the official cross-group, fourth-place, League D cardinality, Article 15, and Article 19 rules. | VERIFIED | The immutable ruleset encodes recursive Article 15 ordering, position-aware fourth-place exclusion, retained three-team League D results, rank bands, interim/final ranking stages, and final/third-place overwrite. Synthetic tests cover the complete and blocked branches; the current scheduled source correctly emits unresolved ranks rather than fake contiguous positions. `R/competition/uefa_nations_league_rules.R:142`, `R/competition/uefa_nations_league_rules.R:1178`, `R/competition/uefa_nations_league_rules.R:1359`, `R/competition/uefa_nations_league_rules.R:1796`, `tests/testthat/test_phase15_nations_league.R:1381`, `tests/testthat/test_phase15_nations_league.R:1734` |
| 3 | Open fixtures expose calibrated forecasts together with both competition-specific and all-international form views from the shared Phase 14 engine. | VERIFIED | Durable `fixture_forecast_form.csv` has 156 rows, all `forecast_status=available`, finite calibrated 1X2 probabilities and expected goals, and explicit `unavailable` / `no_eligible_form_history` values for both form scopes with Phase 14 parent hashes. `R/competition/uefa_nations_league_outcomes.R:1068`, `tests/testthat/test_phase15_nations_league.R:2568`, `outputs/competition/uefa_nations_league_2026_27/outcomes/fixture_forecast_form.csv` |
| 4 | Projected paths and transitions are available when rule inputs are available, while the current pre-results snapshot reports applicable absence as unresolved rather than emitting invented probabilities. | VERIFIED | The synthetic acceptance path produces non-zero legal paths and transitions, while the current durable output has 54 unresolved team-path rows with all ten path-probability fields missing. A direct read-back found zero unresolved/suppressed rows with any determinate path probability. `outputs/competition/uefa_nations_league_2026_27/outcomes/team_path_probabilities.csv`, `tests/testthat/test_phase15_nations_league.R:2684`, `R/competition/uefa_nations_league_simulation.R:1908` |

**Score:** 38/38 positive truths verified (0 present-but-behavior-unverified). Sixteen structured test-tier prohibition entries are separately verified.

### PLAN Must-Have Truths

| ID | Observable truth | Status | Evidence |
| --- | --- | --- | --- |
| 15-00.1 | Focused harness exists before production contracts and covers topology, rankings, stages, sampling, provenance, and replay. | VERIFIED | `tests/testthat/test_phase15_nations_league.R:1`; current focused run: 602 passed. |
| 15-00.2 | Three-team/four-team groups, admitted/unresolved access states, two-leg/single-leg stages, and completed capture fields are represented. | VERIFIED | Fixture builders and completed capture helpers at `tests/testthat/test_phase15_nations_league.R:119`, `tests/testthat/test_phase15_nations_league.R:724`, `tests/testthat/test_phase15_nations_league.R:2466`. |
| 15-00.3 | Repository-root harness loading reports exact missing APIs rather than silently skipping. | VERIFIED | `phase15_test_require_api` and root source loading at `tests/testthat/test_phase15_nations_league.R:3` and `tests/testthat/test_phase15_nations_league.R:772`. |
| 15-00.4 | Temporary outcomes roots are available only through the registered test helper and production remains durable-root-bound. | VERIFIED | `phase15_test_output_root` at `tests/testthat/test_phase15_nations_league.R:125`; production root validation at `R/competition/uefa_nations_league_outcomes.R:1421`; acceptance rejects an unregistered temp root at `tests/testthat/test_phase15_nations_league.R:2657`. |
| 15-01.1 | Canonical order-independent Articles 12-19 rules cover 14 groups, League A knockout, A/B, B/C, C/D, and downstream match policies. | VERIFIED | Ruleset and stage policy are explicit at `R/competition/uefa_nations_league_rules.R:116` and `R/competition/uefa_nations_league_rules.R:180`; reversed-input and topology tests pass. |
| 15-01.2 | Accepted snapshot is four A, four B, four C, two D groups, 156 fixtures, 54 teams, with three-team D groups allowed. | VERIFIED | Independent output check: 14 group records, 156 fixture rows, 54 unique teams; durable topology records D groups with `team_count=3`. `R/competition/uefa_nations_league_rules.R:642`, `tests/testthat/test_phase15_nations_league.R:2540`. |
| 15-01.3 | Article 13 admitted formation validates, while current missing access metadata is `unresolved_access_list` with no invented positions. | VERIFIED | `R/competition/uefa_nations_league_rules.R:347`, `R/competition/uefa_nations_league_rules.R:458`, `tests/testthat/test_phase15_nations_league.R:1016`, `tests/testthat/test_phase15_nations_league.R:2368`. |
| 15-01.4 | Official, projected, unresolved, and suppressed stage states have distinct schemas/provenance and omission cannot make a row official. | VERIFIED | Stage capture validator and output validator enforce status-specific fields at `R/competition/uefa_nations_league_adapter.R:707` and `R/competition/uefa_nations_league_outcomes.R:1302`; the current `stage_slots.csv` has projected rows without official IDs. |
| 15-01.5 | Phase 14's 11-artifact inventory and Phase 13's five-resource contract remain unchanged. | VERIFIED | The live root has exactly 8 state, 2 audit, and 1 local Phase 14 files, plus only the exact nine registered `outcomes/` sibling paths. The Phase 14 validator recursively rejects direct and nested unregistered outcomes descendants after `ad4e24c`/`02bcacb`; CLI checks the five resource names at `scripts/build_nations_league_outcomes.R:189`. |
| 15-02.1 | Group standings retain Phase 14 universal arithmetic behind a Nations League adapter. | VERIFIED | `uefa_nl_make_standings_adapter` and the universal standings handoff are implemented at `R/competition/uefa_nations_league_rules.R:1271` and `R/competition/uefa_nations_league_rules.R:1308`; adapter tests pass. |
| 15-02.2 | Article 15 recursively reapplies tied-subset criteria, then applies all remaining criteria; missing inputs block without fake ranks. | VERIFIED | Recursive ordering and blocked preflight are at `R/competition/uefa_nations_league_rules.R:1193` and `R/competition/uefa_nations_league_rules.R:1310`; tests cover both at `tests/testthat/test_phase15_nations_league.R:1381` and `tests/testthat/test_phase15_nations_league.R:1434`. |
| 15-02.3 | Article 19 individual/interim ranking is cardinality-aware and retains all three-team League D results. | VERIFIED | Cross-group configuration at `R/competition/uefa_nations_league_rules.R:142`; test coverage at `tests/testthat/test_phase15_nations_league.R:1538`. |
| 15-02.4 | Article 19 final ranking is stage-aware, with pre-final placement and final/third-place overwrite. | VERIFIED | Final ranking implementation at `R/competition/uefa_nations_league_rules.R:1796`; tests cover all bands and overwrite at `tests/testthat/test_phase15_nations_league.R:1734` and `tests/testthat/test_phase15_nations_league.R:1767`. |
| 15-02.5 | Direct and A/B, B/C, conditional C/D selectors use exact bands and explicit missing-eligibility state. | VERIFIED | Transition bands are encoded at `R/competition/uefa_nations_league_rules.R:163`; selector implementation at `R/competition/uefa_nations_league_rules.R:2089`; tests cover direct/play-off rows and unresolved eligibility at `tests/testthat/test_phase15_nations_league.R:1575`. |
| 15-02.6 | Supplied C/D cancellation retains C46/C47 and D50/D51 with explicit cancellation fields and no play-off probabilities. | VERIFIED | Cancellation implementation at `R/competition/uefa_nations_league_rules.R:1992`; exact retention test at `tests/testthat/test_phase15_nations_league.R:1808` and production acceptance at `tests/testthat/test_phase15_nations_league.R:2421`. |
| 15-03.1 | Simulation copies cutoff-qualified results, samples eligible open fixtures, and does not refit or mutate Phase 14 artifacts. | VERIFIED | Input normalization and canonical hashes precede simulation at `R/competition/uefa_nations_league_simulation.R:2010`; production acceptance snapshots and compares Phase 14 trees at `tests/testthat/test_phase15_nations_league.R:2515`. |
| 15-03.2 | Calibrated 1X2 is sampled first and the score grid is conditionally reweighted to the sampled class. | VERIFIED | `uefa_nl_sample_calibrated_outcome` and `uefa_nl_condition_score_distribution` at `R/competition/uefa_nations_league_simulation.R:184`; seeded empirical and conditional-grid tests pass. |
| 15-03.3 | Two-leg ties resolve only after leg two with the required tie-break boundary; single-leg and third-place policies are distinct. | VERIFIED | Validators/resolvers at `R/competition/uefa_nations_league_simulation.R:299`, `R/competition/uefa_nations_league_simulation.R:352`, and `R/competition/uefa_nations_league_simulation.R:415`; Article 14-18 tests pass. |
| 15-03.4 | Article 17 host-association ordering is deterministic across Semi-final 1, final, and third place. | VERIFIED | Rules policy at `R/competition/uefa_nations_league_rules.R:251`; acceptance asserts all three Team A sources at `tests/testthat/test_phase15_nations_league.R:2450`. |
| 15-03.5 | League A paths, direct transitions, applicable play-offs, C/D states, mass conservation, legal draws, and seeded replay are produced. | VERIFIED | Legal draw functions at `R/competition/uefa_nations_league_simulation.R:537` and `R/competition/uefa_nations_league_simulation.R:592`; synthetic production acceptance asserts non-zero paths and transitions at `tests/testthat/test_phase15_nations_league.R:2621`, while unresolved aggregate paths are suppressed by the status-aware aggregator. |
| 15-03.6 | Simulation preserves final rank/ranking stage lineage and C/D cancellation retention instead of play-off probabilities. | VERIFIED | Path aggregation preserves ranking fields at `R/competition/uefa_nations_league_simulation.R:1908`; C/D status mapping is at `R/competition/uefa_nations_league_simulation.R:1698`; dedicated tests pass. |
| 15-04.1 | Outcomes are a sibling exact nine-file bundle, including fixture pass-through, outside the Phase 14 inventory. | VERIFIED | Inventory declaration at `R/competition/uefa_nations_league_outcomes.R:19`; independent read-back reports `outcomes_exact_9=TRUE`, and the current directory contains exactly the nine expected CSVs while Phase 14 remains exactly 11 state files. |
| 15-04.2 | Each artifact carries appropriate lineage and the manifest validates content, row, self, parent hashes and rejects extras. | VERIFIED | Manifest validation at `R/competition/uefa_nations_league_outcomes.R:1346`; current manifest has 9 rows and valid hashes; focused acceptance mutates/rejects invalid artifacts. |
| 15-04.3 | Official rows retain source identity; projected rows carry projection/draw identity; unresolved/suppressed rows carry reasons without fabricated IDs. | VERIFIED | Status-specific validation at `R/competition/uefa_nations_league_outcomes.R:1302`; current stage slots have no source IDs and projected identity, while synthetic completed rows retain source IDs. |
| 15-04.4 | Candidate and durable writer share one contract and loader exposes fixture forecast/form without expanding Phase 14. | VERIFIED | Candidate/writer/loader at `R/competition/uefa_nations_league_outcomes.R:920`, `R/competition/uefa_nations_league_outcomes.R:1435`, and `R/competition/uefa_nations_league_outcomes.R:1473`; read-back tests pass. |
| 15-05.1 | CLI accepts only registered 2026/27, loads five source resources plus separate stage capture, and does not mutate/refit Phase 14. | VERIFIED | Edition/source guards at `scripts/build_nations_league_outcomes.R:136` and `scripts/build_nations_league_outcomes.R:189`; fresh-process acceptance verifies immutable Phase 14 inputs. |
| 15-05.2 | Dry-run validates in memory without durable write; write publishes exactly nine registered sibling artifacts. | VERIFIED | CLI modes and mutation reporting at `scripts/build_nations_league_outcomes.R:65` and `scripts/build_nations_league_outcomes.R:523`; dry-run reports `artifact_count=9`, `validation=TRUE`, `durable_mutation=FALSE`, and the writer/read-back contract passes. |
| 15-05.3 | Durable stage output preserves completed QF, semi, final, A/B, B/C, and C/D score/timestamp/source fields. | VERIFIED | Stage capture schema and score validation at `R/competition/uefa_nations_league_adapter.R:447` and `R/competition/uefa_nations_league_adapter.R:743`; completed six-stage round-trip fixture passes at `tests/testthat/test_phase15_nations_league.R:2466`. |
| 15-05.4 | Normal, reversed, and repeated replay compare bytes/hashes including stage-capture and completed-score lineage without durable mutation. | VERIFIED | Replay comparator at `scripts/build_nations_league_outcomes.R:369`; an independent CLI process returned `validation=TRUE`, `replay_verified=TRUE`, and `durable_mutation=FALSE`, while the focused acceptance checks capture hashes and durable-tree equality at `tests/testthat/test_phase15_nations_league.R:2505`. |
| 15-05.5 | Only the registered durable root is accepted; temporary children require the registered test helper. | VERIFIED | Root validator at `R/competition/uefa_nations_league_outcomes.R:1421`; acceptance rejects `tempdir()/phase15-unregistered` and accepts `phase15_test_output_root()` at `tests/testthat/test_phase15_nations_league.R:2657`. |
| 15-06.1 | Current production acceptance recognizes 14 groups, 156 fixtures, 54 teams, scheduled results, and no fabricated standings or official downstream pairings. | VERIFIED | Acceptance assertions at `tests/testthat/test_phase15_nations_league.R:2309` and `tests/testthat/test_phase15_nations_league.R:2338`; independent source read confirms A/B/C/D group counts 4/4/4/2, 156 scheduled rows, NA scores, empty standings, and empty stage capture. |
| 15-06.2 | Deterministic replay preserves exact artifact bytes/hashes and source/model/ruleset/forecast/cutoff/seed/stage lineage. | VERIFIED | Manifest and metadata checks at `tests/testthat/test_phase15_nations_league.R:2520` and `tests/testthat/test_phase15_nations_league.R:2557`; replay test passes. |
| 15-06.3 | Production has calibrated open-fixture forecasts and non-zero synthetic paths without Phase 14 mutation. | VERIFIED | Forecast and no-leakage assertions at `tests/testthat/test_phase15_nations_league.R:2568`; non-zero synthetic path assertions at `tests/testthat/test_phase15_nations_league.R:2637`; Phase 14 snapshot is unchanged. |
| 15-06.4 | Durable fixture pass-through contains calibrated forecasts, both form lineages, and parent state hashes. | VERIFIED | `fixture_forecast_form.csv` read-back assertions at `tests/testthat/test_phase15_nations_league.R:2568`; independent output has 156 rows and calibrated view. |
| 15-06.5 | Article 13, Article 19, and C/D states are explicit resolved/unresolved/completed/suppressed states with no invented positions, ranks, IDs, or probabilities. | VERIFIED | The updated status-aware path aggregator suppresses all ten probability fields for unresolved or suppressed rows, preserves projected means, and the new regression covers all three statuses. The durable read-back reports 54 unresolved rows and zero rows with any determinate path field. |
| 15-06.6 | C/D is unresolved or cancelled only with explicit eligibility input; absent EURO pre-draw data is not inferred. | VERIFIED | `tests/testthat/test_phase15_nations_league.R:2444` and `tests/testthat/test_phase15_nations_league.R:2612` require `unresolved_external_eligibility`, unresolved stage status, and NA play-off probabilities. |
| 15-06.7 | Production root and temporary replay-root rules are enforced. | VERIFIED | Same root checks at `tests/testthat/test_phase15_nations_league.R:2657` and `R/competition/uefa_nations_league_outcomes.R:1421`. |
| 15-06.8 | Official completed stage captures round-trip regulation, extra-time, shootout, final scores, and UTC completion timestamps. | VERIFIED | Schema/validation at `R/competition/uefa_nations_league_adapter.R:447` and completed capture assertions at `tests/testthat/test_phase15_nations_league.R:2466`. |

## Cross-Phase Boundary

The post-`ad4e24c`/`02bcacb` sibling contract is verified against both code and the live tree. Phase 14's exact state inventory is:

```text
state/canonical_matches.csv
state/standings.csv
state/competition_form.csv
state/all_international_form.csv
state/model_form.csv
state/forecast_status.csv
state/forecasts.csv
state/forecast_top10.csv
audit/standings_reconciliation.csv
audit/state_manifest.csv
local/score_distributions.rds
```

Phase 15's registered outcomes sibling is exactly:

```text
outcomes/competition_topology.csv
outcomes/stage_slots.csv
outcomes/projected_standings.csv
outcomes/projected_rankings.csv
outcomes/transition_outcomes.csv
outcomes/team_path_probabilities.csv
outcomes/fixture_forecast_form.csv
outcomes/simulation_metadata.csv
outcomes/outcomes_manifest.csv
```

The current root contains exactly 11 Phase 14 state files and exactly 9 outcomes files. `phase14_validate_competition_state_bundle()` checks recursive relative paths against the 11 state paths plus the nine registered sibling paths (`R/competition/state_bundle.R:1693-1699`); `phase15_nl_read_outcomes_bundle()` and the writer require the nine outcomes paths exactly (`R/competition/uefa_nations_league_outcomes.R:1435-1497`). The live Phase 14 probe passed 3 tests / 6 expectations, including rejection of both `outcomes/unregistered-extra.csv` and `outcomes/unregistered-nested/nested-extra.csv` (`tests/testthat/test_phase14_plan18_transaction_probe.R:206-232`).

## Truthful Current State

The current accepted snapshot is scheduled, not completed: `groups.csv` has 14 rows, `fixtures.csv` has 156 rows, `results.csv` has 156 `scheduled` rows with NA scores and `counts_for_standings=FALSE` / `counts_for_form=FALSE`, and the separate stage capture has zero rows with `capture_status=empty` and `validation_status=valid_empty`. The durable output therefore contains:

- 14 group topology rows plus eight downstream stage definitions, with League D groups at three teams.
- 156 calibrated fixture forecasts, all available, with explicit unavailable form scopes and no eligible-history window.
- Two projected League A final/third-place slot rows with projection and draw-policy IDs but no official fixture IDs.
- 54 unresolved projected standings, 216 unresolved projected-ranking rows, 54 team-path rows with `status=unresolved`, and 19 unresolved transition rows.
- Four unresolved C/D rows with `unresolved_external_eligibility` and NA play-off probabilities.

The source boundary, stage provenance, and synthetic branches are otherwise consistent. However, the durable team-path artifact is not fully fail-closed: it reports unresolved status while carrying determinate direct promotion/relegation probabilities for every team. This blocks the phase goal until those fields are suppressed or otherwise made explicitly unresolved and covered by a regression assertion.

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `R/competition/uefa_nations_league_rules.R` | Rules, topology, Article 13/15/19, transitions, C/D branches | VERIFIED | 2,187-line substantive module; sourced by tests and CLI. |
| `R/competition/uefa_nations_league_adapter.R` | Separate official downstream-stage capture boundary | VERIFIED | Capture schema, path safety, UTC/score/hash/registry validation, and loader are implemented and tested. |
| `R/competition/uefa_nations_league_simulation.R` | Calibrated seeded state-machine simulation | VERIFIED | Samplers, conditional score grid, Article 14-18 resolution, legal draws, paths, transitions, hashes. |
| `R/competition/uefa_nations_league_outcomes.R` | Exact sibling bundle candidate/manifest/loader/writer | VERIFIED | Exact inventory, status-aware provenance, self/row/content/parent hash validation, registered atomic writer. |
| `scripts/build_nations_league_outcomes.R` | Registered production CLI | VERIFIED | Fresh-process dry-run and replay checks pass; write path is wired to candidate, validator, and writer. |
| `scripts/build_uefa_nations_league_outcomes.R` | UEFA-prefixed compatibility entrypoint | VERIFIED | Thin delegate to the plan-owned CLI at line 13; file exists and parses. |
| `tests/testthat/test_phase15_nations_league.R` | Focused 602-expectation contract and acceptance suite | VERIFIED | 34 test blocks, 602 passes, zero fail/error/warn/skip in independent run. |
| `data/competition/accepted/uefa_nations_league_2026_27/{groups,fixtures,standings,results,status}.csv` | Five-resource Phase 13 source boundary | VERIFIED | Fourteen groups, 156 fixtures, empty standings, scheduled results, one status row. |
| `data/competition/accepted/uefa_nations_league_2026_27/stage_capture.csv` | Separate official/completed downstream capture | VERIFIED | Schema-valid empty capture; not part of the five-resource enum. |
| `data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv` | Capture content/raw/parent/self hash manifest | VERIFIED | One `empty` / `valid_empty` row with registered raw and normalized paths. |
| `data/competition/registries/stage_captures.csv` | Registered stage-capture lineage | VERIFIED | One row matches the companion manifest and row hash. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/competition_topology.csv` | Groups and stage topology | VERIFIED | 22 rows: 14 groups and eight stage definitions. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/fixture_forecast_form.csv` | Fixture forecast/form pass-through | VERIFIED | 156 rows, calibrated 1X2, parent state/form/model lineage. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/outcomes_manifest.csv` | Nine-file self-hashed manifest | VERIFIED | Nine rows, valid content/row/self/parent hashes. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/projected_rankings.csv` | Projected/ranking-stage output | VERIFIED | 216 rows, explicit unresolved ranking status for current missing rule inputs. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/projected_standings.csv` | Projected group standings | VERIFIED | 54 rows, explicit unresolved current state. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/simulation_metadata.csv` | Seed/model/source/rules/draw lineage | VERIFIED | One row with seed 15017, simulation count 1, source and state hashes, calibrated policy. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/stage_slots.csv` | Official/projected/unresolved stage slots | VERIFIED | Two projected final/third-place rows with no official lineage. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/team_path_probabilities.csv` | Team path and transition probabilities | VERIFIED | 54 rows exist and are linked; all current rows are unresolved and all ten path-probability fields are missing, while synthetic projected rows retain non-zero probabilities. |
| `outputs/competition/uefa_nations_league_2026_27/outcomes/transition_outcomes.csv` | Direct/play-off/C-D transitions | VERIFIED | 19 rows, explicit unresolved statuses and C/D eligibility reason. |
| `outputs/competition/uefa_nations_league_2026_27/state`, `audit`, `local` | Unchanged Phase 14 eleven-artifact inventory | VERIFIED | Eight state files, two audit files, and one local score-grid file; the separate outcomes sibling is limited to the nine paths listed above. |

The generic artifact query returned false negatives for plans whose `contains` values were comma-delimited as one literal pattern. Manual symbol, import/use, output, and behavioral checks above resolve those checker pattern mismatches; the implementation artifacts are substantive and wired. Plan 15-05's ten artifact checks passed directly.

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `R/competition/standings.R` | `R/competition/uefa_nations_league_rules.R` | `uefa_nl_make_standings_adapter` | WIRED | Phase 14 universal arithmetic receives the Nations League adapter; blocked ranks are cleared before handoff. |
| `R/competition/uefa_nations_league_adapter.R` | `data/competition/accepted/.../stage_capture_manifest.csv` | registered stage-capture path/loader | WIRED | Manifest, raw capture, normalized capture, registry, hashes, and UTC fields are all linked and replayed. |
| `R/competition/state_bundle.R` | `outputs/.../outcomes/` | exact sibling allowlist | WIRED | `ad4e24c`/`02bcacb` preserve exact 11 state paths while allowing only the exact nine registered outcomes paths; the probe rejects direct and nested extras. |
| `R/competition/uefa_nations_league_rules.R` | `R/competition/uefa_nations_league_simulation.R` | transition selectors, ruleset, stage policies | WIRED | Simulation consumes Article 19 selectors and immutable Article 14-18 policy definitions. |
| `R/competition/uefa_nations_league_simulation.R` | `R/competition/uefa_nations_league_outcomes.R` | simulation return tables to nine candidate artifacts | WIRED | Projected standings, rankings, transitions, paths, fixture form, stage slots, and metadata are mapped into validated artifacts. |
| `scripts/build_nations_league_outcomes.R` | `R/competition/uefa_nations_league_outcomes.R` | `phase15_nl_build_candidate`, `phase15_validate_nl_outcomes_bundle`, `phase15_write_nl_outcomes_bundle` | WIRED | Actual functions are at `scripts/build_nations_league_outcomes.R:319`, `R/competition/uefa_nations_league_outcomes.R:1389`, and `R/competition/uefa_nations_league_outcomes.R:1435`. The plan's combined pattern `phase15_build_validate_write_nl_outcomes` was a checker-only naming mismatch. |
| `outputs/.../outcomes/outcomes_manifest.csv` | all nine sibling artifacts | exact ordered inventory, row/content/parent/self hashes | WIRED | Loader rejects any missing, reordered, extra, foreign, or hash-inconsistent artifact. |
| `tests/testthat/test_phase15_nations_league.R` | CLI and durable output | fresh-process dry-run/replay plus read-back | WIRED | Acceptance checks exact nine keys, stage-capture hashes, replay equality, output root, and Phase 14 immutability. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| `competition_topology.csv` | groups, fixtures, teams, stages | accepted five-resource source plus immutable ruleset | Yes: 14 groups, 156 fixtures, 54 teams, eight stages | FLOWING |
| `fixture_forecast_form.csv` | forecast probabilities, expected goals, two form scopes | Phase 14 state forecast/status/form/score-grid artifacts | Yes: 156 finite calibrated forecasts and explicit form status/window values | FLOWING |
| `projected_standings.csv` / `projected_rankings.csv` | simulated rankings and rank-stage lineage | simulation state and Article 15/19 ranking adapters | Yes: 54/216 rows; current missing discipline/access evidence produces explicit blocked/unresolved values, not hardcoded empty tables | FLOWING, STATE-AWARE |
| `transition_outcomes.csv` / `team_path_probabilities.csv` | transition selections and path fields | Article 19 selectors, C/D eligibility input, simulation aggregation | Synthetic positive probabilities and current unresolved transition rows flow; unresolved/suppressed aggregate paths are explicitly suppressed | FLOWING, STATE-AWARE |
| `stage_slots.csv` | official/projected/unresolved stage participants | separate stage capture plus seeded draw/state machine | Yes: current projected slots; empty official capture remains empty and cannot supply source IDs | FLOWING, SOURCE-CONDITIONED |
| `outcomes_manifest.csv` | artifact and parent hashes | nine-artifact candidate and canonical writer | Yes: nine rows with validated content/row/self/parent hashes | FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| All merged Phase 15 R modules parse | `Rscript --vanilla -e 'parse(file=...)'` over rules, adapter, simulation, outcomes, CLI, compatibility CLI | `parsed 6 files` | PASS |
| Focused Phase 15 acceptance | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | Exit 0; `PASS 607`, fail 0, warn 0, skip 0 | PASS |
| Adjacent official-snapshot regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_nations_league_production.R", stop_on_failure=TRUE)'` | Exit 0; `PASS 58`, fail 0, warn 0, skip 0 | PASS |
| Durable inventory and source-conditioned output | bounded R read-back of outcomes and accepted source | `exact_inventory=TRUE count=9`; 156 forecast rows; all calibrated; current ranking/transition state unresolved | PASS |
| Dry-run and replay mutation behavior | fresh-process calls inside the focused acceptance | `artifact_count=9`, `validation=TRUE`, `durable_mutation=FALSE`, `replay_verified=TRUE` | PASS |
| Independent CLI replay | `Rscript --vanilla scripts/build_nations_league_outcomes.R --edition-id uefa_nations_league_2026_27 --simulations 1 --seed 15017 --replay-check` | Exit 0; `validation=TRUE`, `replay_verified=TRUE`, `durable_mutation=FALSE` | PASS |
| Phase 14 sibling boundary probe | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_plan18_transaction_probe.R", stop_on_failure=TRUE)'` | Exit 0; 3 test blocks, 6 expectations, 0 failures; direct and nested outcomes extras rejected | PASS |
| Phase 13 source contract regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R", stop_on_failure=TRUE)'` | Exit 0; `PASS 175`, fail 0, warn 0, skip 0 | PASS |
| Unresolved path suppression invariant | Read-only check of current `team_path_probabilities.csv` | Exit 0; `unresolved_or_suppressed_rows=54`, `rows_with_any_determinate_path_probability=0` | PASS |
| Full repository suite | Not run | Intentionally outside the bounded Phase 15 gate; no server or external service was required | SKIP, bounded-scope decision |

## Probe Execution

No conventional `scripts/*/tests/probe-*.sh` probe was found. The cross-phase Phase 14 probe is an R test file rather than a shell probe; it was run independently above and passed 3 tests / 6 expectations.

## Requirements Coverage

| Requirement | Source plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| COMP-02 | 15-00, 15-01, 15-02, 15-04, 15-05, 15-06 | Registry represents Leagues A-D, published groups, league fixtures, and downstream knockout/play-off stages. | SATISFIED | `ROADMAP.md:157`, `ROADMAP.md:160`; topology/source/stage-capture checks and exact durable bundle pass. |
| SIM-01 | 15-00, 15-03, 15-04, 15-05, 15-06 | Simulator reports standings, League A QF/title paths, direct promotion/relegation, and applicable play-offs. | SATISFIED | Synthetic legal paths and transitions remain non-zero, replay passes, and current unresolved transition inputs produce explicit unresolved rows with all team-path probabilities suppressed rather than invented. |

No Phase 15 requirement is orphaned. `REQUIREMENTS.md` maps exactly COMP-02 and SIM-01 to Phase 15; later Phase 16/17 requirements are intentionally pending and are not gaps in this phase.

## Prohibitions and Negative Checks

The normalized plans declare 16 prohibition objects. Each has the required `statement`, `status: verified`, and `verification` fields. The listed focused Phase 15, Phase 13, and Phase 14 probe tests passed independently, so all 16 negative checks are recorded as `VERIFIED (test)`. The separate unresolved path-probability gap remains a positive-output failure, not a prohibition metadata issue.

| Plan | Must-not statement | Automated evidence | Disposition |
| --- | --- | --- | --- |
| 15-01 | Never label a projected, unresolved, or suppressed stage slot as an official UEFA fixture. | Status-aware output validation and projected rows without source IDs at `R/competition/uefa_nations_league_outcomes.R:1302`; focused acceptance passes. | VERIFIED (test) |
| 15-01 | Never introduce an implicit sixth Phase 13 structured resource class for later-stage data. | Five-resource CLI allowlist at `scripts/build_nations_league_outcomes.R:189`; Phase 13 regression passes 175. | VERIFIED (test) |
| 15-01 | Never alter the Phase 14 eleven-artifact state inventory to carry outcomes. | Exact sibling inventory and Phase 14 immutability checks at `tests/testthat/test_phase15_nations_league.R:2515`; Phase 14 probe passes. | VERIFIED (test) |
| 15-02 | Never use random or team-name ordering as an Article 15/19 substitute when a required rule input is missing. | Fail-closed rank preflight at `R/competition/uefa_nations_league_rules.R:1310`; blocked rank tests pass. | VERIFIED (test) |
| 15-02 | Never remove fourth-place results from League D or from a fourth-placed team's own comparison. | Cardinality-aware rule configuration at `R/competition/uefa_nations_league_rules.R:142`; three-team D tests pass. | VERIFIED (test) |
| 15-02 | Never infer C/D play-off eligibility from an absent EURO qualifying row. | `unresolved_external_eligibility` and NA play-off probabilities are asserted at `tests/testthat/test_phase15_nations_league.R:2444` and `:2612`. | VERIFIED (test) |
| 15-03 | Never sample the uncalibrated score grid as if it were the calibrated 1X2 outcome distribution. | Calibrated sampler and conditional score-grid policy at `R/competition/uefa_nations_league_simulation.R:184`; empirical contract passes. | VERIFIED (test) |
| 15-03 | Never resolve a two-leg tie after one leg or apply single-leg extra-time policy to the third-place match. | Distinct validators/resolvers at `R/competition/uefa_nations_league_simulation.R:299`, `:352`, and `:415`; Article 14-18 tests pass. | VERIFIED (test) |
| 15-03 | Never feed simulated standings, later results, or projected stage outcomes back into Phase 14 forecast features. | Input hashes and before/after Phase 14 tree equality at `R/competition/uefa_nations_league_simulation.R:2023` and `tests/testthat/test_phase15_nations_league.R:2515`. | VERIFIED (test) |
| 15-04 | Never write an outcomes file into the Phase 14 state inventory or mutate Phase 14 forecast rows. | Exact 11/9 sibling boundary, manifest checks, and no-leakage acceptance pass. | VERIFIED (test) |
| 15-04 | Never accept a manifest that is self-consistent only because its parent source/model/rules hashes were omitted. | Manifest parent/content/self validation at `R/competition/uefa_nations_league_outcomes.R:1346`; durable read-back passes. | VERIFIED (test) |
| 15-04 | Never allow `--edition-id` to load EURO or another competition into the Nations League outcomes bundle. | Edition guard at `scripts/build_nations_league_outcomes.R:136`; foreign-edition test passes. | VERIFIED (test) |
| 15-05 | Never accept a foreign edition, arbitrary source/output root, or unregistered stage-capture path. | CLI edition, root, and stage-capture guards; registered-root acceptance and rejection tests pass. | VERIFIED (test) |
| 15-05 | Never add stage capture as a sixth Phase 13 resource or move outcomes into the Phase 14 eleven-artifact state inventory. | Five-resource source check and exact sibling boundary probe pass. | VERIFIED (test) |
| 15-05 | Never fit a model, recompute Phase 14 features, or mutate Phase 14 state while building or replaying outcomes. | Fresh-process no-leakage snapshots, hashes, and replay checks pass. | VERIFIED (test) |
| 15-05 | Never write during dry-run or replay-check, and never treat projected/unresolved rows as official completed results. | Independent replay returned `validation=TRUE`, `replay_verified=TRUE`, `durable_mutation=FALSE`; dry-run and status tests pass. | VERIFIED (test) |

## Review, Validation, and Security Gates

| Gate | Evidence | Result |
| --- | --- | --- |
| Clean re-review | `15-REVIEW.md:16` reports critical 0, warning 0, info 0, total 0, status clean; the review covers the two cross-phase files changed by `02bcacb`. | CONFIRMED |
| Review-fix closure | `15-REVIEW-FIX.md:18` reports 9 findings, 9 fixed, 0 skipped; its bounded acceptance at `15-REVIEW-FIX.md:85` reports 594 passed, 0 failed, 0 skipped, 0 warnings, `durable_mutation=FALSE`, `replay_verified=TRUE`. | CONFIRMED |
| Nyquist focused gate | `15-VALIDATION.md:41` reports 602 expectations, 0 failures/errors/warnings/skips; adjacent regression reports 58 at `15-VALIDATION.md:46`. | CONFIRMED |
| Nyquist caveat | `15-VALIDATION.md:7` remains `nyquist_compliant: false` because the focused run is about 72 seconds rather than the 30-second target, but `15-VALIDATION.md:35` sets a 120-second gate and `15-VALIDATION.md:44` confirms it remains within that gate. | WARNING, non-blocking |
| Security | `15-SECURITY.md:5` status secured, `threats_open: 0`, `threats_closed: 33`; evidence includes boundaries, fail-closed ranking/C-D logic, replay, exact nine-file validation, and both regression counts. | CONFIRMED 33/33 |
| Current independent rerun | Focused test independently returned 607 passes; adjacent production regression remained green at 58 passes; Phase 13 returned 175 and the Phase 14 boundary probe returned 3 tests / 6 expectations. | CONFIRMED |

The 594 assertion result is the earlier clean review-fix acceptance record. The later Nyquist closure raised the focused source to 602 assertions, and the current gap-closure regression raises the independently passing run to 607. These are consistent sequential gates, not conflicting results.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `R/competition/uefa_nations_league_adapter.R` | 66 | Variable named `placeholder` | INFO | This is a real validation guard that rejects UEFA placeholder teams before ID mapping; it is not a stub or user-visible placeholder output. |
| Phase 15 merged implementation/test/CLI files | n/a | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, empty implementation, or static empty rendered data | None found | No debt-marker blocker or hollow implementation found. |

## Human Verification Required

None. All remaining checks are mechanically observable and no visual, external-service, or human-only verification is required.

## Gaps Summary

No blockers remain. The current output keeps standings and transitions unresolved, suppresses all path probabilities until the missing ranking inputs are available, and preserves non-zero synthetic projected paths. All 16 structured test-tier prohibitions are verified.

---

_Verified: 2026-08-22T14:49:57Z_
_Verifier: the agent (gsd-verifier)_
