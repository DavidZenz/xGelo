---
phase: 20-ucl-rules-state-and-tournament-outcomes
verified: 2026-09-21T20:51:32Z
status: gaps_found
score: 3/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Knockout projections use only legal rank-constrained and accepted draw-conditioned paths."
    status: failed
    reason: "ucl_validate_draw_artifact accepts an accepted/complete draw with only one pairing and arbitrary 64-hex draw/rank-input hashes; it does not enforce the complete expected pairing set or bind hashes to content."
    artifacts:
      - path: "R/competition/uefa_champions_league_simulation.R"
        issue: "ucl_validate_draw_artifact validates schema and local row legality, but not complete stage cardinality/coverage or content hashes."
      - path: "R/competition/uefa_champions_league_outcomes.R"
        issue: "The candidate boundary can therefore treat a partial accepted draw as valid mechanics input."
    missing:
      - "Require the complete editioned draw topology and participant coverage before accepted status."
      - "Recompute and verify draw_artifact_sha256 and rank_input_sha256 from canonical content."
  - truth: "Each club's stage probabilities reconcile and remain monotone through champion."
    status: failed
    reason: "ucl_run_simulation returns rank rows and knockout paths but never emits progression_probabilities or executes stage transitions; the outcomes fallback produces league bands and unresolved rows only. An accepted-draw fixture run produced only direct_round_of_16, knockout_play_off, and eliminated stages."
    artifacts:
      - path: "R/competition/uefa_champions_league_simulation.R"
        issue: "No progression/stage-event construction is wired into ucl_run_simulation."
      - path: "R/competition/uefa_champions_league_outcomes.R"
        issue: "ucl_out_progression derives only three league bands unless an absent simulation field is supplied; candidate validation does not require champion-stage rows."
    missing:
      - "Simulate and persist every knockout stage through champion, with stage input conservation and per-club monotonicity enforced on the generated output."
  - truth: "Repeated simulations with identical accepted inputs produce byte-equivalent, tamper-resistant outcome artifacts whose identity binds all accepted inputs."
    status: failed
    reason: "The validator checks self-consistent row hashes but does not compare supplied artifact tables to the state-derived tables or manifest artifact hashes. A projected-standings value can be changed, its row hash recomputed, and the candidate still validates. The run ID hashes schedule identity fields but excludes settled scores/lifecycle state and model/draw content hashes."
    artifacts:
      - path: "R/competition/uefa_champions_league_state.R"
        issue: ".ucl_state_graph_hash excludes lifecycle and score fields."
      - path: "R/competition/uefa_champions_league_simulation.R"
        issue: "run_id is based on graph hash, ruleset, source bundle, seed, simulation count, and cutoff only."
      - path: "R/competition/uefa_champions_league_outcomes.R"
        issue: "Artifact validation accepts supplied, internally rehashed payloads without semantic/manifest-to-table comparison."
    missing:
      - "Bind run identity to the canonical accepted state, model release, draw artifact content, and algorithm/version inputs."
      - "Rebuild or semantically compare every artifact and verify manifest artifact hashes against the actual tables before acceptance."
  - truth: "The isolated ten-target UCL namespace executes the ledger, simulation, legal paths, stage events, and outcome publication seams."
    status: failed
    reason: "The target names and fifteen static edges exist, but downstream target bodies call phase20_ucl_target_passthrough instead of ucl_build_forecast_ledger, ucl_run_simulation, path/event builders, or outcome construction. With a future accepted source, the graph would carry state rather than build the advertised artifacts."
    artifacts:
      - path: "_targets.R"
        issue: "ucl20_forecast_ledger, ucl20_league_simulation, ucl20_knockout_paths, ucl20_stage_events, ucl20_outcome_candidate, and ucl20_outcome_manifest are pass-through/issue propagation bodies."
    missing:
      - "Wire each target to its corresponding Phase 20 implementation and preserve typed blocked/unresolved propagation around those calls."
---

