# Phase 16: EURO Qualifying Activation and Play-off Rules - Pattern Map

**Mapped:** 2026-08-23  
**Files analyzed:** 6 likely new/modified files  
**Analogs found:** 6 / 6 (role-match analogs; Phase 15 provides exact competition analogs)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/competition/uefa_euro_rules.R` | utility / rules adapter | transform | `R/competition/uefa_nations_league_rules.R` | exact role and contract style |
| `R/competition/uefa_euro_simulation.R` | service / simulator | batch transform | `R/competition/uefa_nations_league_simulation.R` | exact role and seeded simulation flow |
| `R/competition/uefa_euro_outcomes.R` | output contract / serializer | batch and file-I/O | `R/competition/uefa_nations_league_outcomes.R` | exact durable-artifact pattern |
| `scripts/build_euro_qualifying_outcomes.R` | CLI / orchestration | batch and file-I/O | `scripts/build_nations_league_outcomes.R` | exact production builder pattern |
| `scripts/build_uefa_euro_qualifying_outcomes.R` | CLI compatibility entrypoint | request-response / delegation | `scripts/build_uefa_nations_league_outcomes.R` | exact wrapper pattern |
| `tests/testthat/test_phase16_euro_qualifying.R` | contract, unit, integration, replay test | transform, batch, file-I/O | `tests/testthat/test_phase15_nations_league.R` | closest competition test harness |

The research also calls for synthetic mixed-size groups, host-slot cases, Phase 15 eligibility handoffs, invalid source bundles, and all three play-off topologies. These can be inline test builders or new `tests/fixtures/phase16/*` files; no exact fixture filename is locked by the phase context.

## Pattern Assignments

### `R/competition/uefa_euro_rules.R` (utility / rules adapter, transform)

**Analog:** `R/competition/uefa_nations_league_rules.R`

Copy the module boundary and keep competition semantics separate from arithmetic state construction. The existing module explicitly owns rules/topology and leaves standings arithmetic to the Phase 14 reducer (`R/competition/uefa_nations_league_rules.R:1-5`). The EURO module should therefore own Articles 13-17 and 23-24, activation validation, host allocation, runner-up ordering, eligibility selection, and topology validation, while consuming Phase 14 standings/state inputs.

**Identity and status pattern** (`R/competition/uefa_nations_league_rules.R:7-20`):

```r
uefa_nl_ruleset_version <- function() {
  "uefa-nations-league-2026-27-v2"
}

uefa_nl_edition_id <- function() {
  "uefa_nations_league_2026_27"
}

uefa_nl_source_bundle_id <- function() {
  "nl-2026-27-official-uefa-v2"
}

uefa_nl_stage_status_values <- function() {
  c("official", "projected", "unresolved", "completed", "suppressed")
}
```

For EURO, use corresponding stable helpers such as `uefa_euro_ruleset_version()`, `uefa_euro_edition_id()`, `uefa_euro_source_bundle_id()`, and explicit status/reason enums. Do not make the 6 December 2026 date alone activate the edition.

**Canonical hashing pattern** (`R/competition/uefa_nations_league_rules.R:50-67`, `828-832`):

```r
uefa_nl_rules_canonical_sha256 <- function(data, key = NULL) {
  if (exists("phase13_canonical_sha256", mode = "function", inherits = TRUE)) {
    return(phase13_canonical_sha256(data, key = key))
  }
  # fallback canonical sort and digest implementation...
}

uefa_nl_ruleset_sha256 <- function(rules = uefa_nl_2026_27_rules(), topology = NULL) {
  value <- if (is.null(topology)) rules else list(rules = rules, topology = topology)
  digest::digest(uefa_nl_rules_canonical_object(value), algo = "sha256", serialize = FALSE)
}
```

Reuse Phase 13 hash helpers when available, hash the complete canonical rules/topology object, and carry `ruleset_version` plus `ruleset_sha256` through every EURO ranking, allocation, topology, and outcome row.

**Topology table pattern** (`R/competition/uefa_nations_league_rules.R:302-323`):

```r
uefa_nl_stage_topology <- function(rules = uefa_nl_2026_27_rules()) {
  definitions <- rules$stages
  rows <- lapply(definitions, function(stage) {
    data.frame(
      edition_id = rules$edition_id,
      ruleset_version = rules$ruleset_version,
      stage_id = as.character(stage$stage_id),
      stage_type = as.character(stage$stage_type),
      legs = as.integer(stage$legs),
      seed_policy = as.character(stage$seed_policy),
      different_group = as.logical(stage$different_group),
      first_leg_home_policy = as.character(stage$first_leg_home_policy),
      tie_break_policy = as.character(stage$tie_break_policy),
      cancellation_condition = as.character(stage$cancellation_condition),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output <- output[order(output$stage_id, method = "radix"), , drop = FALSE]
  row.names(output) <- NULL
  output
}
```

EURO should expose a ruleset-backed topology table or equivalent object with the three official branches: `reserved_slots_used = 2` -> 8 entrants / 2 single-leg paths / 2 places; `1` -> 12 / 3 / 3; `0` -> 8 / 4 home-and-away ties / 4. Validate source-supplied topology constraints and return `unresolved` for incomplete or unsupported shapes.

**Recommended new signatures:**

```r
uefa_euro_2026_28_rules <- function()
uefa_euro_playoff_topologies <- function(rules = uefa_euro_2026_28_rules())
validate_euro_activation <- function(status, groups, fixtures, team_registry, source_bundle)
rank_euro_group <- function(standings, fixtures, rules = uefa_euro_2026_28_rules())
rank_euro_overall <- function(standings, fixtures, rules = uefa_euro_2026_28_rules())
allocate_euro_places <- function(group_rankings, host_ids, nl_eligibility, rules)
```

`validate_euro_activation()` should check official status, non-empty groups, stable/resolved team IDs, complete official fixtures, unique stable fixture IDs, `kickoff_confirmed == TRUE`, non-empty `confirmed_kickoff_at_utc`, edition/source lineage, and ruleset identity. Empty initial standings/results are valid only after these checks pass.

**Ranking evidence:** Preserve `counted_match_ids` and `excluded_match_ids` in Article 23 output. For positions 1-4 in a five-team group, exclude matches against fifth place; retain all matches for fifth place. Keep Article 15 tied-subset evidence/reason fields rather than reducing the result to a generic points sort.

**Host ledger:** Keep host slots separate from direct qualification. The allocation output should include explicit host association, slot status (`occupied`, `unused`, `unresolved`), direct-qualification consumption, remaining capacity, source/rules lineage, and a suppression reason when host guarantees are unresolved.

**Phase 15 handoff:** Consume the accepted transition table by stable `team_id`. The existing helper rejects missing/duplicate IDs and incomplete candidate coverage with `unresolved_external_eligibility` (`R/competition/uefa_nations_league_rules.R:1972-1989`). Do not reconstruct Nations League rankings from EURO rows or join on display names.

---

### `R/competition/uefa_euro_simulation.R` (service / simulator, batch transform)

**Analog:** `R/competition/uefa_nations_league_simulation.R`

Use the established seeded, caller-RNG-preserving simulation boundary. The simulator must consume Phase 14 calibrated forecasts and score distributions, then invoke the EURO rules adapter for ranking, host allocation, eligibility, potting, and topology-specific resolution.

**Seed isolation pattern** (`R/competition/uefa_nations_league_simulation.R:84-96`):

```r
uefa_nl_sim_with_seed <- function(seed, callback) {
  if (!is.function(callback)) stop("Nations League simulation seeded callback must be a function", call. = FALSE)
  if (is.null(seed)) return(callback())
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Nations League simulation seed must be one non-negative integer", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  set.seed(seed)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  callback()
}
```

Copy this behavior with EURO-prefixed names. Determinism must include simulation count, seed, canonical input ordering, draw-policy identity, source bundle hash, ruleset hash, and model/state lineage.

**Forecast admission and conditional score sampling** (`R/competition/uefa_nations_league_simulation.R:223-265`):

```r
uefa_nl_sample_stage_match <- function(
    forecast, score_distribution, seed = NULL, stage_id = "league_phase",
    stage_status = "projected", projection_run_id = "", draw_policy_id = "") {
  row <- uefa_nl_sim_forecast_row(forecast)
  if (!identical(tolower(as.character(row$forecast_status[[1L]])), "available")) {
    stop("Nations League stage sampling requires forecast_status = available", call. = FALSE)
  }
  probabilities <- uefa_nl_sim_probability_vector(row)
  # Sample calibrated 1X2 outcome, then condition the score grid on it.
}
```

EURO fixture-level simulation should retain this fail-closed admission: no probability or sampled result for unavailable, pre-draw, missing-kickoff, unresolved-source, or unsupported-topology inputs.

**Two-leg resolution pattern** (`R/competition/uefa_nations_league_simulation.R:352-468`):

```r
uefa_nl_resolve_two_leg_tie <- function(
    pair, seed = NULL, rules = uefa_nl_2026_27_rules(),
    lower_league_team_id = NULL, penalty_winner = NULL,
    second_leg_extra_time = NULL) {
  uefa_nl_validate_two_leg_pair(pair, lower_league_team_id = lower_league_team_id, rules = rules)
  ordered <- pair[order(as.integer(pair$leg_number), method = "radix"), , drop = FALSE]
  uefa_nl_sim_with_seed(seed, function() {
    # Resolve aggregate goals, then second-leg extra time and penalties.
  })
}
```

Reuse the existing single-leg resolver for the two-path and three-path branches, and the aggregate/two-leg resolver for the zero-host-slot branch. Keep extra time and penalties as explicit resolution fields. Do not force all three official topologies through one bracket shape.

**Recommended new signatures:**

```r
uefa_euro_run_simulation <- function(
    canonical_matches, completed_results, forecast_status, forecasts,
    score_distributions, groups, standings, hosts, nl_eligibility,
    rules, simulation_count = 1000L, seed = 16017L,
    source_bundle_id, source_bundle_sha256, model_release_id,
    model_lineage, state_manifest_sha256)
uefa_euro_simulate_qualification <- function(...)
uefa_euro_resolve_single_leg <- function(pair, seed = NULL, rules = ...)
uefa_euro_resolve_two_leg_tie <- function(pair, seed = NULL, rules = ...)
```

Return deterministic projected group standings, Article 23 rankings, direct qualifiers, host ledger, play-off eligibility/potting, topology/stage slots, team qualification probabilities, and suppression metadata.

---

### `R/competition/uefa_euro_outcomes.R` (output contract / serializer, batch and file-I/O)

**Analog:** `R/competition/uefa_nations_league_outcomes.R`

Copy the Phase 15 sibling-artifact design, but define EURO-specific tables for qualification ledger, projected standings/rankings, host slots, Nations League eligibility, play-off topology/stage slots, team qualification probabilities, fixture forecast/form pass-through, simulation metadata, and the outcomes manifest. Preserve exact schemas, stable row hashes, parent hashes, and compact CSV output.

**Inventory and schema pattern** (`R/competition/uefa_nations_league_outcomes.R:19-123`):

```r
phase15_nl_outcomes_expected_inventory <- function() {
  file.path("outcomes", c(
    "competition_topology.csv", "stage_slots.csv",
    "projected_standings.csv", "projected_rankings.csv",
    "transition_outcomes.csv", "team_path_probabilities.csv",
    "fixture_forecast_form.csv", "simulation_metadata.csv",
    "outcomes_manifest.csv"
  ))
}

phase15_nl_outcomes_schema <- function() {
  list(
    projected_rankings = c(
      "edition_id", "projection_run_id", "ranking_scope", "league", "group_id",
      "team_id", "group_position", "interim_overall_rank", "final_overall_rank",
      "ranking_stage", "rank", "probability", "counted_match_ids", "excluded_match_ids",
      "ranking_status", "missing_rule_input", "suppression_reason",
      "ruleset_version", "ruleset_sha256", "simulation_seed", "row_sha256"
    )
  )
}
```

For EURO, make `qualification_ledger.csv` (or equivalent) the auditable ordered allocation table. It should represent direct group winners, best runners-up, host reservation consumption, remaining runner-up play-off places, Nations League A-C entrants, League D fallback, broader ranking fallback, and final topology placement as explicit rows/stages.

**Hash and canonical CSV pattern** (`R/competition/uefa_nations_league_outcomes.R:164-209`):

```r
phase15_nl_add_row_hashes <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 outcomes row hashing requires a data frame", call. = FALSE)
  if (!"row_sha256" %in% names(data)) stop("Phase 15 outcomes artifact requires row_sha256", call. = FALSE)
  data$row_sha256 <- ""
  data$row_sha256 <- phase15_nl_row_hashes(data)
  phase15_nl_sort_table(data)
}

phase15_nl_table_content_hash <- function(data) {
  phase15_nl_sha256(phase15_nl_csv_bytes(data))
}
```

Use the Phase 13 publication writer when available and normalize scalar serialization before hashing so R CSV read-back does not alter hashes.

**Validation and atomic writer pattern** (`R/competition/uefa_nations_league_outcomes.R:1346-1465`):

```r
phase15_validate_nl_outcomes_bundle <- function(bundle) {
  artifacts <- bundle$artifacts %||% bundle$outcomes_artifacts
  manifest <- bundle$manifest %||% artifacts[["outcomes/outcomes_manifest.csv"]]
  expected <- phase15_nl_outcomes_expected_inventory()
  if (!is.list(artifacts) || !setequal(names(artifacts), expected)) {
    stop("Phase 15 outcomes candidate must contain exactly the nine-file sibling inventory", call. = FALSE)
  }
  # Require schema, edition, row-hash, probability, lineage, and manifest validity.
}
```

The EURO validator must reject foreign editions, invalid row hashes, non-conserved probability groups, missing source/rules/seed lineage, unresolved inputs carrying probabilities, and unsupported topology rows. Pre-draw output should be schema-valid empty artifacts with edition-level status/reason metadata and no fixture or qualification probability rows.

**Recommended new signatures:**

```r
phase16_euro_outcomes_expected_inventory <- function()
phase16_euro_outcomes_schema <- function()
phase16_build_euro_outcomes_candidate <- function(simulation, rules, source, state_bundle, nl_eligibility, ...)
phase16_validate_euro_outcomes_bundle <- function(bundle)
phase16_write_euro_outcomes_bundle <- function(candidate, output_root = NULL, project_root = ".")
phase16_read_euro_outcomes_bundle <- function(root = NULL, project_root = ".", validate = TRUE)
```

---

### `scripts/build_euro_qualifying_outcomes.R` (CLI / orchestration, batch and file-I/O)

**Analog:** `scripts/build_nations_league_outcomes.R`

Source dependencies in the same order and style as the Phase 15 builder (`scripts/build_nations_league_outcomes.R:39-50`): source contracts/publication hashes, Phase 14 forecast/form/match/state modules, standings, the EURO rules/simulation modules, and the EURO outcomes module. Use `sys.source()` into the script environment and fail immediately when a required dependency is missing.

**Candidate construction pattern:** Copy the Phase 15 builder's `phase15_nl_build_candidate()` flow (`scripts/build_nations_league_outcomes.R:319-350`): obtain the Phase 14 state bundle, validate the forecast handoff, call the seeded simulator with source/rules/model/state lineage, build the durable candidate, attach the parent graph, and run the outcomes validator before any write.

The EURO builder must additionally:

- reject `pre_draw` as a simulation input while returning the explicit pre-draw/unavailable candidate envelope;
- validate the complete accepted five-resource bundle and activation gate before using groups or fixtures;
- load and validate the accepted Phase 15 transition outcomes by `team_id`;
- keep the last accepted source/output bundle untouched when a post-draw candidate fails;
- pass source bundle ID/hash, state manifest hash, model release identity, ruleset version/hash, simulation seed/count, and warning/revision metadata into the candidate.

**CLI, replay, and write modes** (`scripts/build_nations_league_outcomes.R:481-568`):

```r
phase15_build_nl_outcomes_main <- function(
    args = commandArgs(trailingOnly = TRUE),
    project_root = phase15_nl_project_root
) {
  options <- phase15_nl_parse_args(args)
  if (isTRUE(options$help)) return(list(help = TRUE, durable_mutation = FALSE))
  rng_before <- phase15_nl_rng_snapshot()
  on.exit(phase15_nl_rng_restore(rng_before), add = TRUE)
  loaded <- phase15_nl_default_inputs(options$edition_id, project_root)
  normal <- phase15_nl_build_candidate(loaded, options)
  if (identical(options$mode, "replay")) {
    # compare normal, reversed, and repeated candidates byte-for-byte
  }
  if (identical(options$mode, "write")) {
    # validate and atomically write the registered outcomes root
  }
  result
}
```

Keep `--dry-run`, `--replay-check`, and `--write` mutually safe, make dry-run/replay non-mutating, restore caller RNG state, and print compact validation/lineage results. Phase 17 owns cross-competition atomic refresh; this builder should only own the EURO candidate/output boundary.

---

### `scripts/build_uefa_euro_qualifying_outcomes.R` (CLI compatibility entrypoint, request-response / delegation)

**Analog:** `scripts/build_uefa_nations_league_outcomes.R:1-17`

Use the same thin wrapper convention if Phase 16 exposes both plan-owned and explicit UEFA command names:

```r
phase15_uefa_delegate <- file.path(
  phase15_uefa_project_root,
  "scripts/build_nations_league_outcomes.R"
)
if (!file.exists(phase15_uefa_delegate)) {
  stop("The plan-owned Nations League outcomes builder is missing.", call. = FALSE)
}
sys.source(phase15_uefa_delegate, envir = environment())
```

Rename the symbols/messages/target path for EURO and delegate without adding independent business logic. If the planner chooses one CLI only, omit this file rather than duplicating the builder.

---

### `tests/testthat/test_phase16_euro_qualifying.R` (contract, unit, integration, replay test)

**Analog:** `tests/testthat/test_phase15_nations_league.R`, with state/publication cases borrowed from `tests/testthat/test_phase14_state_bundle.R` and `tests/testthat/test_phase13_publication_hashes.R`.

**Source-style API loader** (`tests/testthat/test_phase15_nations_league.R:105-122`):

```r
phase15_test_source <- function(relative_path, envir = .GlobalEnv) {
  path <- file.path(phase15_test_project_root, relative_path)
  if (!file.exists(path)) stop(sprintf("missing Phase 15 source file: %s", relative_path), call. = FALSE)
  sys.source(path, envir = envir)
  invisible(path)
}

phase15_test_source("R/competition/source_contracts.R")
phase15_test_source("R/competition/publication_hashes.R")
phase15_test_source("R/competition/state_bundle.R")
phase15_test_source("R/competition/uefa_nations_league_rules.R")
phase15_test_source("R/competition/uefa_nations_league_simulation.R")
```

Load the Phase 13-15 dependencies plus the new EURO rules/simulation/outcomes modules in a deterministic order. Use test-local synthetic data and do not change production data or accepted bundles.

**Required test groups:**

- `pre_draw` returns schema-valid empty groups, fixtures, standings, results, forecasts, qualification ledger, and probability tables with explicit `pre_draw` / `awaiting_official_draw_and_schedule` status;
- activation accepts a complete official status/groups/teams/fixture bundle with empty standings/results, but rejects missing group rows, unknown/duplicate team IDs, duplicate fixture IDs, missing kickoff confirmation, missing kickoff timestamp, foreign lineage, and invalid hashes;
- failed post-draw correction leaves the last accepted bundle bytes/hashes unchanged and exposes a revision/block warning;
- Article 15 tied-subset recursion and Article 23 five-team exclusion preserve counted/excluded match evidence and deterministic ordering;
- host ledger covers zero, one, and two reserved slots used, direct host qualification consumption, unused capacity, and `host_place_unresolved` suppression;
- Phase 15 handoff accepts complete unique `team_id` eligibility and rejects missing, duplicate, wrong-stage, incomplete, or unresolved rows;
- all three official topology branches validate their cardinality, potting, host separation, single-leg/two-leg resolution, and probability conservation;
- unresolved eligibility, unsupported topology, invalid source, missing kickoff, and pre-draw state produce no fabricated probability rows;
- normal, reversed-input, repeated, and fresh-process replays produce identical artifact bytes/hashes and preserve the caller RNG state.

Phase 15's concrete rule-test style is the model: synthetic group fixtures are asserted for schema and invariants, invalid variants are passed to `expect_error()`, and completed stage rows assert score axes, source lineage, and row hashes (`tests/testthat/test_phase15_nations_league.R:809-910`).

## Shared Patterns

### Source bundle and activation

**Sources:** `R/competition/source_contracts.R:8-80`, `653-715`; `R/competition/edition_registry.R:19-20`; `R/competition/publication_hashes.R:326-339`  
**Apply to:** EURO activation validator, builder, outcomes validator, and focused tests.

```r
phase13_source_required_resource_types <- function() {
  c("fixtures", "groups", "standings", "results", "status")
}

phase13_validate_source_bundle <- function(bundle, artifacts) {
  # Require one accepted bundle, all five resource classes, matching edition /
  # bundle foreign keys, matching parser/provenance, canonical artifact hash,
  # accepted status, and last_accepted_bundle_id.
}
```

Activation is a bundle-validation result, not a date toggle. Preserve the existing `pre_draw` structural guard: when EURO status contains `pre_draw`, every non-status structure table must have zero rows (`publication_hashes.R:326-339`).

### Pre-draw state and forecast suppression

**Source:** `R/competition/state_bundle.R:1103-1138`  
**Apply to:** EURO state handoff, outcomes candidate, and tests.

```r
if (identical(lifecycle, "pre_draw")) {
  forecast <- phase14_forecast_empty_result("pre_draw")
  forecast$fixture_status <- forecast_status_table
  return(list(
    lifecycle_state = lifecycle,
    fixtures = phase14_state_bundle_empty(),
    results = phase14_state_bundle_empty(),
    groups = phase14_state_bundle_empty(),
    standings = phase14_state_bundle_empty(),
    forecast_status = "pre_draw",
    state_status = "pre_draw"
  ))
}
```

Do not populate projected teams, placeholder fixtures, zero-score matches, or qualification probabilities. Preserve edition-level status, official draw date, source confidence, refresh time, and reason fields in the payload/manifest for Phase 17.

### Edition isolation and stable identity

**Sources:** `R/competition/state_bundle.R:102-129`; `R/competition/standings.R:273-318`  
**Apply to:** all EURO rules/state joins.

Filter every input by `edition_id`, reject foreign rows in shared orchestration, use canonical `team_id` for all cross-competition joins, and keep display names as source metadata only. Pass the EURO rules adapter behind the Phase 14 standings seam; do not mix EURO fixtures/results/standings with Nations League state.

### Candidate isolation and atomic replacement

**Source:** `R/competition/publication_transaction.R:62-97`, `264-296`; `scripts/acquire_uefa_snapshot.R` accepted-candidate staging flow.  
**Apply to:** post-draw corrections, rules/topology revisions, and outcomes publication.

Build and validate a candidate in a staging root, validate the complete target graph, then promote ordered targets. On any failure, restore the previous target bytes and leave refresh history/unrelated files untouched. The existing transaction explicitly backs up each target before rename and injects/handles promotion failure; the new EURO builder should use this boundary rather than patching active rows in place.

### Phase 15 eligibility and outcome lineage

**Sources:** `R/competition/uefa_nations_league_rules.R:1949-1989`; `R/competition/uefa_nations_league_outcomes.R:70-85`, `102-120`.  
**Apply to:** EURO qualification ledger, play-off pool, simulation metadata, and manifest.

Carry `team_id`, `eligibility_status`, `unresolved_reason`, `source_bundle_id`, `model_release_id`, `ruleset_version`, `ruleset_sha256`, `simulation_seed`, and row hashes. A missing or incomplete Phase 15 handoff remains `unresolved_external_eligibility`; it must not be converted to an ineligible/eligible guess.

### Deterministic durable outputs

**Source:** `R/competition/uefa_nations_league_outcomes.R:164-209`, `1346-1465`; `scripts/build_nations_league_outcomes.R:481-568`.  
**Apply to:** all Euro outcome artifacts and replay tests.

Canonicalize table ordering before row/content hashing, validate every artifact against its declared schema, require manifest parent paths/hashes, verify self-hash, compare reversed/repeated replays byte-for-byte, and write only the registered output root after validation.

## No Analog Found

| File / concern | Role | Data Flow | Reason |
|---|---|---|---|
| EURO-specific host allocation and three-branch play-off topology | rules / simulation | batch transform | No existing competition implements host-reserved places plus all three EURO Article 16/17 branches; use the Phase 15 rules, seeded simulation, and explicit unresolved-state patterns. |
| Article 23 mixed-size cross-group ranking | rules adapter | transform | Existing Phase 15 has cardinality-aware ranking evidence, but no EURO five-team exclusion rule; retain counted/excluded match IDs and add dedicated synthetic cases. |
| Phase 16 production source bundle | source integration | file-I/O | The future official EURO post-draw bundle does not exist yet; reuse Phase 13 schemas and fail closed until a complete accepted bundle is available. |

## Metadata

**Analog search scope:** `R/competition/`, `scripts/`, `tests/testthat/`, `tests/fixtures/`, plus Phase 13-16 planning artifacts.  
**Files scanned:** 6 primary analogs, with Phase 13/14 shared seams and Phase 15 eligibility/outcome helpers consulted.  
**Pattern extraction date:** 2026-08-23
