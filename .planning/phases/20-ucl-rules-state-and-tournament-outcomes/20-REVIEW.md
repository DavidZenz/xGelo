---
phase: 20-ucl-rules-state-and-tournament-outcomes
reviewed: 2026-09-21T20:54:42Z
depth: deep
files_reviewed: 16
files_reviewed_list:
  - _targets.R
  - R/competition/uefa_champions_league_rules.R
  - R/competition/uefa_champions_league_state.R
  - R/competition/uefa_champions_league_simulation.R
  - R/competition/uefa_champions_league_outcomes.R
  - scripts/build_uefa_champions_league_outcomes.R
  - scripts/verify_phase20_contracts.R
  - tests/testthat/helper_uefa_champions_league.R
  - tests/testthat/test_uefa_champions_league.R
  - tests/testthat/test_phase20_adversarial_regression.R
  - data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json
  - R/common/phase18_canonical_hash.R
  - R/competition/ucl_source_acceptance.R
  - R/competition/ucl_source_bundle.R
  - R/competition/ucl_source_refresh.R
  - R/club/release.R
findings:
  critical: 16
  warning: 5
  info: 0
  total: 21
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-09-21T20:54:42Z  
**Depth:** deep  
**Files Reviewed:** 16  
**Status:** issues_found

## Summary

The focused suites and aggregate verifier pass, but the implementation has multiple trust-boundary and false-green defects. In particular, supplied artifacts, accepted draws, prior ledgers, and simulation ledgers are not bound to the validated inputs; production paths are not wired to the Phase 19 release contract; and the target/verifier layers can report success without executing or validating the outcome computation. Exact knockout paths therefore cannot be trusted, and the implementation is not safe to ship.

## Critical Issues

### CR-01: Caller-supplied artifact bundles replace the computed candidate

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:372-382`

**Issue:** `ucl_validate_outcome_candidate()` computes `expected_artifacts`, but when `candidate$artifacts` is present it validates that caller-owned list instead. The table validator checks schemas, row hashes, and a few cardinalities, but never compares supplied tables with the computed tables or verifies each manifest `artifact_sha256` against the corresponding table. A caller can alter a projected ranking, recompute that row hash, leave the manifest self-consistent, and receive `valid = TRUE`.

**Fix:** Reject supplied artifacts at this boundary, or compare every supplied table to the freshly computed table and require manifest artifact hashes to equal the recomputed table hashes before accepting the candidate.

### CR-02: Accepted draws can be partial, forged, or rank-incomplete

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_simulation.R:351-375`

**Issue:** The validator accepts any nonempty set of unique `path_id` rows; it does not require the complete playoff/R16 inventory, unique coverage of all 36 clubs, or a complete bracket. `draw_artifact_sha256` and `rank_input_sha256` are only checked for a 64-hex shape, never recomputed. `rank_inputs$club_id` is not checked for uniqueness or exact coverage, and `source_artifact_ids` are not required to be nonempty or tied to the accepted source. `ucl_enumerate_legal_knockout_paths()` then returns the caller’s pairings unchanged and only compares the intersection of ranking IDs (`:311-321`).

**Fix:** Recompute both hashes from canonical content, require the exact 36-club permutation and expected pairing/cardinality inventory, require complete source-artifact lineage, and compare the full current ranking set (not an intersection).

### CR-03: Completed prior forecast bytes are trusted after identity-only matching

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_state.R:423-440`

**Issue:** For a completed fixture, any prior row with the same six identity fields is returned verbatim. Its probabilities, model hashes, status, source lineage, and `row_sha256` are not validated or recomputed. A tampered prior row can therefore inject invalid probabilities or stale model output while preserving an old row hash.

**Fix:** Validate the prior row against the full ledger schema and canonical row hash, require the accepted release/model/calibrator lineage, and reject rather than reuse any row whose immutable bytes do not verify.

### CR-04: The production ledger cannot consume the Phase 19 release resolver

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_state.R:477-488`; `R/club/release.R:1373-1377`