# Phase 20: UCL Rules, State, and Tournament Outcomes Verification Report

**Phase Goal:** Users can inspect a rules-correct Champions League state and replayable probabilities from the league phase through the final.

**Verified:** 2026-09-21T20:51:32Z

**Status:** gaps_found

**Re-verification:** No — initial verification (no prior `20-VERIFICATION.md`).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Users can inspect all 36 clubs, qualification bands, and Article 18 decisive/unresolved tie evidence. | ✓ VERIFIED (mechanics) | `R/competition/uefa_champions_league_rules.R:139-203` contains the editioned 36/144 contract, exact Article 18/Annex B criterion order, bands, and evidence sidecar; `R/competition/uefa_champions_league_state.R:191-245,305-351` validates/builds the state and applies Article 18. The 63-test focused suite and aggregate verifier passed. Production inspection remains externally blocked by the absent accepted Phase 18 source. |
| 2 | Every club has an accepted eight-opponent schedule and a cutoff-safe immutable pre-kickoff forecast when covered by an approved release. | ✓ VERIFIED (mechanics) | `ucl_validate_schedule` enforces 36 clubs/144 fixtures, eight distinct opponents, 4/4 home-away, matchdays, venues, confirmed kickoff, lifecycle and score semantics; `ucl_build_forecast_ledger` creates one row per fixture and reuses completed prior bytes (`R/competition/uefa_champions_league_state.R:431-510`). Focused tests and adversarial mutations passed. No accepted production schedule/release is currently available. |
| 3 | Conditional league-phase probabilities are mutually exclusive across top-8/play-off/eliminated and include rank/cut-line distributions. | ✓ VERIFIED (mechanics) | `ucl_run_simulation` samples only eligible open fixtures while preserving settled/postponed rows (`R/competition/uefa_champions_league_simulation.R:188-235`); `ucl_aggregate_rank_distributions` emits 36-rank, three-band, and rank-8/rank-24 cut-line distributions (`:237-270`). The focused 63-test suite passed. |
| 4 | Knockout projections use only legal rank-constrained and accepted draw-conditioned paths with correct tie semantics. | ✗ FAILED | Two-leg/final resolver code exists (`R/competition/uefa_champions_league_simulation.R:309-580`) and direct resolver tests pass, but the accepted-draw boundary is incomplete. A fresh-process counterexample changed the fixture draw to one pairing and arbitrary valid-looking hashes; `ucl_validate_draw_artifact` returned `status=accepted`, `pairings=1`. |
| 5 | Stage probabilities reconcile and remain monotone through champion, with byte-equivalent replay and tamper resistance. | ✗ FAILED | Replay and incumbent-byte checks pass for the fixture contract, but a fresh accepted-draw run reported only `direct_round_of_16, eliminated, knockout_play_off` stages; no QF/SF/final/champion progression is generated by `ucl_run_simulation`. A projected-standings value changed and its row hash was recomputed; candidate validation still returned `tampered_valid=TRUE`. Mutating a settled score/lifecycle left `graph_hash_same=TRUE` and `run_id_same=TRUE`. |

