---
phase: 20-ucl-rules-state-and-tournament-outcomes
reviewed: 2026-09-22T00:16:26Z
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
  critical: 3
  warning: 3
  info: 0
  total: 6
status: issues_found
---

# Phase 20: Code Review Re-review

**Reviewed:** 2026-09-22T00:16:26Z  
**Depth:** deep  
**Files Reviewed:** 16  
**Status:** issues_found

## Summary

The five focused Phase 20 suites pass, and the repaired validators reject the original shallow mutations (partial draws, stale hashes, cutoff equality, unsafe result flags, and incomplete inventories). A clean adversarial pass still found three blocker-level trust/orchestration defects and three warnings. The most serious defect is that `ucl_validate_outcome_candidate()` accepts state, graph, ledger, progression, and run-identity mutations after simulation; it only validates the resulting output shapes and model-lineage strings, not that the components belong to the same hashed run.

Production authority is still correctly fail-closed in the current checkout. The default CLI returned typed `production_human_needed / phase18_authority_missing`. The Phase 19 resolver still exposes no `forecast_rows`, and the official 2026/27 draw evidence remains explicitly unaccepted; these are external authority prerequisites, not counted as Phase 20 implementation findings below.

## Re-test disposition for the original review

| Original ID | Disposition | Evidence |
|---|---|---|
| CR-01 | Fixed at the supplied-artifact boundary | Candidate validation recomputes every registered artifact and compares supplied hashes before manifest validation. |
| CR-02 | Fixed for structural/content mutations; authority residual is CR-18 | Partial, stale, duplicate-rank, forged-participant, and contradictory draw probes return typed unresolved results. |
| CR-03 | Fixed | State ledger reconstruction preserves completed rows and rejects identity/content tampering in the focused state suite. |
| CR-04 | External blocker, not a new Phase 20 defect | `phase19_resolve_production_club_release()` still returns model/calibrator metadata without `forecast_rows`; the production seam returns `phase19_forecast_rows_missing`. |
| CR-05 | Fixed for production | Production requires an explicit validated cutoff and strict feature/kickoff inequalities; the fixture default is mechanics-only and non-promotable. |
| CR-06 | Partially fixed; component-binding residual is CR-17 | Simulation run IDs now include state, ledger, draw, seed, count, cutoff, and algorithm hashes, but the candidate validator does not enforce those identities after the run is supplied. |
| CR-07 | Fixed at simulation entry; component-binding residual is CR-17 | Direct simulation with a foreign or stale ledger blocks on graph/table/lineage hashes. |
| CR-08 | Fixed | Rank aggregation rejects incomplete club inventories and non-permutations; accepted-draw validation requires all 36 ranks. |
| CR-09 | Fixed for inventory/reconciliation; unresolved-value residual is WR-07 | Stage validation requires all 24 events and all eight progression rows per club; unresolved numeric probabilities are still accepted. |
| CR-10 | Fixed fail-closed | Missing Phase 14 authority cannot promote the fixture fallback; current missing authority remains typed/external. |
| CR-11 | Fixed at graph construction; component-binding residual is CR-17 | Full graph table hashes and source-lineage evidence are checked, but a caller can mutate the graph after simulation and pass candidate validation. |
| CR-12 | Fixed from pass-through structure; orchestration residuals are CR-19/WR-08 | The exact ten targets and fifteen edges are executable, but the draw input is dropped and target exceptions are swallowed. |
| CR-13 | Fixed for result-contract hashes; replay residual is WR-06 | The result preserves ten hashes and verifies them against artifact bytes, but the CLI replay calls the builder twice with identical inputs. |
| CR-14 | Fixed | `phase20_result_contract()` forces unsafe promotion/selector/incumbent flags false and converts invalid status/flags into an unexpected failure. |
| CR-15 | Fixed | Empty/zero-exit unexpected failures are rejected and receive a non-zero exit code plus a reason. |
| CR-16 | Fixed resolver wiring; current authority is external | The no-graph builder resolves the fixed Phase 18 reader and returns typed `phase18_authority_missing` when no accepted current source exists. |
| WR-01 | Fixed | Ledger validation rejects mixed model/calibrator/release identity across available rows. |
| WR-02 | Fixed | Framed canonical sequence hashing distinguishes delimiter-collision counterexamples. |
| WR-03 | Fixed | Rules evidence is pinned to the sidecar digest and validated against the exact evidence schema/URL set. |
| WR-04 | Fixed | Public parser rejects negative seeds, malformed cutoffs, conflicting modes, and unknown/root-override options. |
| WR-05 | Not green; external/historical regression blocker | The executable Phase 14 standings suite still fails at `test_phase14_standings.R:686` on a temporary schema-v2 row-names mismatch; parse/declaration smoke is not treated as success. |

