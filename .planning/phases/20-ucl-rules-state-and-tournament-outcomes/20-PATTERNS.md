# Phase 20: UCL Rules, State, and Tournament Outcomes - Pattern Map

**Mapped:** 2026-09-21  
**Files classified:** 8 planned/new-or-modified files (plus the durable outcome inventory)  
**Analogs found:** 7 / 8 role or contract matches; no exact UCL rules implementation exists

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/competition/uefa_champions_league_rules.R` | config / rules adapter | transform, request-response | `R/competition/uefa_nations_league_rules.R`, `R/competition/uefa_euro_rules.R` | role + reducer-seam match; UCL criteria are new |
| `R/competition/uefa_champions_league_state.R` | service / state projection | transform, request-response | `R/competition/match_state.R`, `R/competition/standings.R`, `R/competition/forecast_layer.R` | strong contract match |
| `R/competition/uefa_champions_league_simulation.R` | service / simulator | batch, transform, event-driven stage transitions | `R/competition/uefa_nations_league_simulation.R`, `R/competition/uefa_euro_simulation.R` | strong mechanics match; UCL draw policy is new |
| `R/competition/uefa_champions_league_outcomes.R` | store / payload + manifest | transform, file-I/O | `R/competition/uefa_nations_league_outcomes.R`, `R/competition/state_bundle.R` | exact sibling-bundle match |
| `scripts/build_uefa_champions_league_outcomes.R` | config / production orchestration | batch, file-I/O | `scripts/build_nations_league_outcomes.R`, `scripts/build_uefa_euro_qualifying_outcomes.R` | exact CLI/replay shape |
| `_targets.R` | config / pipeline orchestration | batch, request-response | current Phase 19 isolated target graph at `_targets.R:20-42,161-198` | role match; add a separate UCL graph |
| `tests/testthat/test_uefa_champions_league.R` | test / contract + adversarial integration | request-response, batch, file-I/O | `tests/testthat/test_phase15_nations_league.R`, `test_phase16_euro_qualifying.R`, Phase 19 adversarial tests | exact test style |
| `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` | config / pinned manual evidence | file-I/O | `R/competition/uefa_euro_rules.R:827-950` draw-condition record | no exact file analog; evidence is edition-specific |

The outcome writer should create a sibling `outcomes/` tree; do not add these
files to the Phase 14 state-bundle inventory. The planned closed inventory is:

```text
outcomes/competition_topology.csv
outcomes/league_schedule.csv
outcomes/tie_break_trace.csv
outcomes/projected_standings.csv
outcomes/projected_rankings.csv
outcomes/knockout_paths.csv
outcomes/progression_probabilities.csv
outcomes/fixture_forecast_ledger.csv
outcomes/simulation_metadata.csv
outcomes/outcomes_manifest.csv
```

## Pattern Assignments

### `R/competition/uefa_champions_league_rules.R` (config / rules adapter, transform)

**Closest analogs:** `R/competition/uefa_nations_league_rules.R` and
`R/competition/uefa_euro_rules.R`.

**New vs reuse:** Create a UCL-owned editioned rules object and draw-policy
contract. Reuse the Phase 15 data-driven ruleset, canonical hash, stage-topology,
tie-trace, and blocked-ordering shapes. Reuse `phase14_compute_standings()` only
for W/D/L/goals/points arithmetic. Do not copy Nations League head-to-head
criteria, group recursion, access-list ranking, or its interim lexical order.

**Module boundary** (`uefa_nations_league_rules.R:1-5`):

```r
# This module owns competition semantics and source-derived topology only.  It
# deliberately does not calculate standings; the universal Phase 14 reducer
# remains the arithmetic seam for later ranking adapters.
```

**Editioned rules and canonical identity** (`uefa_nations_league_rules.R:50-67,116-140`):

```r
uefa_nl_2026_27_rules <- function() {
  list(
    edition_id = uefa_nl_edition_id(),
    ruleset_version = uefa_nl_ruleset_version(),
    league_phase = list(...),
    group_tiebreak = c(...),
    ...
  )
}

