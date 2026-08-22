# Phase 15: Nations League Rules and Outcomes - Pattern Map

**Mapped:** 2026-08-22  
**Files analyzed:** 6 planned source/test files, plus Phase 14/13 analogs  
**Analogs found:** 5 strong role matches / 6 planned files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| R/competition/uefa_nations_league_rules.R | utility/rules adapter | transform, request-response | R/competition/standings.R | role + seam match |
| R/competition/uefa_nations_league_simulation.R | service/simulator | batch, event-driven state transitions | R/forecast/tournament.R | partial only; domain mismatch |
| R/competition/uefa_nations_league_outcomes.R | service/payload + manifest | transform, file I/O | R/competition/state_bundle.R | role + provenance match |
| R/competition/uefa_nations_league_adapter.R | adapter (conditional extension) | request-response, file I/O | existing file itself | exact local source boundary |
| scripts/build_nations_league_outcomes.R | production entrypoint/config | batch, file I/O | scripts/build_competition_state.R | exact CLI/replay match |
| tests/testthat/test_phase15_nations_league.R | integration/unit test | batch, request-response | test_phase14_state_bundle.R and test_phase14_standings.R | exact test style |

The Phase 15 output is a sibling bundle under
outputs/competition/uefa_nations_league_2026_27/outcomes/. Keep state/ and its
exact eleven-artifact phase14_state_bundle_expected_inventory() unchanged. The
outcome bundle may reference Phase 14 hashes and files, but must not add outcome
files to the Phase 14 inventory or mutate Phase 14 forecast rows.

## Pattern Assignments

### R/competition/uefa_nations_league_rules.R (utility/rules adapter, transform)

**Analog:** R/competition/standings.R

Use a pure, deterministic adapter accepted by phase14_compute_standings().
The Phase 14 reducer owns universal arithmetic; this module owns Article 15/19
ordering, access-list/disciplinary inputs, group-size-aware cross-group ranking,
interim rank bands, transition selectors, and stage topology.

**Bootstrap pattern** (R/competition/state_bundle.R:7-22): source a repository
dependency only when its public symbol is absent, and resolve the project root
before sourcing. Prefer base R and existing digest helpers; use
requireNamespace() for optional package checks.

**Reducer seam** (R/competition/standings.R:324-487):

~~~r
phase14_compute_standings(
  matches = canonical_results,
  edition_id = edition_id,
  group_id = group_id,
  state_cutoff_utc = state_cutoff_utc,
  source_bundle_id = source_bundle_id,
  ruleset_adapter = uefa_nl_rank_group
)
~~~

The adapter must return a complete team set with contiguous unique ranks. The
accepted return forms and validation are in phase14_standings_adapter_ranks()
(standings.R:273-318). Preserve computed_rank, ordering_status, and
ruleset_adapter_id; do not replace the universal reducer with a second W/D/L
calculator.

**Validation and fail-closed pattern** (standings.R:680-770): validate exact
snapshot keys, arithmetic, contiguous ranks, supported ordering statuses, and
hashes. Missing Article 15 inputs must produce an explicit blocked/unresolved
ordering result with missing_rule_input/suppression metadata, never a random
fallback.

**Rules-specific implementation guidance:**

- Implement recursive tied-subset reapplication for ordered head-to-head criteria,
  then overall goal difference/goals, away goals, wins, away wins, disciplinary
  points, and access-list position.
- Compare individual leagues using the team's own group position. Exclude the
  fourth-place opponent only for positions 1-3 and only when that opponent
  exists. Do not assume League D has four teams or that rank 55 is populated.
- Represent topology and stage rules as canonical data: League A-D groups,
  QF/semi/third-place/final, A/B, B/C, and C/D play-offs; include leg count,
  seed/different-group policy, home-order policy, tie-break policy, and
  cancellation condition.
- Hash canonicalized ruleset serialization with digest::digest(..., algo =
  "sha256"); reverse input order must not change the hash.

**No direct analog:** official Nations League ranking and stage topology do not
exist elsewhere. Use 15-RESEARCH.md for Article 15/19 rules, but copy the
reducer contract and validator behavior above.

---

### R/competition/uefa_nations_league_simulation.R (service/simulator, batch)

**Analog:** R/forecast/tournament.R, with R/competition/forecast_layer.R as the
authoritative forecast input pattern.

**Legacy pattern to borrow only:** tournament.R:90-126 validates explicit
fixtures, accepts a seed, precomputes fixture forecasts, and returns structured
stage results. tournament.R:157-281 shows the iteration loop and aggregation
shape. Do not copy its fixed fixture-list traversal, one-match knockout
shortcut, runif() tie-break fallback (tournament.R:221-227), or direct model
calls. Those assumptions are structurally wrong for Nations League.

