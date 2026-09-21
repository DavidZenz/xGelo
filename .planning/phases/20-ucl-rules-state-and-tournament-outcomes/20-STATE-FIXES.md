# Phase 20 state/authority repair handoff

The state-side repair is implemented by commits `e1cebf3` and `6601c2c`.

## Interfaces consumed by later outcomes/simulation/targets work

- `ucl_build_state(source, rules = NULL, state_cutoff_utc = NULL, ...)` now
  requires an explicit UTC `state_cutoff_utc` in `YYYY-MM-DDTHH:MM:SSZ` form.
  Missing, malformed, and `2099`-style sentinel cutoffs return a typed
  `ucl_blocked_state`; a fixture-only Phase 14 fallback is marked
  `standings_authority = "fixture_fallback_non_promotable"` and never carries
  production eligibility.
- `ucl_build_forecast_ledger(...)` binds its
  `information_cutoff_utc`/`state_cutoff_utc` metadata to the explicit cutoff.
  Missing or invalid cutoffs return class
  `c("ucl_forecast_ledger", "ucl_blocked_state", "list")` with
  `status = "production_blocked"`, a typed `reason_code`, and `ledger = NULL`
  (never an empty production ledger).
- A production release must come from the Phase 19 resolver and contain a
  validated `forecast_rows` seam with one exact row per fixture and one
  release/model/calibrator lineage. A resolver result with model/calibrator
  metadata but no rows returns `reason_code = "phase19_forecast_rows_missing"`.
  Caller-supplied production-shaped releases cannot bypass the resolver.
- Valid ledger results expose `release_id`, `model_sha256`,
  `calibrator_sha256`, `information_cutoff_utc`, `state_cutoff_utc`, and
  `forecast_row_seam = "phase19_release_forecast_rows"`; blocked results expose
  the same cutoff fields as `NULL` and `forecast_row_seam = "suppressed"` is
  not emitted because no ledger is returned.
- `ucl_validate_schedule()` derives `source_bundle_id`, source lineage, and
  authority flags from validated fixture/source evidence. Forged caller
  metadata returns a typed blocked state. `graph_sha256` is Phase 18 framed-v2
  content identity over complete clubs/fixtures tables and authority metadata,
  including lifecycle, scores, standings inclusion, and bundle hash.
- Completed prior rows are reused only after full identity/schema/lineage,
  cutoff, probability/xG/status, and canonical row-hash validation. Production
  rows use framed-v2 row hashes; legacy row hashes are accepted only for
  explicitly marked non-promotable fixture evidence.

The dedicated adversarial coverage is in
`tests/testthat/test_phase20_state_authority_review.R`. The state test file
passes. The pre-existing focused suite has four failures in the simulation and
outcomes seams (the parent agents own those files); the state tests do not
introduce additional failures.