**Issue:** Phase 20 extracts production forecast rows only from `chosen$forecast_rows` or `chosen$forecasts`. The Phase 19 production resolver returns `model`, `calibrator`, and `metadata`, but no forecast rows. Consequently a valid production release produces an empty `release_rows` table and suppresses every normal fixture as `insufficient_model_evidence`; the advertised production outcome path can never produce forecasts.

**Fix:** Add a trusted Phase 19 forecast-generation seam that consumes the resolved model/calibrator and emits validated rows, or change the Phase 19 resolver contract to return source-backed forecast rows and validate that contract before ledger construction.

### CR-05: The information cutoff is optional and is not enforced during sampling

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_simulation.R:113-131`; `scripts/build_uefa_champions_league_outcomes.R:360-369`; `R/competition/uefa_champions_league_outcomes.R:456-466`

**Issue:** Sampling checks only `feature_cutoff_utc < kickoff_utc`; the `cutoff_utc` argument is stored and returned but never compared with kickoff. The fixed CLI explicitly passes `information_cutoff_utc = NULL`, and the builder uses a 2099 sentinel for state construction. A fixture before the requested information cutoff can therefore be sampled as open, allowing future information into a simulation.

**Fix:** Require one valid UTC cutoff for every run, reject sentinel/future defaults, and enforce `information_cutoff_utc < kickoff_utc` for every sampled fixture (with the same cutoff bound into the ledger and run identity).

### CR-06: Graph and run identities omit semantic inputs

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_state.R:165-168`; `R/competition/uefa_champions_league_simulation.R:194-205`

**Issue:** `graph_sha256` hashes only fixture identities, schedule metadata, and source references; lifecycle status, completion method, scores, standings inclusion, and source bundle are absent. `run_id` then hashes that incomplete graph hash plus rules/seed/count/cutoff, but omits the forecast ledger, model/calibrator hashes, and accepted draw identity. Different forecasts or changed settled scores can therefore receive the same replay identity.

**Fix:** Hash the complete validated graph and a canonical, validated ledger/draw payload (including release and artifact hashes) into both `graph_sha256` and `run_id`.

### CR-07: Simulation accepts an untrusted arbitrary ledger

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_simulation.R:194-205`

**Issue:** `ucl_run_simulation()` accepts any data frame as `ledger_table`. Sampling checks only fixture ID, status, feature cutoff, and a score grid (`:116-131`); it does not require a `ucl_forecast_ledger`, verify row hashes, source bundle, model/calibrator lineage, or exact coverage. A caller can drive production-shaped simulation samples with foreign forecast rows without crossing any validation boundary.

**Fix:** Require the validated ledger class/contract, verify one row per graph fixture and every row hash/lineage field, and reject any ledger whose source bundle, release, cutoff, or graph hash does not match the run.

### CR-08: Rank aggregation silently accepts missing clubs and invalid permutations

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_simulation.R:238-269`

**Issue:** The aggregation derives its club set from whatever rows are present and only checks each observed club’s row count against the number of iterations. It never requires the expected 36-club set, exactly one row per club/iteration, unique ranks, or ranks 1–36. A run missing one club can return `status = "ready"` with a 35-club distribution.

**Fix:** Pass the authoritative club IDs from the validated state and require every iteration to be a complete rank permutation before calculating any probabilities.

### CR-09: Outcome validation ignores stage-event validity and permits incomplete progression

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:385-392`; `R/competition/uefa_champions_league_simulation.R:581-622,625-666`

**Issue:** The candidate builder computes `stage_events` but never inspects its `valid` attribute or `errors`. It only adds progression errors when a nonempty progression table is invalid, so an empty/missing progression can pass. The standalone progression validator accepts a one-row resolved progression with no stage inputs, and stage aggregation treats a missing status column as all `resolved`. An incomplete knockout result can therefore be reported as mechanically complete.

**Fix:** Require exact stage inventories and conservation counts, reject missing/invalid stage-event results, require complete per-club progression rows and authoritative stage inputs, and propagate all reconciliation errors into `failures`.

### CR-10: Missing Phase 14 authority silently falls back to a new standings implementation

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_state.R:304-324`