**Score:** 3/5 truths verified (mechanics); 0 present-but-behavior-unverified truths. Two truths are implementation blockers, not merely absent external data.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/competition/uefa_champions_league_rules.R` | Editioned Articles 17–22/Annex B contract and evidence | ✓ VERIFIED | Substantive rules/evidence contract; sourced by tests, CLI, and target helpers. |
| `R/competition/uefa_champions_league_state.R` | 36-club/144-fixture state and immutable forecast ledger | ✓ VERIFIED (mechanics) | Full validation and typed authority/suppression paths exist; production authority currently absent. |
| `R/competition/uefa_champions_league_simulation.R` | Conditional rank distributions, legal paths, tie resolvers, stage progression | ⚠️ PARTIAL | Rank/cutline and direct tie mechanics work, but draw completeness, stage execution, and run identity have gaps. |
| `R/competition/uefa_champions_league_outcomes.R` | Closed ten-file schemas, hashes, manifest, reconciliation, write seam | ⚠️ PARTIAL | Exact inventory/schema and self-consistent row hashes pass; supplied-table semantic binding and manifest-to-table verification are incomplete. |
| `scripts/build_uefa_champions_league_outcomes.R` | Fixed CLI and fail-closed production boundary | ✓ VERIFIED | `--help`, fixed controls, invalid edition, and path-override rejection behave as declared; missing authority returns typed human-needed without writing. |
| `_targets.R` UCL namespace | Ten isolated targets with executable implementation wiring | ✗ FAILED | Manifest reports exactly ten names/fifteen edges, but six downstream bodies are pass-throughs rather than builders. |
| `data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json` | Seven accepted regulation records plus typed unresolved draw record | ✓ VERIFIED | Exactly eight records; seven accepted/complete canonical UEFA documents; `draw_procedure_2026_27` is `accepted=false`, `complete=false`, `missing_edition_draw_procedure`. |
| `scripts/verify_phase20_contracts.R` | Aggregate deterministic contract verifier | ✓ VERIFIED | Ran in a fresh process and exited 0 with zero failures/warnings/skips. |
| `outputs/competition/ucl_2026_27/outcomes` | Production ten-file output | ? EXTERNAL BLOCK | Correctly absent because the Phase 18 pointer is `accepted_status: no_incumbent`; absence must not be treated as fixture evidence or a successful publication. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Rules evidence sidecar | Rules contract | `.ucl_rule_require_evidence` / `.ucl_rule_contract` | WIRED | Eight records are loaded and Article/URL/hash constraints are enforced. |
| Phase 18 accepted source | UCL state | Fixed CLI and `phase20_ucl_target_state` | WIRED, BLOCKED AS DESIGNED | Reads the registry and returns typed `no_accepted_current_ucl`; current pointer has no incumbent. |
| UCL state | Phase 14 standings / Article 18 | `ucl_build_state` → Phase 14 reducer → `ucl_apply_article18` | WIRED | Fixture state produces standings and tie-break trace; missing evidence stays unresolved. |
| Phase 19 production resolver | Forecast ledger | `.ucl_state_production_release` → `ucl_build_forecast_ledger` | WIRED, BLOCKED AS DESIGNED | Current Phase 19 authority is not accepted; production rows are suppressed. |
| Forecast ledger | Conditional simulator | `ucl_run_simulation(state, ledger=...)` | PARTIAL | Public seam is wired and fixture tests pass; target graph does not call it. |
| Rank/draw state | Legal paths | `ucl_enumerate_legal_knockout_paths` → `ucl_validate_draw_artifact` | PARTIAL | Pre-draw paths and local legality work, but partial accepted draws pass and hashes are not content-bound. |
| Knockout paths | Stage events/progression | `ucl_aggregate_stage_events` / `ucl_out_progression` | NOT_WIRED FOR GENERATED SIMULATIONS | Helpers exist, but `ucl_run_simulation` does not build stage events/progression; accepted-draw output lacks later stages. |
| Candidate artifacts | Manifest/write boundary | `ucl_validate_outcome_candidate` → `ucl_outcomes_manifest` / `ucl_write_outcome_candidate` | PARTIAL | Structural inventory/self-hash/read-back is wired, but supplied artifact content is not compared to regenerated semantics or manifest hashes. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| State/standings | `universal_standings`, `standings`, `tie_break_trace` | Accepted source → Phase 14 reducer → Article 18 | Yes for full-cardinality fixture | FLOWING; production source is absent. |
| Forecast ledger | 144 ledger rows | Approved-release rows, otherwise typed suppression | Yes for fixture mechanics; no production release | FLOWING / externally blocked. |
| Simulation | `rank_rows`, score-grid samples, paths | Ledger plus settled/open lifecycle handling | Yes for fixture mechanics | FLOWING for league ranks; knockout stage progression disconnected. |
| Outcome bundle | Ten artifact tables | State/ledger/simulation builders | Yes for fixture candidate | HOLLOW for semantic tamper binding; candidate can accept a supplied rehashed table. |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Aggregate Phase 20 contracts | `rtk Rscript --vanilla scripts/verify_phase20_contracts.R` | Exit 0; 19 edges, 21 threat mappings, 10 outputs, 63 focused tests, 10 adversarial tests, protected bytes unchanged, fixture replay byte-identical, production typed human-needed; failures/warnings/skips 0. | ✓ PASS |
| Focused UCL mechanics | `testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)` | 63 tests, 0 failures, 0 errors, 0 warnings, 0 skips. | ✓ PASS |
| Adversarial regression | `testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)` | 10 tests, 0 failures, 0 errors, 0 warnings, 0 skips. | ✓ PASS |
| Fixed production CLI with current authority | `scripts/build_uefa_champions_league_outcomes.R --edition-id=ucl_2026_27 --simulations=1 --seed=20260921 --dry-run` | Exit 0; `status=production_human_needed`, `human_needed_reason=phase18_authority_missing`, `production_eligible=FALSE`, `selector_changed=FALSE`, `incumbent_changed=FALSE`, `draw_status=unresolved_draw_procedure`. | ✓ PASS (fail-closed) |
| CLI boundary | `--trusted-release-root=/tmp/release`; invalid `--edition-id=bad` | Exit 2 with usage errors; caller-selected authority/output roots and foreign editions rejected. | ✓ PASS |
| Incomplete draw acceptance counterexample | Fresh R process calling `ucl_validate_draw_artifact` with one pairing and arbitrary 64-hex hashes | Returned `status=accepted`, `pairings=1`. | ✗ FAIL — blocker |
| Accepted-draw stage output | Fresh R process calling `ucl_run_simulation(..., draw_artifact=phase20_fixture_accepted_draw())` | Candidate valid, but progression stages were only `direct_round_of_16, eliminated, knockout_play_off`. | ✗ FAIL — blocker |
| Artifact tamper counterexample | Fresh R process changed `projected_standings$points[1]`, recomputed that row hash, then revalidated | `tampered_valid=TRUE`; manifest remained unchanged. | ✗ FAIL — blocker |
| Settled-state identity counterexample | Fresh R process changed a fixture from scheduled to completed 4–0 | `graph_hash_same=TRUE`, `run_id_same=TRUE`. | ✗ FAIL — blocker |
| Target manifest | `targets::tar_manifest(callr_function=NULL)` filtered to `^ucl20_` | Exactly 10 declared targets; commands confirm downstream pass-through bodies. | ⚠️ PARTIAL |

No full workspace suite or server was run; Phase 20 verification stayed bounded. The aggregate verifier reported historical Phase 14–19 checks as parse/declaration smoke with the known Phase 19 production repair blocker isolated.

## Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| Phase 20 aggregate contract verifier | `rtk Rscript --vanilla scripts/verify_phase20_contracts.R` | Exit 0; `PHASE20_GATE_OK mechanics=true production=typed_human_needed_or_blocked replay=true warnings=0 skips=0 failures=0 unexpected_failures=0`. | ✓ PASS |

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| UCLRULE-01 | 20-00, 20-01, 20-02, 20-05 | Recomputed 36-club table and qualification bands | SATISFIED (mechanics) | Full-cardinality schedule/state validation, Article 18 application, and focused tests pass; no accepted production source exists yet. |
| UCLRULE-02 | 20-00, 20-01, 20-02, 20-05 | Official-order editioned tie-breakers and explicit unresolved state | SATISFIED | Contract has criteria 1–10 in official order with source document IDs; missing metrics produce unresolved intervals/traces. |
| UCLRULE-03 | 20-00, 20-01, 20-02, 20-05 | Accepted eight-opponent schedule with matchday/venue/kickoff/status/score | SATISFIED (mechanics) | Schedule validator enforces all fields and 8/4/4 topology; production acceptance remains externally blocked. |
| UCLOUT-01 | 20-00, 20-01, 20-02, 20-05 | Immutable pre-kickoff forecasts only under approved release | SATISFIED at fixed production boundary | Ledger checks identity/cutoff/model evidence, preserves completed prior bytes, suppresses missing release; fixed CLI cannot select a caller release and never promotes fixtures. |
| UCLOUT-02 | 20-00, 20-01, 20-03, 20-05 | Mutually exclusive bands, ranks, and cutlines conditioned on results | SATISFIED (league mechanics) | Rank/band/cutline aggregation and conditional sampling pass focused tests. |
| UCLOUT-03 | 20-00, 20-01, 20-03, 20-05 | Legal rank-constrained paths conditioned on accepted draw | BLOCKED | Partial accepted draw counterexample demonstrates missing complete-set/content-hash enforcement. |
| UCLOUT-04 | 20-00, 20-01, 20-04, 20-05 | Two legs, aggregate/ET/penalties, no away goals, leg order, neutral final | BLOCKED at outcome boundary | Direct resolver cases pass, but accepted draw/path validation can admit incomplete topology and target/output wiring does not execute the full bracket. |
| UCLOUT-05 | 20-00, 20-01, 20-04, 20-05 | Reconciled monotone progression through champion | BLOCKED | Generated simulation has no progression field/stage transitions; accepted-draw output lacks QF/SF/final/champion rows. |
| UCLOUT-06 | 20-00, 20-01, 20-04, 20-05 | Byte-equivalent replay for identical accepted inputs | BLOCKED | Normal/reverse/repeat fixture replay passes, but settled-score mutation leaves run ID unchanged and semantically rehashed table tampering validates. |

No Phase 20 requirement is orphaned in the plans; all nine roadmap requirements are declared. Requirements marked “mechanics” are not evidence that a current production edition exists.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No unreferenced `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, placeholder, empty-return, or console-only implementation markers found in the inspected Phase 20 implementation/CLI/verifier files. | ℹ️ Info | No debt-marker blocker. The blockers above are semantic/wiring gaps found by counterexample, not grep-only warnings. |