uefa_nl_rules_canonical_sha256 <- function(data, key = NULL) {
  canonical <- data[, sort(names(data)), drop = FALSE]
  ...
  digest::digest(..., algo = "sha256", serialize = FALSE)
}
```

The UCL object should bind `ucl_2026_27`, a ruleset version/hash, 36-club and
144-fixture expectations, Article 18's exact criterion order, matchday 1-7
interim policy, rank bands (1-8/9-24/25-36), Article 19/Annex B draw policy,
two-leg/no-away-goals policy, and neutral-final policy. The pinned JSON is
evidence input, not a substitute for this typed object.

**Trace and blocked result** (`uefa_nations_league_rules.R:1096-1119,1195-1210`):

```r
uefa_nl_group_tiebreak_trace <- function(
    group_id = NA_character_, league = NA_character_, criterion = character(),
    tied_subset = character(), counted_match_ids = character(), decision = character(),
    recursion_depth = 0L, remaining_tied_subset = character(), rules = uefa_nl_2026_27_rules()) {
  data.frame(
    ranking_scope = rep("group", n), criterion = rep(as.character(criterion), length.out = n),
    tied_subset = ..., counted_match_ids = ..., decision = ...,
    ruleset_version = rep(as.character(rules$ruleset_version), n),
    ruleset_sha256 = rep(uefa_nl_ruleset_sha256(rules), n), ...
  )
}

uefa_nl_blocked_ordering_result <- function(standings, missing_rule_input, ...) {
  output$computed_rank <- rep(NA_integer_, nrow(output))
  output$interim_rank <- rep(NA_integer_, nrow(output))
  output$ordering_status <- "blocked"
  output$missing_rule_input <- paste(missing_rule_input, collapse = ";")
  output$suppression_reason <- "missing_rule_input"
  ...
}
```

For UCL, each decisive Article 18 criterion must reference its counted fixtures
and source evidence. If late evidence is absent, preserve a shared unresolved
rank interval and leave `computed_rank`/band-dependent paths unavailable. The
alphabetical abbreviated-name display order described by UEFA is presentation
only, never a qualification rank.

**Reducer seam** (`uefa_nations_league_rules.R:1324-1352`):

```r
universal <- phase14_compute_standings(
  matches = rows, edition_id = edition_id, group_id = group_id,
  state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id,
  ruleset_adapter = NULL, team_ids = team_ids
)
...
phase14_standings <- phase14_compute_standings(
  matches = rows, edition_id = edition_id, group_id = group_id,
  state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id,
  ruleset_adapter = adapter, team_ids = team_ids
)
```

`phase14_standings_adapter_ranks()` (`R/competition/standings.R:281-315`)
requires the complete team set and contiguous unique ranks. Therefore the UCL
adapter may return exact ranks only when proven; it must not force unresolved
intervals through the reducer as lexical, source-order, or random ranks. Keep
the unresolved interval/trace in UCL state and suppress rank-dependent draw and
band paths.

**Explicit non-reuse:** `uefa_nl_2026_27_rules()$group_tiebreak` at
`uefa_nations_league_rules.R:130-140` contains head-to-head criteria and must
not be copied into UCL Article 18. `uefa_nl_rank_interim_overall()`'s lexical
fallback is also not safe for UCL eligibility.

---

### `R/competition/uefa_champions_league_state.R` (service / state projection, transform)

**Closest analogs:** `R/competition/match_state.R`,
`R/competition/standings.R`, `R/competition/ucl_source_refresh.R`, and the
forecast ledger in `R/competition/forecast_layer.R`.

**New vs reuse:** Build one UCL state boundary that reads only the accepted
Phase 18 source bundle, validates the complete schedule, calls the universal
reducer plus the UCL rules adapter, and emits the typed forecast ledger. Reuse
canonical-v2 match identity/lifecycle/score fields and strict cutoff logic;
do not create UCL-specific status or score semantics.

**Canonical match schema and semantics** (`R/competition/match_state.R:646-660,976-1018`):

```r
phase14_canonical_match_schema <- function() {
  c(
    "schema_version", "match_id", "source_namespace", "source_id",
    "source_match_id", "source_lineage_id", "edition_id", "fixture_id",
    "home_team_id", "away_team_id", "scheduled_at_utc",
    "kickoff_confirmed", "confirmed_kickoff_at_utc", "source_status",
    "match_status", "completion_method", "regulation_home_goals",
    "regulation_away_goals", "final_home_goals", "final_away_goals",
    "shootout_home_goals", "shootout_away_goals", "winner_team_id",
    "evidence_completed_at_utc", "counts_for_standings", ...,
    "row_sha256", "table_sha256"
  )
}
```

The existing validator rejects unmapped lifecycle states, inconsistent
completion methods, incomplete score pairs, and invalid penalty winners. The
UCL schedule validator should additionally require exactly 36 unique clubs and
144 accepted fixtures, eight distinct opponents per club, four home/four away,
matchday 1-8, kickoff, venue, lifecycle, score semantics, stable IDs, and
source lineage. A missing edge is blocked; it is never generated from a known
round-robin cardinality.

**Accepted Phase 18 handoff** (`R/competition/ucl_source_refresh.R:325-375`):

```r
if (identical(as.character(pointer$accepted_status), "accepted")) {
  accepted <- phase18_read_ucl_candidate(accepted_root_path)
  phase18_validate_ucl_source_bundle(accepted)
}
...
out <- list(pointer = pointer, state = state, history = history,
  sidecar = sidecar, accepted = accepted, ...)