**Issue:** `.ucl_state_source_phase14()` may fail to load the Phase 14 standings function, but `ucl_build_state()` then calls `.ucl_state_fallback_standings()` instead of returning a typed blocked state. This bypasses the declared Phase 14 authority and can change score/lifecycle/tie semantics while still producing a ready state.

**Fix:** Treat absence or load failure of `phase14_compute_standings` as a production blocker. Keep any fallback fixture helper explicitly outside the production entry point and mark it non-promotable.

### CR-11: Caller-provided graph lineage metadata is not bound to fixture evidence

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_state.R:223-240`

**Issue:** Validation checks that fixture rows share one bundle, but then preserves a caller-supplied `graph$source_bundle_id`, `source_lineage_id`, `authority_mode`, and eligibility flags even when they disagree with the fixture rows. Only a missing bundle is filled from the first fixture. A graph with a forged bundle ID is accepted and carries that ID into all downstream artifacts.

**Fix:** Derive lineage and authority exclusively from validated fixture/source-bundle evidence; reject any caller metadata that is present but differs, and validate the complete Phase 18 bundle hash before constructing the graph.

### CR-12: The Phase 20 targets are pass-through nodes, not an executable outcome pipeline

**Classification:** BLOCKER  
**File:** `_targets.R:1691-1777`

**Issue:** `ucl20_forecast_ledger` merely passes through `ucl20_state`; every downstream target similarly passes through the prior object or returns the first typed issue. None calls `ucl_build_forecast_ledger()`, `ucl_run_simulation()`, `ucl_validate_outcome_candidate()`, `ucl_outcomes_manifest()`, or the writer. The verifier only checks target names and lexical parent references (`scripts/verify_phase20_contracts.R:155-195`), so the declared ten-target graph can be green without executing any outcome computation.

**Fix:** Wire each target to the corresponding production function, preserve the source/release/draw dependencies, and add an executable target-level assertion that output artifacts and their manifest were actually built and validated.

### CR-13: The aggregate replay gate is false-green because the result contract drops hashes

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:433-439,467-472`; `scripts/verify_phase20_contracts.R:333-357`

**Issue:** `ucl20_build_outcomes()` computes `candidate$artifact_hashes` but returns `phase20_result_contract()`, whose implementation ignores `...` and has no `artifact_hashes` field. The verifier consequently compares three `NULL` values and prints `byte_identical=true`; it never proves that normal, reversed, and repeated fixture outputs are identical.

**Fix:** Preserve the nonempty artifact-hash vector in the result contract and make the gate reject missing hashes before comparing them; alternatively compare the canonical artifacts/manifests directly.

### CR-14: The public result contract accepts unsafe production flags

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:433-440`

**Issue:** Callers can invoke `phase20_result_contract(status = "mechanics_complete", production_eligible = TRUE, selector_changed = TRUE, incumbent_changed = TRUE)` and receive those unsafe flags unchanged with exit code 0. The flags are rejected only by downstream verifier helpers, not at the contract boundary, so any consumer using the public result directly can treat an untrusted result as promotable.

**Fix:** Hard-code `production_eligible = FALSE`, `selector_changed = FALSE`, and `incumbent_changed = FALSE` in this constructor, or require an unforgeable internal authority object and reject caller-supplied `TRUE` values.

### CR-15: Unexpected failures can be represented as successful, empty contracts

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:434-439`; `R/competition/uefa_champions_league_outcomes.R:443-451`

**Issue:** `phase20_result_contract(status = "unexpected_failure")` permits `exit_code = 0` and empty `failures`, while `phase20_verify_contracts()` explicitly allows zero exit status for that state. The aggregate result validator likewise checks only that the status is in the allowed set. An unexpected failure can therefore be reported as a zero-failure gate result.

**Fix:** Require a nonzero exit code and at least one failure/unexpected-failure reason for `unexpected_failure`, and make every verifier reject an empty unexpected-failure result.