**Immutable forecast handoff** (R/competition/forecast_layer.R:1303-1569):

~~~r
forecast <- phase14_build_fixture_forecasts(
  canonical_matches = fixture_rows,
  resolved_release = resolved_release,
  edition_registry = edition_registry,
  edition_lifecycle_state = lifecycle
)
~~~

Consume forecast$forecasts, forecast$fixture_status, and the matching
forecast$score_distributions already produced by Phase 14. Fixed completed
results are copied into each iteration; only eligible open fixtures are sampled.
Never rerun the model, use simulated standings as feature inputs, or mutate the
forecast rows.

**Calibrated sampling rule** (forecast_layer.R:1469-1509): Phase 14 exposes
primary_probability_view = "calibrated_1x2" and calibrated p_home, p_draw, and
p_away. The simulator must sample the calibrated simplex. If scorelines are
needed, use a documented conditional scoreline distribution or tested
reweighting whose W/D/L sums equal those calibrated probabilities. Do not sample
the raw G=40 grid directly while reporting calibrated outcomes.

**State-machine core:**

- Resolve each iteration's group matches, call the Nations League adapter for
  standings, then compute individual-league and interim rankings.
- Select direct promotion/relegation and applicable A/B, B/C, C/D ties from
  rank bands, preserving unresolved C/D EURO eligibility as explicit state.
- Sample legal QF and semi-final draws with persisted policy IDs/hashes. Keep
  projected slots distinct from official source fixtures.
- Resolve two-leg ties by aggregate score, with extra time/penalties only at the
  specified tie boundary. Resolve semi/final and third-place single-leg
  outcomes with their distinct extra-time/penalty policies.
- Aggregate per-team probabilities for projected standings, QF, semi, final,
  champion, direct transitions, and play-off eligibility/win/loss. Include
  simulation count and seed in every result row.

**Determinism pattern:** seed once at the script boundary, derive stable
iteration/fixture draws from that seeded stream, canonicalize all input rows
before simulation, and sort all output rows by stable IDs before hashing.

---

### R/competition/uefa_nations_league_outcomes.R (service/payload + manifest, transform/file I/O)

**Analog:** R/competition/state_bundle.R and its manifest helpers.

**Keep the Phase 14 inventory intact** (state_bundle.R:590-603):

~~~r
phase14_state_bundle_expected_inventory <- function() {
  c(
    "state/canonical_matches.csv", "state/standings.csv",
    "state/competition_form.csv", "state/all_international_form.csv",
    "state/model_form.csv", "state/forecast_status.csv", "state/forecasts.csv",
    "state/forecast_top10.csv", "audit/standings_reconciliation.csv",
    "audit/state_manifest.csv", "local/score_distributions.rds"
  )
}
~~~

Build a separate outcomes artifact map under outcomes/. Exact output names
should be locked in the plan, but the bundle should cover topology/stage slots,
projected standings/rankings, transitions/play-offs, team path probabilities,
fixture-level forecast/form pass-through, simulation metadata, and an outcomes
manifest. Official rows must carry source
artifact/fixture lineage; projected rows must carry projection_run_id and
draw_policy_id; unresolved/suppressed rows must carry the reason and must not
invent team IDs or official fixture IDs.

**Manifest construction** (state_bundle.R:1377-1482): copy the existing shape:
canonical artifact paths, row counts, content hashes, row hashes where useful,
parent paths/hashes, model/release IDs, model cutoff, feature cutoff, source
bundle IDs/hashes, warning/failure fields, validation status, generated time,
and a self hash with the self-hash field blanked before hashing. Use the same
canonical row ordering and digest hashing behavior.

**Parent graph:** outcomes depend on the Phase 14 state manifest, canonical
matches/results, forecast status/forecasts, source bundle manifest, ruleset
version/hash, and simulation seed/config. Keep parent hashes explicit so a
changed forecast or ruleset invalidates the outcomes bundle.

**Validator pattern** (state_bundle.R:1672-1765): accept either an in-memory
candidate or durable path, require exact inventory, reject unexpected files,
validate manifest self/content hashes, verify edition identity and lineage, and
fail closed on incomplete status. Add the same reverse-input/repeated-run hash
comparison for outcomes.

**Source/provenance analog:** R/competition/source_contracts.R:653-691 and
publication_manifests.R:307-405 require exact foreign keys, complete resource
classes, one fallback status, parser identity, canonical artifact hashes, and
self-hashed manifests. Reuse that vocabulary for source bundle, ruleset,
release, forecast, and projection lineage; do not create a loose CSV without
hashes.

---

### R/competition/uefa_nations_league_adapter.R (adapter, request-response/file I/O)