phase18_validate_ucl_refresh_current(out)
```

State must consume `current$accepted` only when it is accepted and complete;
provider standings remain reconciliation evidence. Preserve the Phase 18
authority/source/table hashes in every state artifact and carry a typed
`blocked`/`unresolved` status when no accepted bundle exists.

**Universal arithmetic and cutoff** (`R/competition/standings.R:324-390`):

```r
required <- c("home_team_id", "away_team_id", "final_home_goals",
              "final_away_goals", "counts_for_standings")
...
status <- tolower(phase14_standings_clean_text(matches$match_status))
completed_status <- status %in% c("completed", "after_extra_time", "after_penalties", ...)
```

Call `phase14_compute_standings()` once for universal played/W/D/L/goals/points
and attach the UCL Article 18 ordering trace through the adapter. Do not
recompute those metrics in the UCL module.

**One-row-per-fixture forecast ledger** (`R/competition/forecast_layer.R:1543-1577`):

```r
status_rows <- lapply(seq_len(nrow(canonical_matches)), function(row) {
  fallback <- phase14_forecast_batch_fallback_row(canonical_matches, row, edition_id, registry)
  reason <- eligibility[[row]]
  ...
  phase14_forecast_batch_hash_row(lineage)
})
fixture_status <- do.call(rbind, status_rows)
if (anyDuplicated(as.character(fixture_status$fixture_id)) ||
    !setequal(as.character(fixture_status$fixture_id), fixture_ids)) {
  stop("Phase 14 forecast fixture/status identity is not exact", call. = FALSE)
}
```

Use the same exact coverage and typed suppression shape. Resolve production
club authority internally via `phase19_resolve_production_club_release()`;
completed fixtures retain their existing pre-kickoff forecast bytes, while only
open fixtures with strict `forecast_cutoff_utc < kickoff` may receive a new
forecast. A blocked release still yields a ledger row for every fixture, not a
silently shortened table.

---

### `R/competition/uefa_champions_league_simulation.R` (service / simulator, batch)

**Closest analogs:** `R/competition/uefa_nations_league_simulation.R` and
`R/competition/uefa_euro_simulation.R`.

**New vs reuse:** Reuse seeded RNG scoping, calibrated forecast handoff,
fixed-completed/open partitioning, two-leg arithmetic, stage ledgers, and
metadata lineage. Implement UCL rank-constrained draw path enumeration and
accepted-draw conditioning as a UCL policy; do not reuse a generic UEFA draw or
fixed bracket.

**RNG isolation** (`uefa_nations_league_simulation.R:84-96`):

```r
uefa_nl_sim_with_seed <- function(seed, callback) {
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

Canonicalize fixture/club IDs before deriving per-iteration seeds. Preserve the
caller's RNG state and bind the simulation seed/count, ruleset/draw hashes,
source/state/release hashes, and cutoff into `simulation_metadata.csv`.

**Fixed versus sampled fixtures** (`uefa_nations_league_simulation.R:1365-1407`):

```r
qualifies <- output$stage_id[[index]] == "league_phase" &&
  uefa_nl_sim_status_is_completed(output$match_status[[index]]) &&
  uefa_nl_sim_score_present(output[index, , drop = FALSE]) &&
  !is.na(evidence) && evidence <= as.POSIXct(cutoff_utc, tz = "UTC")
output$counts_for_standings[[index]] <- isTRUE(qualifies)
...
open <- output$stage_id == "league_phase" & uefa_nl_sim_status_is_open(output$match_status)
```

Copy accepted completed results into every iteration. Sample only eligible open
fixtures whose forecast status, calibrated probabilities, and score grid are
available. Missing forecasts remain a typed unresolved/suppressed row.

**Legal draw enumeration** (`uefa_nations_league_simulation.R:537-590`):

```r
legal <- list()
walk <- function(index, used, chosen) {
  if (index > nrow(winners)) {
    legal[[length(legal) + 1L]] <<- chosen
    return(invisible(NULL))
  }
  candidates <- which(!(seq_len(nrow(runners_up)) %in% used) &
                      as.character(runners_up$group_id) != as.character(winners$group_id[[index]]))
  for (candidate in candidates) walk(index + 1L, c(used, candidate), c(chosen, candidate))
}
walk(1L, integer(), integer())
```

For UCL, enumerate only Article 19/Annex B rank-compatible pair families and
carry a path identity/hash. Before an accepted draw, report legal paths or an
unresolved state; after an accepted same-edition draw, use its exact pairing
artifact once and never resample it. A tie interval crossing rank 8 or 24
suppresses any draw path that requires the exact rank.

**Two-leg and final resolution** (`uefa_nations_league_simulation.R:352-412`
and `R/competition/uefa_euro_simulation.R:821-883`):

```r
aggregate <- first_total + second_reg_total
if (diff(range(aggregate)) == 0) {
  # UCL wrapper: second-leg extra time only, then penalties.
}
if (diff(range(aggregate)) == 0) {
  penalty_used <- TRUE
  ...
}
```

Reuse the tested two-leg participant/leg validation and score-resolution shape,
but make UCL policy explicit: no away-goals criterion, second-leg extra time
and penalties only when aggregate regulation scores are tied, and a neutral
single-match final. Do not carry Nations League lower-league first-leg hosting
rules into UCL.

**Negative pattern:** `uefa_nl_sim_penalty_winner()` (`:328-338`) falls back to
`sample(c(home_team, away_team), prob = c(0.5, 0.5))` when no penalty evidence
exists. That seeded fallback may be used only where the UCL rules explicitly
model an unresolved future shootout. It must never break an Article 18 tie,
choose an unresolved rank, or manufacture an illegal draw.

---

### `R/competition/uefa_champions_league_outcomes.R` (store / payload + manifest, transform/file-I/O)

**Closest analog:** `R/competition/uefa_nations_league_outcomes.R`, with
`R/competition/state_bundle.R` as the manifest/hash boundary.

**New vs reuse:** Create a UCL-specific closed ten-file sibling inventory and
schemas. Reuse canonical-v2 row/table hashing, stable ordering, parent graph,
typed stage statuses, exact inventory validation, atomic staging, read-back, and
manifest self-hash. Add UCL band/cut-line and progression conservation checks.

**Exact inventory validation** (`uefa_nations_league_outcomes.R:1429-1445`):

```r
expected <- phase15_nl_outcomes_expected_inventory()
if (!is.list(artifacts) || !setequal(names(artifacts), expected)) {
  stop("Phase 15 outcomes candidate must contain exactly the nine-file sibling inventory", call. = FALSE)
}
for (path in setdiff(expected, "outcomes/outcomes_manifest.csv")) {
  phase15_nl_require_schema(artifacts[[path]], schemas[[key]], path)
  if (nrow(table) && any(as.character(table$edition_id) != phase15_nl_edition_id())) stop(...)
  if (nrow(table) && any(as.character(table$row_sha256) != phase15_nl_row_hashes(table))) stop(...)
}
```

Use the UCL ten paths listed above, exact ordered names, canonical-v2 schemas,
stable IDs, and row/table hashes. Every artifact and manifest row carries
edition, source bundle, ruleset, club release, cutoff, draw policy, algorithm
version, seed/count, and parent artifact hashes. `fixture_forecast_ledger.csv`
must contain exactly one row for every accepted fixture, including blocked or
suppressed rows.

**Status and probability validators** (`uefa_nations_league_outcomes.R:1342-1383`):

```r
if (any(status == "unresolved" & missing("unresolved_reason"))) stop(...)
if (any(status == "suppressed" & missing("suppression_reason"))) stop(...)
if (any(status != "completed" & present)) stop("Non-completed stage slots must not carry score fields", call. = FALSE)
...
sums <- tapply(probabilities, groups, sum)
if (any(abs(as.numeric(sums) - 1) > tolerance)) stop("... probabilities are not conserved", call. = FALSE)
```

Extend this validator to require mutually exclusive top-8/play-off/eliminated
probabilities summing to one, full-rank/cut-line reconciliation, and per-club
monotonic progression (`champion <= final <= semi-final <= quarter-final <=
round-of-16 <= play-off eligibility`). Unresolved rank intervals carry typed
NA/reason values rather than a repaired or dashboard-normalized probability.

**Atomic writer/read-back** (`uefa_nations_league_outcomes.R:1490-1551`):

```r
root <- phase15_nl_validate_output_root(output_root, project_root)
expected_files <- sub("^outcomes/", "", phase15_nl_outcomes_expected_inventory())
if (length(existing) && !setequal(existing, expected_files)) stop(...)
staging <- tempfile(".outcomes-staging-", tmpdir = parent)
...
if (!file.rename(staging, root)) stop("Could not atomically promote ...", call. = FALSE)
output <- phase15_nl_read_outcomes_bundle(root, validate = TRUE)
```

Keep production output under the registered fixed UCL outcome root and protect
an existing incumbent. The command may use a process-temporary root only for
fixture tests; a caller must not choose a production root or write a fixture
bundle into production.

---

### `scripts/build_uefa_champions_league_outcomes.R` (production entrypoint, batch/file-I/O)

**Closest analog:** `scripts/build_nations_league_outcomes.R`.

**Bootstrap and dependency contract** (`scripts/build_nations_league_outcomes.R:21-53`):

```r
phase15_nl_source_if_missing <- function(relative_path, symbol) {
  dependency <- file.path(phase15_nl_project_root, relative_path)
  if (!file.exists(dependency)) stop(...)
  sys.source(dependency, envir = phase15_nl_script_environment)
}
...
phase15_nl_source_file("R/competition/match_state.R")
phase15_nl_source_if_missing("R/competition/standings.R", "phase14_compute_standings")
phase15_nl_source_if_missing("R/competition/uefa_nations_league_outcomes.R", ...)
```

Create the same private script environment and project-root resolution, but
source the UCL state/rules/simulation/outcomes modules plus the accepted Phase
18 and Phase 19 contracts. Do not source national release/model modules into
the UCL graph.

**CLI/replay/write contract** (`scripts/build_nations_league_outcomes.R:66-153,498-548`):

```r
options <- list(edition_id = NULL, simulations = 1000L, seed = 15017L,
                dry_run = FALSE, replay_check = FALSE, write = FALSE,
                mode = "dry-run")
...
if (isTRUE(options$write) && (isTRUE(options$dry_run) || isTRUE(options$replay_check))) stop(...)
options$mode <- if (isTRUE(options$write)) "write" else if (isTRUE(options$replay_check)) "replay" else "dry-run"
```

Preserve `--edition-id`, `--simulations`, `--seed`, `--dry-run`,
`--replay-check`, `--write`, and `--help`; reject foreign editions and unknown
arguments. Replay must compare normal, reversed-input, and repeated builds at
the canonical artifact bytes and protected completed forecast fields.

The production entrypoint must resolve the fixed Phase 18 accepted UCL source
root and `phase19_resolve_production_club_release()` internally. It must not
accept `--fixture-root`, `--selector-path`, `--trusted-release-root`, a national
selector, or an output-root override. Missing authority returns typed blocked or
unresolved output and leaves selectors/incumbent outcome bytes unchanged.

---

### `_targets.R` (config / pipeline orchestration, batch)

**Closest analog:** current Phase 19 target isolation (`_targets.R:20-42,161-198`).

**Existing isolation pattern:**

```r
phase19_target_runtime_envir <- new.env(parent = globalenv())
source("R/competition/ucl_source_bundle.R")
source("R/competition/ucl_source_refresh.R")
source("R/club/release.R")
...
phase19_targets_blocked <- function(reason_code, upstream = NULL) {
  list(schema_version = "phase19-club-target-state-v1",
       forecast_domain = "club", authority_mode = "production",
       fixture_authority = FALSE, production_eligible = FALSE,
       status = "blocked", reason_code = as.character(reason_code), ...)
}
```

Add a separate UCL runtime/target namespace that sources the canonical Phase 14
match/standings/forecast contracts, Phase 18 accepted UCL source reader, Phase
19 club production resolver, and the four new UCL modules. Carry typed
`blocked`/`unresolved` state through downstream targets; do not turn a missing
authority into an exception that allows a later target to fit, publish, or
advance a selector. Keep the graph free of national release, FIFA/national
identity, and World Cup/Euro target dependencies.

Targets should call the same fixed production entrypoint used by the script and
publish only the registered UCL outcomes root. If the planner chooses not to
add targets in this phase, retain the script as the authoritative orchestrator
and add a wiring test that proves no national targets are imported.

---

### `tests/testthat/test_uefa_champions_league.R` (test, contract/request-response/batch)

**Closest analogs:** `tests/testthat/test_phase15_nations_league.R:105-123`
(source harness and sibling tests), `test_phase16_euro_qualifying.R:59-115`
(typed pre-draw/unavailable state), and Phase 19 adversarial probe inventory.

**Source harness pattern** (`test_phase15_nations_league.R:105-123`):

```r
phase15_test_source <- function(relative_path, envir = .GlobalEnv) {
  path <- file.path(phase15_test_project_root, relative_path)
  if (!file.exists(path)) stop(sprintf("missing Phase 15 source file: %s", relative_path), call. = FALSE)
  sys.source(path, envir = envir)
}
phase15_test_source("R/competition/uefa_nations_league_rules.R")
phase15_test_source("R/competition/uefa_nations_league_simulation.R")
phase15_test_source("R/competition/uefa_nations_league_outcomes.R")
```

Load only the UCL modules and their approved dependencies. Build a reusable
full-cardinality fixture helper (36 clubs, 144 fixtures, 8 opponents, 4/4
home-away) and a separate approved-release fixture helper. Fixture authority
must prove mechanics but remain `fixture_authority=TRUE`, non-promotable, and
unable to satisfy production resolution.

**Typed unavailable precedent** (`test_phase16_euro_qualifying.R:59-115`):

```r
phase16_test_pre_draw_bundle <- function() {
  list(lifecycle_state = "pre_draw", forecast_status = "pre_draw",
       forecast_reason = "awaiting_official_draw_and_schedule", ...)
}
expect_true(identical(bundle$lifecycle_state, "pre_draw"))
```

Use equivalent UCL blocked/unresolved fixtures; never fabricate a schedule,
rank, draw, or probability to make a nominal test pass.

**Required focused tests:**

- UCLRULE-01/03: exact schedule cardinality, stable IDs, matchday/kickoff/
  lifecycle/score/lineage, eight distinct opponents and 4/4 venue split;
- UCLRULE-02: every Article 18 criterion order, criterion/subset trace,
  missing late evidence, shared unresolved interval, and rejection of lexical,
  provider, or random tie fallbacks;
- UCLOUT-01: production-only club authority, strict pre-kickoff cutoff,
  immutable completed forecast bytes, fixture non-promotion, fixed roots;
- UCLOUT-02/05: fixed completed results, mutually exclusive bands, rank/cut
  reconciliation, stage input/output accounting, monotonic progression;
- UCLOUT-03: only legal UCL rank-constrained paths, exact accepted-draw
  conditioning, same-edition/source-lineage checks, and no fixed/uniform illegal
  bracket;
- UCLOUT-04: two-leg aggregate without away goals, correct leg order,
  second-leg ET/penalties, neutral final;
- UCLOUT-06: identical/reverse-ordered inputs produce byte-identical artifacts,
  caller RNG is restored, timestamps/filesystem order are excluded, and a
  protected incumbent remains unchanged on blocked production.

The validation command is:

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'
```

---

### `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` (config, file-I/O)

**Closest analog:** Phase 16's explicit draw-condition record
(`R/competition/uefa_euro_rules.R:827-843`) and topology projection
(`:929-950`):

```r
list(
  draw_conditions_version = "uefa-euro-2028-playoff-draw-conditions-v1",
  draw_conditions_sha256 = phase16_euro_rules_hash(payload),
  source_artifact_id = "artifact-euro-draw-conditions-v1",
  source_bundle_id = uefa_euro_source_bundle_id(),
  accepted = TRUE, complete = TRUE, conditions = conditions
)
```

Create a UCL-edition manual evidence sidecar with document IDs/URLs, retrieval
or review metadata, raw/canonical hashes, Article 18/19/20/21/Annex B scope,
and an explicit accepted/complete status. The command must reject missing,
stale, partial, contradictory, or foreign-edition evidence. There is no exact
existing UCL evidence file to copy; keep this artifact pinned and versioned
rather than relying on a provider standings page or an unpinned summary.

## Shared Patterns

### Canonical identity, lifecycle, and hashing

**Sources:** `R/competition/match_state.R:646-660,1435-1497`,
`R/competition/ucl_source_bundle.R:53-89`, and
`R/competition/uefa_nations_league_outcomes.R:1386-1425`.

**Apply to:** every UCL state, simulation, ledger, outcome, and manifest table.

Use stable `edition_id`, club/fixture IDs, source artifact lineage, explicit
schema versions, canonical-v2 row/table hashes, deterministic semantic sorting,
and exact inventory validation. Do not hash RDS serialization, timestamps, or
filesystem enumeration.

### Authority and edition boundaries

**Sources:** `R/competition/ucl_source_refresh.R:325-375`,
`R/club/release.R:248-260,1091-1135`, and
`R/competition/ucl_source_bundle.R:194-226,237-262`.

**Apply to:** state loading, club release resolution, script, targets, and
publication.

Use accepted Phase 18 UCL state and the fixed Phase 19 production club resolver.
Carry authority mode, source bundle IDs/hashes, release selector/manifest hashes,
and domain identity. Fixture evidence is mechanics-only and permanently
non-promotable.

### Typed unavailable state / no silent drops

**Sources:** `R/competition/forecast_layer.R:594-609,1543-1577`,
`R/competition/uefa_nations_league_rules.R:1195-1210`, and
`tests/testthat/test_phase16_euro_qualifying.R:59-115`.

**Apply to:** missing schedule, missing rules/draw evidence, missing forecast,
unresolved rank interval, blocked production authority, and every output table.

Emit one row with a closed reason enum and NA/unavailable fields. Never omit a
fixture, replace unknown ranks with a lexical/random value, or normalize broken
probabilities downstream.

### Deterministic simulation and replay

**Sources:** `R/competition/uefa_nations_league_simulation.R:84-96,2030-2123`
and `scripts/build_nations_league_outcomes.R:383-475,478-548`.

**Apply to:** simulation and CLI/targets.

Canonicalize inputs, derive explicit seeds, restore caller RNG, sort output rows,
exclude generation timestamps from replay identity, and compare normal,
reversed-input, repeated-run bytes plus lineage fields.

### Reconciliation before publication

**Sources:** `R/competition/uefa_nations_league_outcomes.R:1374-1383,1429-1472`
and `R/competition/forecast_layer.R:1566-1577`.

**Apply to:** rankings, bands, cuts, stage paths, progression probabilities,
and fixture ledger coverage.

Validate conservation and monotonicity before the writer runs. Dashboard code
must consume already reconciled outputs and must never repair/renormalize them.

## Integration Map

```text
Phase 18 accepted UCL source/current pointer
  -> UCL schedule + canonical match state (36 clubs / 144 fixtures)
  -> Phase 14 universal arithmetic + UCL Article 18 rank/tie trace
  -> Phase 19 fixed production club release + strict pre-kickoff forecast ledger
  -> conditional league simulation + legal UCL draw paths / accepted draw
  -> two-leg/no-away-goals stages + neutral final
  -> reconciled ten-file UCL outcomes bundle + manifest
  -> Phase 21 dashboard input (read-only)
```

The only production inputs are the accepted Phase 18 source bundle and the
internally resolved Phase 19 club release. Provider standings, fixture roots,
national releases, and dashboard calculations are not alternative inputs.

## Must Not Reuse

| Existing pattern | Why it is unsafe for Phase 20 | Required replacement |
|---|---|---|
| `phase14_resolve_approved_release()` and the national arguments in `forecast_layer.R:843-856,1366-1377` | They expose national-domain selector/root parameters and allow the wrong authority domain. | Call `phase19_resolve_production_club_release()` internally; fixed club root, no caller selector/root. |
| `phase19_resolve_fixture_club_release()` or any fixture selector in production | Fixture authority is useful for mechanics but cannot authorize production or overwrite an incumbent. | Temporary fixture helper only; typed `fixture_authority=TRUE`, `production_eligible=FALSE`, no selector publication. |
| `uefa_nl_sim_penalty_winner()`'s random 0.5 fallback (`:328-338`) | Randomness cannot prove Article 18 rank, band membership, or an exact draw path. | Shared unresolved interval / suppressed path; seeded penalty sampling only at an explicitly modeled future knockout penalty boundary. |
| `uefa_nl_draw_quarter_finals()` (`:537-590`) or legacy `R/forecast/tournament.R` fixed traversal/uniform pairing | UCL has rank-constrained pair families, inherited bracket positions, and edition-specific draw conditions. | Versioned UCL draw-policy validator and legal path enumeration; condition exactly on an accepted draw. |
| Any provider `rank`/`band` or alphabetical interim display order | Provider ordering is not recomputed Article 18 evidence; display order cannot decide rank 8/24. | Project-owned rank/tie trace, unresolved interval, and provider reconciliation-only fields. |
| Synthetic schedule/pairing generation from known 36/144 cardinality | It creates fixture identity/lineage that was never accepted. | Require all accepted source rows, stable IDs, kickoff/venue/matchday, and fail closed on missing/contradictory edges. |
| Caller-selectable `output_root`, `trusted_release_root`, `selector_path`, or fixture path | A caller can route a valid-looking candidate into production. | Resolve fixed roots inside the command/targets; test root rejection and protected incumbent bytes. |
| Away-goal tie-break, wrong first-leg host, or two-row final | UCL 2026/27 uses aggregate goals, second-leg ET/penalties, and a neutral single final. | UCL stage policy wrapper around tested two-leg/single-leg primitives. |
| Dashboard-side probability normalization | It hides missing paths and broken stage reconciliation. | Pre-publication validator with typed unresolved/suppressed probabilities. |

## No Analog Found

| File/behavior | Reason |
|---|---|
| `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` | No existing pinned UCL Article 18/19/Annex B evidence artifact; Phase 16's draw-condition shape is the closest contract. |
| UCL Article 18 late-evidence shared intervals and Article 19 legal rank paths | Phase 15/16 provide trace/activation mechanics, but no existing competition implements these UCL-specific rules. Use the pinned research evidence and encode them in the new UCL rules object. |

## Metadata

**Analog search scope:** `R/competition/` Phase 14-18 state/standings/forecast/
source modules; `R/club/` Phase 19 release/authority modules; Phase 15-16
rules/simulation/outcomes modules; current `_targets.R`; scripts and focused
test harnesses under `tests/testthat/`.  
**Pattern extraction date:** 2026-09-21  
**Planning note:** exact UCL module names and test fixture sizes are
discretionary in the phase context, but the authority, identity, cutoff,
inventory, and fail-closed boundaries above are locked.
