# Phase 20 simulation repair contract

This note records the simulation-side trust-boundary changes for CR-02,
CR-05--CR-09 and WR-02.  It is an interface note for the state/outcomes and
targets repairs; it does not make fixture evidence production authority.

## Required inputs

`ucl_run_simulation()` now requires a strict UTC
`information_cutoff_utc` (`YYYY-MM-DDTHH:MM:SSZ`).  Missing, malformed, or
2099+ sentinel cutoffs return a typed `ucl_simulation_run` with
`status = "blocked"`.  A ledger must be an `ucl_forecast_ledger` containing
one row for every validated graph fixture and these top-level fields:

* `canonical_hash_version = "phase18-canonical-v2"`;
* non-empty `graph_sha256`, `source_bundle_id`, `state_cutoff_utc`, and
  `table_sha256` values (the state cutoff must equal the run cutoff);
* `ledger`, whose rows carry the exact fixture-forecast schema and
  `ucl20-forecast-ledger-row-v1` Phase 18 row hashes; the table hash uses
  `ucl20-forecast-ledger-v1`;
* non-empty `model_release_id`, `model_sha256`, and `calibrator_sha256`
  matching the one release/model/calibrator identity in available rows, with
  64-hex model and calibrator hashes; feature cutoffs must precede both kickoff
  and the run information cutoff.

An accepted draw must be same-edition and same-source-bundle, have one source
artifact lineage ID shared by all 16 pairings, exactly eight play-off and
eight round-of-16 rows, the exact `playoff-01..08` and `r16-01..08` path
inventory, all required bracket/seed slots and venues, and a complete 36-club
rank permutation.  The supplied rank and draw hashes are recomputed using
`ucl20-accepted-draw-ranks-v1` and `ucl20-accepted-draw-pairings-v1`, then
bound by `ucl20-accepted-draw-v1`.

## Public interface additions

* `ucl_aggregate_rank_distributions(simulation, rules = NULL, club_ids = NULL)`
  requires authoritative 36-club IDs (from the simulation/state or explicit
  `club_ids`) and validates one complete rank permutation per iteration.
* `ucl_aggregate_stage_events(..., required_stage_ids = NULL)` accepts either
  `status` or durable `path_status`; when both are present they must agree.
  Supplying `stage_inputs` requires exact event counts, rather than imputing
  missing rows as resolved/unresolved.
* `ucl_validate_progression_reconciliation(..., required_stage_ids = NULL)`
  requires explicit status and can require the full stage inventory.

## Simulation output fields consumed downstream

Ready or typed-unresolved runs include `stage_events` (also exposed as the
complete durable `knockout_paths` table; `legal_paths` retains the 16-row
draw/path conditioning seam),
`stage_reconciliation`, `progression_probabilities`,
`progression_reconciliation`, `club_ids`, `graph_sha256`, `state_sha256`, and
`metadata` with the full graph hash, full state hash, `ledger_sha256`, model/calibrator identity,
cutoff, algorithm version, stage-event count, and progression-row count.
Accepted draws generate all 24 stage rows (play-off, round of 16, quarter-final,
semi-final, final, champion); without score evidence those rows remain typed
`unresolved` with `knockout_score_evidence_missing`.  Missing/foreign/partial
draw evidence generates the complete stage inventory as typed `suppressed`
rows and never fabricates a bracket.

## Verification

Fresh adversarial coverage is in
`tests/testthat/test_phase20_simulation_review.R` and runs with:

```sh
rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_simulation_review.R", reporter="summary", stop_on_failure=TRUE)'
```