**Analog:** the existing file itself, especially :86-145, :148-255, and :286-328.

If Phase 15 admits later-stage source fields, extend this boundary only for
validated official fields. Keep existing behavior: validate the official JSON
array, competition/season, fixture/group/team identity, counts, duplicate IDs,
and status before adapting it; then return the existing five resource classes
plus a deliberate separately hashed stage capture if required. Do not silently
add an unknown sixth Phase 13 resource class.

~~~r
phase14_uefa_nl_validate_response(payload, expected_fixture_count = 156L,
  expected_group_count = 14L, expected_team_count = 54L)
phase14_uefa_nl_adapt_response(payload)
~~~

The adapter currently emits empty standings and score-free scheduled results when
the endpoint has no completed results (:222-255). Preserve that truthful
scheduled state. Use jsonlite only at the adapter boundary (:258-266) and retain
exact raw bytes/source URL/retrieval metadata from :286-328.

---

### scripts/build_nations_league_outcomes.R (production entrypoint, batch/file I/O)

**Analog:** scripts/build_competition_state.R.

**Bootstrap and seed** (build_competition_state.R:1-70): set a fixed seed before
sourcing dependencies, resolve the script path/project root, and source
dependencies into a private script environment with sys.source(). The new
entrypoint should load the Phase 14 state builder/validator, rules, simulation,
and outcomes modules without relying on the caller's working directory.

**Argument contract** (:74-109): use explicit --edition-id, --dry-run,
--replay-check, and --help parsing; reject unknown options and missing values.
The production path is Nations League-only and must reject foreign edition inputs.

**Input loader** (:206-255): read accepted/registry CSVs with stringsAsFactors =
FALSE, bind edition IDs explicitly, and load the Phase 14 candidate inputs once.
Read the durable Phase 14 sibling bundle as an input, not as a second
model-building path.

**Replay contract** (:139-180 and :294-320): build normal, reversed-input, and
repeated candidates; compare edition IDs, manifests, all artifact hashes, fixture
inventories, and outcomes hashes; return durable_mutation = FALSE for replay
checks. Keep publication out of this entrypoint unless a later phase explicitly
owns the atomic public promotion boundary.

Recommended command shape:

~~~text
Rscript --vanilla scripts/build_nations_league_outcomes.R --edition-id uefa_nations_league_2026_27 --replay-check
~~~

---

### tests/testthat/test_phase15_nations_league.R (unit/integration, batch)

**Analogs:** test_phase14_standings.R, test_phase14_state_bundle.R,
test_phase14_forecast_layer.R, and test_uefa_nations_league_production.R.

**Load pattern:** source only APIs under test into the global test environment, as
in test_uefa_nations_league_production.R:8-21; use normalizePath() from the
repository root and utils::read.csv(..., na.strings = "") for durable tables.

**Test blocks to add:**

- topology: A1-A4, B1-B4, C1-C4, D1-D2; 14 groups, 156 fixtures, 54 current
  teams; stage definitions and no invented official downstream IDs;
- ranking: all Article 15 criteria, recursive tied subsets, access-list and
  disciplinary ordering, Article 19 fourth-place exclusion, and 3-team League D
  handling;
- stage resolution: lower-league first-leg home, aggregate score, extra time,
  penalties, single-leg third-place behavior, and C/D cancellation;
- simulation: fixed completed results, calibrated 1X2 sampling, legal draw
  constraints, probability mass conservation, and non-zero synthetic paths;
- provenance/replay: ruleset/source/model/forecast/form hashes, seed/count,
  official/projected/unresolved/suppressed status, reversed/repeated equality,
  and Phase 14 forecast rows/hashes unchanged after simulation;
- production smoke: current scheduled snapshot remains truthful, with no
  completed results or standings fabricated.

**Concrete test idioms:** use expect_silent() for validators, expect_error() for
foreign IDs/missing rule inputs/invalid stage fixtures, expect_identical() for
hashes and replay outputs, and reset row names before table equality. The Phase
14 replay assertions at test_phase14_state_bundle.R:650-704 are the closest
template for normal/reversed/repeated durable-byte checks.

**Commands:**

~~~text
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'
Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'
~~~

## Shared Patterns

### Phase 14 Forecast Handoff

**Sources:** R/competition/forecast_layer.R:1303-1569,
R/competition/state_bundle.R:395-435

Apply to the simulator and outcomes builder. Use Phase 14's available forecast
rows as immutable inputs; preserve calibrated probabilities, G=40 metadata,
release/model/calibrator IDs, model and feature cutoffs, form/history hashes,
and source bundle lineage. Forecast generation happens before simulation.

### Exact Identity and No Silent Drops