### CR-16: The production builder does not resolve the accepted Phase 18 source when no graph is supplied

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:455-466`

**Issue:** The default `ucl20_build_outcomes(graph = NULL)` calls only the Phase 19 club resolver and immediately returns a parent-reason contract. It never calls `phase18_read_ucl_refresh_current()` or constructs the accepted UCL graph. Thus the public fixed production builder cannot run even when a valid Phase 18 current source exists; the script has a separate workaround, and the targets never call the builder at all.

**Fix:** Make the production entry point resolve and validate the fixed Phase 18 current bundle, then resolve Phase 19 and build the graph before entering the common pipeline. Keep the graph argument as an explicitly fixture-only internal seam.

## Warnings

### WR-01: Model and calibrator lineage is silently mixed and reduced to the first row

**Classification:** WARNING  
**File:** `R/competition/uefa_champions_league_outcomes.R:339-346`; `R/competition/uefa_champions_league_state.R:488-496`

**Issue:** The ledger builder does not require one release/model/calibrator identity across all rows. Metadata uses `unique(...)[1L]`, so a mixed ledger is labeled with whichever identity happens to sort first while row-level values differ.

**Fix:** Require exactly one non-missing release ID and matching model/calibrator hashes across all rows, and compare them with the trusted release manifest before building metadata.

### WR-02: Custom delimiter hashing is not collision-safe canonicalization

**Classification:** WARNING  
**File:** `R/competition/uefa_champions_league_rules.R:27-45`; `R/competition/uefa_champions_league_state.R:25-28,165-168`; `R/competition/uefa_champions_league_simulation.R:9-12`; `R/competition/uefa_champions_league_outcomes.R:3-33`

**Issue:** Hash inputs are joined with raw `\x1f`, `\x1e`, `\x1c`, or `|` delimiters without length/type framing or escaping. Schedule/source IDs are only required to be nonempty, so distinct values containing delimiters can produce identical graph, run, or artifact hashes. This also differs from the Phase 18 length-prefixed canonical-v2 contract while output metadata calls the format canonical-v2.

**Fix:** Reuse the Phase 18 framed canonical encoder for all cross-module identities, or reject control delimiters and document a collision-resistant format with test vectors.

### WR-03: Rules evidence hashes are accepted as shape-only claims

**Classification:** WARNING  
**File:** `R/competition/uefa_champions_league_rules.R:110-134`

**Issue:** The rules loader checks that `raw_sha256` and `canonical_sha256` look like 64-hex strings, but never recomputes them from an immutable artifact or verifies a pinned sidecar digest. A changed sidecar can therefore assert new review/acceptance metadata without an integrity failure.

**Fix:** Pin and verify the sidecar hash, or require the reviewed raw/canonical bytes through the Phase 18 evidence contract before accepting the ruleset.

### WR-04: The public argument parser has weaker safety invariants than the fixed CLI

**Classification:** WARNING  
**File:** `R/competition/uefa_champions_league_outcomes.R:410-430`

**Issue:** `ucl20_parse_args()` permits `--write --dry-run` together (the later flag silently wins) and accepts negative seeds. The script parser rejects both conditions, so callers using the public parser get different mode and seed semantics from the shipped CLI.

**Fix:** Share one parser, reject mutually exclusive modes, and enforce the same non-negative integer seed range in both entry points.

### WR-05: Historical regression claims are parse/declaration smoke tests, not regressions

**Classification:** WARNING  
**File:** `scripts/verify_phase20_contracts.R:361-407`

**Issue:** `phase20_gate_run_regressions()` parses Phase 14–16 files and checks that they contain `test_that(`, then prints `phase14_15_16=true phase18=true`. It does not execute those tests or the Phase 18 verifier. The final `PHASE20_GATE_OK` still reports zero warnings, which can be consumed as a full regression pass.

**Fix:** Execute the selected suites in isolated processes and fail on results, or label the output as smoke-only and do not emit a green regression claim.

---

_Reviewed: 2026-09-21T20:54:42Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_