## Critical Issues

### CR-17: Candidate components are not bound to the simulation run

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_outcomes.R:623-696`  
**Issue:** `ucl_validate_outcome_candidate()` rebuilds output tables from the caller's `state`, `ledger`, and `simulation`, but only checks the ledger's model-lineage strings. It never verifies that the supplied state graph, state hash, ledger table/hash, simulation ledger, simulation metadata, progression, or `run_id` are the same inputs used to produce the simulation. The simulation already emits the needed `graph_sha256`, `state_sha256`, `ledger_sha256`, and run identity at `R/competition/uefa_champions_league_simulation.R:737-750,790-816`, but the outcome validator does not consume them.

Fresh counterexamples built a valid fixture state/ledger/simulation and then independently changed `ledger$ledger$prob_home[1]`, `state$standings$rank[1]`, `state$graph$fixtures$venue_id[1]`, `simulation$progression_probabilities$probability[1]`, or `simulation$run_id`. Every mutated candidate returned `valid=TRUE` with `status=unresolved_draw_procedure`. The emitted forecast table therefore can contain bytes that were not used by the simulation while retaining the old simulation ledger/run identity. This is a post-validation artifact-substitution and state/run identity vulnerability, even though fixture outputs remain non-promotable.

**Fix:** Revalidate the candidate graph/schedule and ledger at this boundary, recompute their canonical graph/state/table hashes, and require equality with `simulation$metadata` and `simulation$ledger` (including run identity). Reject any candidate whose state, graph, ledger, progression, stage events, or metadata is not the exact bound run; do not merely recalculate row hashes over substituted values.

### CR-18: A self-consistent caller draw bypasses the unaccepted official draw evidence

**Classification:** BLOCKER  
**File:** `R/competition/uefa_champions_league_simulation.R:976-1033`  
**Issue:** `ucl_validate_draw_artifact()` verifies the caller's shape, rank permutation, legal pair families, and self-recomputed hashes, but it never requires the draw artifact to be present in trusted Phase 18/source-bundle evidence or requires the rules evidence row to be accepted and complete. `ucl20_build_outcomes()` accepts a caller-provided `draw_artifact` and passes it directly to simulation at `R/competition/uefa_champions_league_outcomes.R:889-907,936`.

Fresh probe result: `.ucl_rule_contract()$evidence` reports `draw_procedure_2026_27` as `accepted=FALSE, complete=FALSE`, while `ucl_validate_draw_artifact(phase20_fixture_accepted_draw(), rules=.ucl_rule_contract(), source_bundle_id=...)` returns `status=accepted`. The draw's `source_artifact_ids` is only a free-form caller string and can be rehashed along with fabricated pairings. If Phase 18/19 authority becomes available, this lets a caller force an arbitrary internally-consistent draw through the production builder despite the still-unaccepted official procedure.

**Fix:** In production, resolve the draw only from a fixed, source-backed accepted artifact whose ID/content hash is recorded in the accepted Phase 18 bundle and whose rules evidence is `accepted=true, complete=true`. Reject caller-supplied production draw objects and retain fixture draw objects as explicitly non-promotable mechanics inputs. Bind the trusted draw identity/source hash into the run and manifest.

### CR-19: The executable target/CLI pipeline drops every accepted draw

**Classification:** BLOCKER  
**File:** `_targets.R:374-393,444-470`  
**Issue:** `phase20_ucl_target_rules()` returns only the rules/evidence contract; it does not resolve or carry a draw artifact. `phase20_ucl_target_simulation()` omits `draw_artifact` when calling `ucl_run_simulation()`, and `phase20_ucl_target_paths()` hardcodes `draw_artifact = NULL`. The fixed CLI's replay/builder calls likewise pass no draw artifact (`scripts/build_uefa_champions_league_outcomes.R:367-373`). Consequently, even after the official draw evidence is accepted, the production target graph has no route for the accepted pairings to reach simulation/path enumeration; exact paths remain unresolved/pre-draw forever.

**Fix:** Add a trusted accepted-draw resolution/input to the production authority boundary and carry it through the target namespace into simulation and path enumeration. Keep the current typed `missing_edition_draw_procedure` result until that input is accepted, then pass the exact same source-bound artifact to both consumers and bind its hashes.

## Warnings

### WR-06: Replay-check repeats the same call instead of testing reordered input

**Classification:** WARNING  
**File:** `scripts/build_uefa_champions_league_outcomes.R:367-379`  
**Issue:** `phase20_ucl_candidate_replay()` calls the builder twice with identical arguments. The CLI help promises normal/reversed/repeated canonical identity checks, but no reversed fixture/input order is supplied, so ordering-dependent regressions can pass the replay gate.

**Fix:** Run the normal, semantically reversed-input, and repeated builds and compare all ten artifact hashes plus the typed result contract for each run. The reversed input must exercise the actual source/row ordering boundary rather than simply repeating the same call.

### WR-07: Unresolved progression rows may carry numeric probabilities

**Classification:** WARNING  
**File:** `R/competition/uefa_champions_league_outcomes.R:596-619`; `R/competition/uefa_champions_league_simulation.R:1321-1324`  
**Issue:** Validation checks bounds for finite probabilities and only requires non-missing values for `resolved` rows. A fresh probe changed an `unresolved` progression row's `NA` probability to `0.99`; candidate validation still returned `valid=TRUE`. A downstream consumer that ignores the status column can mistake unresolved evidence for a real probability.

**Fix:** Require `probability=NA` for `unresolved`, `suppressed`, and `blocked` rows (and finite `[0,1]` values only for `resolved` rows), then recompute/reject the row hash after that semantic check.

### WR-08: Target exceptions are converted to empty data frames

**Classification:** WARNING  
**File:** `_targets.R:466-472,484-498`  
**Issue:** Path enumeration and stage aggregation catch all errors and return an empty data frame while retaining the upstream status. A real path/aggregation failure can therefore look like a successful/unresolved target until a later, unrelated validator notices it; this loses the original failure reason and makes target diagnostics false-green at the node boundary.

**Fix:** Return a typed `phase20_ucl_target_blocked()` value with the caught reason/message and propagate it through `ucl20_build_status`; never replace an execution error with an empty successful-looking table.

## External authority and regression blockers (not counted as Phase 20 implementation findings)

- Phase 18 currently has no accepted current UCL source. The fixed CLI and default builder correctly return `production_human_needed` with `phase18_authority_missing`, without mutating protected bytes.
- Phase 19's resolver currently returns no `forecast_rows`; production ledger construction therefore correctly stops at `phase19_forecast_rows_missing`. This is the outstanding Phase 19 release-contract seam, not evidence that Phase 20 should fabricate rows.
- The exact 2026/27 organiser draw procedure remains unavailable. The rules sidecar correctly retains `accepted=false`, `complete=false`, and `missing_edition_draw_procedure`; production must remain unresolved until trusted evidence exists. CR-18/CR-19 are implementation defects because the current code would not enforce/use that authority once it arrives.
- The aggregate verifier reached the executable Phase 14 regressions but could not be green: `tests/testthat/test_phase14_standings.R:686` fails on a temporary schema-v2 `row.names` attribute mismatch. This known historical/resource failure is not reported as a Phase 20 implementation defect.

## Validation evidence

All five required Phase 20 suites were run in fresh R processes and passed:

```text
tests/testthat/test_uefa_champions_league.R
tests/testthat/test_phase20_state_authority_review.R
tests/testthat/test_phase20_simulation_review.R
tests/testthat/test_phase20_outcomes_wiring_review.R
tests/testthat/test_phase20_adversarial_regression.R
```

Additional probes covered partial/forged/foreign/duplicate-rank draws, delimiter-collision hashes, negative seed/conflicting CLI modes, candidate artifact and component mutations, accepted-draw evidence mismatch, and the default production source path. The direct Phase 14 standings run failed as documented above; it was not counted as regression success.

---

_Reviewed: 2026-09-22T00:16:26Z_  
_Reviewer: the agent (gsd-code-reviewer, independent Phase 20 re-review)_  
_Depth: deep_