**Sources:** forecast_layer.R:1544-1555, state_bundle.R:1491-1500,
match_state.R:1457-1498

Every source fixture must map one-to-one to canonical/status rows. Every
available fixture must map one-to-one to forecast/grid/top-10 rows. Every
outcome row must retain stable team/fixture/stage identity, with foreign-edition
rows rejected rather than filtered silently.

### Hashes, Lineage, and Fail-Closed Status

**Sources:** state_bundle.R:1403-1482, source_contracts.R:653-691,
publication_manifests.R:307-405

Canonicalize before hashing, include parent hashes, blank self-hash fields before
self hashing, and validate durable read-back. Use explicit official, projected,
unresolved, suppressed, and completed statuses. Missing access list, disciplinary,
EURO eligibility, or official pairing inputs must block or suppress the affected
result rather than randomize it.

### Deterministic Production and Tests

**Sources:** scripts/build_competition_state.R:1-6, :139-180, :294-320;
tests/testthat/test_phase13_publication_manifests.R:200-271, :311-354

Use fixed seeds, stable row ordering, repeated/reversed replay, exact byte/hash
comparisons, and registered output roots. Production accepts only the durable
root returned by `phase15_nl_registered_outcomes_root(project_root)`; tests may
use a child of `tempdir()` only after `phase15_test_output_root()` validates and
registers that child. Arbitrary temporary paths are rejected. Do not alter
durable Phase 14 output while running Phase 15 tests or replay checks.

## Revision Planning Decisions

These decisions close the Phase 15 revision blockers and are implementation
contracts for the plans:

- Article 13 access-list inputs are first-class validated data. Use
  `uefa_nl_validate_access_list()` and `uefa_nl_validate_group_formation()`
  with `access_list_position`, `league_id`, `group_id`, `draw_pot`,
  `group_formation_status`, and `source_artifact_id`. When the accepted source
  lacks admitted metadata, preserve group identity but emit
  `unresolved_access_list` and `NA_integer_` positions; never infer positions.
- Article 19 final ranking is a separate deterministic function,
  `uefa_nl_rank_final_overall()`, with `final_overall_rank` and
  `ranking_stage`. Its ten stage bands follow Article 19.04, and Article 19.05
  overwrites ranks 1-4 after the final and third-place match.
- The outcomes bundle has exactly nine sibling artifacts. The ninth is
  `outputs/competition/uefa_nations_league_2026_27/outcomes/fixture_forecast_form.csv`,
  which passes through calibrated forecast/model/release/cutoff fields and both
  form scopes to the shared payload boundary without fabricating unavailable
  history.
- C/D cancellation retains C interim ranks 46/47 in C and D interim ranks 50/51
  in D for the next edition. The row carries `cd_playoff_status`,
  `retained_next_edition_league`, `retained_next_edition_rank`, and
  `cancellation_reason`; canceled play-off probabilities are `NA_real_`.
- Phase 14's exact eleven-artifact inventory and Phase 13's exact five-resource
  contract remain unchanged. Official, projected, unresolved, completed, and
  suppressed statuses remain distinct, and no official ID is invented.
- Plan 15-05 owns the atomic generated nine-file bundle, including its nine
  output paths. Plan 15-06 reads and verifies those paths but does not write
  them. Production-root validation and the explicit test-root helper are
  asserted in both CLI and acceptance tests.

## No Analog Found

| File/Capability | Reason | Planner Direction |
|---|---|---|
| R/competition/uefa_nations_league_simulation.R stage graph | No existing simulator models Nations League transitions, two-leg ties, legal draws, or C/D cancellation | Use research Articles 15-19 plus the Phase 14 forecast handoff; borrow only generic iteration/test shape from R/forecast/tournament.R |
| R/competition/uefa_nations_league_outcomes.R sibling bundle | Phase 14 has a state bundle but no derived outcomes sibling | Copy state-bundle manifest/validator patterns and keep the new output boundary independent |
| Later-stage official source fields | Current five-resource source contract has no access-list, cards, pairings, or downstream results | Add a deliberate source-admission/stage capture contract or emit unresolved; never silently expand the resource enum |

## Metadata

**Analog search scope:** R/competition, R/forecast, scripts, tests/testthat,
Phase 13 publication/source artifacts, and all Phase 14 plan/summary artifacts.

**Strong analogs scanned:** standings.R, state_bundle.R, forecast_layer.R,
uefa_nations_league_adapter.R, build_competition_state.R,
test_phase14_state_bundle.R, test_phase14_standings.R,
test_phase14_forecast_layer.R, test_uefa_nations_league_production.R,
publication_manifests.R, and source_contracts.R.

**Pattern extraction date:** 2026-08-22