## External / Human Verification Required

These items are genuine external dependencies and must remain typed rather than being replaced with fixture evidence:

1. **Accept a current Phase 18 UCL source bundle.** The committed pointer is `accepted_status: no_incumbent`, with empty accepted generation/path/hash; the fixed CLI correctly returns `production_human_needed` / `phase18_authority_missing` and writes no production output.
2. **Accept a final Phase 19 club release.** The current Phase 19 production resolver is not an accepted authority, so no production forecasts may be promoted. Fixture release rows are explicitly non-promotable.
3. **Obtain and review the 2026/27 draw procedure artifact.** `draw_procedure_2026_27` is deliberately `accepted=false`, `complete=false`, and `missing_edition_draw_procedure`; Article 19 is only the governing-rule anchor. Do not infer exact draw-conditioned probabilities until a same-edition artifact with complete pairings, rank inputs, lineage, and content hashes is accepted.
4. **After the implementation gaps are closed and authorities exist, inspect the generated ten-file bundle end-to-end.** This is a release check for user-facing state/probability inspection; the current phase cannot perform it without the external authorities.

## Gaps Summary

The rules and schedule mechanics are substantial and the bounded automated contracts pass. The production boundary is correctly fail-closed: fixture evidence remains non-promotable, the missing Phase 18/19 authorities produce typed human-needed state, and the unresolved 2026/27 draw procedure is not fabricated.

The phase goal is nevertheless not achieved in the codebase. The accepted-draw validator admits incomplete/hash-unbound draw content, simulation does not produce the required progression through champion, outcome validation can accept a semantically tampered supplied table, run identity does not bind settled state, and the isolated `_targets.R` namespace does not execute the Phase 20 builders. These are implementation blockers independent of the genuine external authority gaps.

---

_Verified: 2026-09-21T20:51:32Z_
_Verifier: the agent (gsd-verifier)_
