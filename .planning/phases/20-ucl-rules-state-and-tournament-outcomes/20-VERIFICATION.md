---
phase: 20-ucl-rules-state-and-tournament-outcomes
verified: 2026-09-25T00:00:00Z
status: human_needed
score: 5/5 implementation must-haves verified; external authority pending
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "The accepted-draw validator now rejects partial pairings, duplicate or incomplete rank inputs, stale hashes, and foreign lineage, and recomputes the canonical pairing/rank/draw hashes."
    - "Simulation now emits the complete 24-row knockout-stage inventory and 8 progression rows per club through champion, including unresolved/suppressed rows when the edition draw is unavailable."
    - "Outcome candidates now compare supplied artifact tables with freshly regenerated expected tables and bind the ten artifact hashes into the manifest."
    - "The ten UCL targets now call the state, ledger, simulation, path, stage, candidate, manifest, and result helpers instead of being pure pass-through nodes."
    - "Production draw validation now requires accepted edition evidence and an in-process trusted artifact token; the target and CLI seams carry that trusted artifact through simulation and path enumeration."
    - "Outcome candidates now bind graph, state, ledger, model, calibrator, component, and simulation-run identities; unresolved progression rows must carry NA probabilities."
    - "Target path/stage exceptions now remain typed blocked states, and replay-check reverses semantic fixture input rows before comparing identities."
  gaps_remaining:
    - "Phase 18 has no accepted current UCL source bundle."
    - "Phase 19 still has no source-backed forecast_rows release."
    - "The official 2026/27 draw artifact remains unreviewed and explicitly unaccepted in the rules sidecar."
  regressions:
    - "Phase 14 standings still fails at test_phase14_standings.R:686 on a temporary schema-v2 row.names attribute mismatch."
    - "The bounded aggregate run did not produce a result for the long Phase 14 state-bundle regression before it was interrupted; it is not reported as green."
gaps:
  - truth: "Knockout projections use only legal rank-constrained and trusted accepted draw-conditioned paths."
    status: failed
    reason: "Local draw shape/content checks are fixed, but a self-consistent caller draw is accepted even while the editioned draw evidence is explicitly unaccepted; the target and CLI pipeline also do not carry a trusted draw into simulation/path enumeration."
    artifacts:
      - path: "R/competition/uefa_champions_league_simulation.R"
        issue: "ucl_validate_draw_artifact validates caller-supplied content but does not require trusted accepted edition evidence."
      - path: "_targets.R"
        issue: "phase20_ucl_target_simulation and phase20_ucl_target_paths do not accept or forward a draw artifact."
      - path: "scripts/build_uefa_champions_league_outcomes.R"
        issue: "The fixed production builder has no source-bound accepted-draw resolution."
    missing:
      - "Resolve the draw only from a fixed accepted Phase 18/source-bundle artifact and bind its source/content hash."
      - "Carry that exact draw object through the target and CLI simulation/path/manifest seams; reject caller production draw injection."
  - truth: "Stage replay and outcome identity bind the complete accepted state, ledger, draw, model, and simulation run."
    status: failed
    reason: "The candidate artifact tables and manifest hashes are real, but candidate validation accepts independent graph, ledger, and simulation run_id mutations after the simulation has been built."
    artifacts:
      - path: "R/competition/uefa_champions_league_outcomes.R"
        issue: "ucl_validate_outcome_candidate does not require state/graph/table/model/draw hashes and run_id to equal the simulation metadata."
      - path: "R/competition/uefa_champions_league_simulation.R"
        issue: "The simulation emits the needed identity fields, but the outcome boundary does not consume them for component binding."
    missing:
      - "Revalidate the supplied state graph and ledger at the outcome boundary and compare graph/state/ledger/model/calibrator/draw/run identities with simulation metadata."
      - "Require unresolved/suppressed progression probabilities to be NA and reject any rehashed semantic mutation."
---

# Current final disposition (2026-09-25)

The earlier blocker findings below are retained as the historical audit trail. They were closed by commit `e1402ba` and the focused final-boundary review. The Phase 20 implementation is mechanically complete and fail-closed; the phase remains `human_needed` because production authority is still external and unavailable.

Fresh evidence after the repair:

- `test_uefa_champions_league.R` passed.
- `test_phase20_state_authority_review.R`, `test_phase20_simulation_review.R`, `test_phase20_outcomes_wiring_review.R`, `test_phase20_adversarial_regression.R`, and `test_phase20_final_boundary_review.R` passed.
- `targets::tar_manifest()` reports the exact ten UCL targets and fifteen edges.
- The fixed CLI returns `production_human_needed / phase18_authority_missing` with protected bytes unchanged.
- The aggregate verifier reaches the known historical Phase 14 standings row-names failure; the long Phase 14 state-bundle regression remains bounded/incomplete and is not claimed green.

Production output must remain absent until Phase 18 source acceptance, Phase 19 release/forecast-row acceptance, and the official 2026/27 draw artifact are independently approved.

# Phase 20: UCL Rules, State, and Tournament Outcomes Verification Report

**Phase Goal:** Users can inspect a rules-correct Champions League state and replayable probabilities from the league phase through the final.

**Verified:** 2026-09-22T00:45:42Z

**Status:** gaps_found

**Re-verification:** Yes — after the prior verification and review-fix commits.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Users can inspect all 36 clubs, qualification bands, and Article 18 decisive/unresolved tie evidence. | ✓ VERIFIED (fixture mechanics) | The rules contract contains the editioned 36-club/144-fixture topology, seven accepted regulation records plus the explicit unresolved draw record, and the Article 18 criterion order. The fresh UCL suite and state-authority suite pass; the fixture state produces 36 standings/ranking rows and tie traces. Current production inspection remains blocked by the absent accepted Phase 18 source. |
| 2 | Every club has an accepted eight-opponent schedule and a cutoff-safe immutable pre-kickoff forecast when covered by an approved release. | ✓ VERIFIED (fixture mechanics) | ucl_validate_schedule enforces 36 clubs, 144 unique fixtures, eight opponents, 4/4 home-away, matchday, venue, confirmed kickoff, lifecycle/score semantics, edition, and source lineage. The ledger builder validates one row per fixture, strict feature_cutoff_utc < kickoff_utc, and completed-row preservation. The fixture outcome contains 144 schedule and 144 ledger rows; no accepted production schedule/release is currently available. |
| 3 | Conditional league-phase probabilities are mutually exclusive across top-8/play-off/eliminated and include rank/cut-line distributions. | ✓ VERIFIED (fixture mechanics) | The simulation samples only eligible open fixtures, preserves settled rows, and the rank aggregator requires a complete authoritative 36-club rank permutation. Focused and adversarial suites pass the band, rank, and cut-line contracts. |
| 4 | Knockout projections use only legal rank-constrained and accepted draw-conditioned paths with correct tie semantics. | ✗ FAILED | Structural mechanics are substantially fixed: an accepted fixture draw must contain exactly eight play-off and eight R16 pairings, all 36 rank inputs, legal bracket families, and content-derived rank/pairing/draw hashes. However, a fresh probe accepted a self-consistent caller draw while the rules sidecar reported draw_procedure_2026_27 accepted=false, complete=false; the production boundary does not require trusted accepted draw evidence. The target graph also hardcodes draw_artifact = NULL, so a future accepted draw cannot reach the target simulation/path consumers. |
| 5 | Stage probabilities reconcile and remain monotone through champion, with byte-equivalent replay and tamper-resistant identity. | ✗ FAILED | Fixture simulation now emits 24 knockout stage/path rows and 288 progression rows (eight stage rows for each of 36 clubs), and the CR-09 reconciliation test passes. Artifact hashes and three fixture replays are byte-identical. The outcome boundary nevertheless accepts a valid candidate after independently mutating the state graph venue, a ledger probability, or the simulation run_id; those components are not required to match the simulation's state/graph/ledger/model/draw identity. An unresolved progression row also accepted a numeric probability (0.99) rather than requiring NA. |

**Score:** 3/5 truths verified. Two truths remain implementation blockers; no truth is merely present-but-behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| R/competition/uefa_champions_league_rules.R | Editioned Articles 17–22/Annex B contract and evidence | ✓ VERIFIED | Exact evidence inventory and draw-policy contract are loaded and checked. |
| R/competition/uefa_champions_league_state.R | 36-club/144-fixture state and immutable forecast ledger | ✓ VERIFIED (fixture mechanics) | Full schedule/state validation, Article 18 trace, cutoff, ledger lineage, and completed-row preservation are wired. Production source/release authority is externally absent. |
| R/competition/uefa_champions_league_simulation.R | Conditional ranks, legal draw paths, tie resolvers, and complete progression | ⚠️ PARTIAL | Rank/cut-line logic, exact draw inventory/content hashing, two-leg/final resolvers, 24 stage events, and progression reconciliation pass. Trusted draw provenance and candidate component binding remain incomplete. |
| R/competition/uefa_champions_league_outcomes.R | Ten closed schemas, real hashes, manifest binding, reconciliation, and write seam | ⚠️ PARTIAL | Ten schemas and real artifact/manifest hashes pass. The validator does not bind the supplied state/ledger/simulation components to the run identity and permits numeric values on unresolved progression rows. |
| scripts/build_uefa_champions_league_outcomes.R | Fixed CLI and fail-closed production boundary | ⚠️ PARTIAL | Fixed roots, cutoff, seed, mode, and typed production blocker pass. Replay calls the same builder twice rather than exercising reversed semantic input; no accepted draw is resolved or forwarded. |
| _targets.R UCL namespace | Ten executable isolated targets with fifteen directed edges | ⚠️ PARTIAL | targets::tar_manifest() reports the exact ten-name set. Downstream bodies call real helpers, but path/stage errors are converted to empty data frames, and draw input is hardcoded NULL. |
| data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json | Seven accepted regulation rows plus typed unresolved draw row | ✓ VERIFIED | Eight rows are present; the draw row is explicitly accepted=false, complete=false, missing_edition_draw_procedure, with the Article 19 anchor. |
| scripts/verify_phase20_contracts.R | Fresh-process aggregate contract verifier | ⚠️ PARTIAL | Exact inventory, public symbols, target graph, CR probes, production/root protections, focused suites, and fixture replay all emitted passing markers. The run then reached the historical Phase 14 standings failure and did not complete the long state-bundle regression before bounded interruption; it is not a green aggregate result. |
| outputs/competition/ucl_2026_27/outcomes | Production ten-file output | ? EXTERNAL BLOCK | Correctly absent while the fixed Phase 18 pointer has no accepted UCL incumbent. Fixture outputs remain explicitly non-promotable. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Rules evidence sidecar | Rules contract | .ucl_rule_contract / evidence validator | WIRED | Eight editioned records and the unresolved draw record are checked, including canonical content hashes. |
| Phase 18 accepted source | UCL state | Fixed reader and ucl_build_state | WIRED, BLOCKED AS DESIGNED | The reader sees accepted_status: no_incumbent; the CLI returns phase18_authority_missing without production mutation. |
| UCL state | Phase 14 standings / Article 18 | State builder → standings reducer → Article 18 trace | WIRED | Fixture state produces full standings and decisive/unresolved tie traces; Phase 14 authority absence cannot promote the fixture fallback. |
| Phase 19 production resolver | Forecast ledger | Fixed resolver → ucl_build_forecast_ledger | WIRED, BLOCKED AS DESIGNED | The production release seam requires source-backed forecast_rows; current Phase 19 authority is blocked. |
| Forecast ledger | Conditional simulator | ucl_run_simulation(state, ledger=...) | WIRED | Simulation entry validates graph/table/lineage/model identity and the strict cutoff; candidate validation does not re-bind those identities. |
| Accepted draw | Simulation and legal paths | ucl_run_simulation / ucl_enumerate_legal_knockout_paths | NOT WIRED AT PRODUCTION BOUNDARY | The public validator locally accepts a fabricated self-consistent draw and the target path helper explicitly passes draw_artifact = NULL; trusted source acceptance is not consumed. |
| Knockout paths | Stage events/progression | Stage inventory, aggregation, progression reconciliation | WIRED FOR FIXTURE SIMULATION | Complete 24-event/288-row mechanics are generated and reconciled; target stage aggregation can hide errors by returning an empty data frame. |
| State/ledger/simulation | Candidate artifacts/manifest | ucl_validate_outcome_candidate | PARTIAL | Supplied artifact tables are compared against freshly generated tables and manifest hashes are real, but independently mutated component objects can still be combined into a valid candidate. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| State/standings | standings, projected_rankings, tie_break_trace | Fixture graph → state builder → Article 18 reducer | Yes, 36 rows | ✓ FLOWING; production source externally blocked |
| Forecast ledger | fixture_forecast_ledger | Approved fixture release → strict ledger builder | Yes, 144 rows | ✓ FLOWING for fixture mechanics; production release externally blocked |
| Simulation | rank_rows, knockout_paths, stage/progression rows | Ledger score grids → seeded simulator → stage reconciliation | Yes, 24 path/stage rows and 288 progression rows | ✓ FLOWING for fixture mechanics |
| Outcome bundle | Ten named artifact tables | State/ledger/simulation → candidate builder → manifest | Yes; ten hashes match actual artifact bytes | ⚠️ HOLLOW identity binding: independently mutated source components are not rejected |
| Target namespace | ucl20_* values | Fixed source/rules/state/ledger/simulation/path/stage/candidate/manifest/status functions | Typed blockers/unresolved values | ⚠️ PARTIAL: draw is disconnected and path/stage exceptions are swallowed |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Broad UCL mechanics | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary")' | Fresh process exited 0; no failure/error/warning/skip summary. | ✓ PASS |
| Phase 20 adversarial suite | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary")' | Fresh process exited 0; 10 tests, no failures/errors/warnings/skips. | ✓ PASS |
| State authority review suite | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_state_authority_review.R", reporter="summary")' | Fresh process exited 0; no failures/errors/warnings/skips. | ✓ PASS |
| Simulation review suite | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_simulation_review.R", reporter="summary")' | Fresh process exited 0; 7 tests, no failures/errors/warnings/skips. | ✓ PASS |
| Outcomes wiring review suite | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_outcomes_wiring_review.R", reporter="summary")' | Fresh process exited 0; 5 tests, no failures/errors/warnings/skips. | ✓ PASS |
| Fixture artifact replay probe | Fresh R process calling ucl20_build_outcomes with the declared fixture graph/release | status=unresolved_draw_procedure, ten artifact hashes, 24 knockout_paths rows, 288 progression rows, and result hashes identical to hashes recomputed from all ten actual tables. | ✓ PASS (mechanics) |
| Accepted-draw authority probe | Fresh R process calling ucl_validate_draw_artifact on a complete locally hashed fixture draw | Sidecar says accepted=FALSE, complete=FALSE; validator returned status=accepted. | ✗ FAIL — trusted draw provenance bypass |
| Candidate component-binding probe | Fresh R process independently changed graph venue, ledger probability, or simulation run_id after the run | Each mutation returned valid=TRUE, status=unresolved_draw_procedure, with no failure. | ✗ FAIL — run identity not enforced at outcome boundary |
| Unresolved probability probe | Fresh R process set one unresolved progression row probability to 0.99 | Candidate still returned valid=TRUE. | ⚠️ WARNING — unresolved rows are not forced to NA |
| Fixed production CLI | rtk Rscript --vanilla scripts/build_uefa_champions_league_outcomes.R --edition-id=ucl_2026_27 --simulations=1 --seed=20260921 --dry-run | Exit 0; status=production_human_needed, human_needed_reason=phase18_authority_missing, original_parent_reason=no_accepted_current_ucl, production_eligible=FALSE, selector/incumbent unchanged. | ✓ PASS (fail-closed external blocker) |
| Target manifest | rtk Rscript --vanilla -e 'targets::tar_manifest(script="_targets.R")' | Exact UCL target name set contains ten targets. | ✓ PASS (declaration); runtime draw/error wiring remains partial |
| Phase 18 contract gate | rtk Rscript --vanilla scripts/verify_phase18_contracts.R | PHASE18_GATE_OK ... production_fail_closed=true; 8 fresh suites, 142 tests, 840 assertions. | ✓ PASS (authority remains intentionally absent) |
| Phase 14 standings regression | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", reporter="summary")' | Failed at line 686: temporary schema-v2 expected/actual data frames differ only by row.names attributes. | ✗ HISTORICAL FAILURE — not a Phase 20 pass |
| Phase 14/15/16 bounded regressions | Aggregate fresh-process run plus individual Phase 15/16 runs | Phase 14 match-state and forecast checks emitted pass markers; Phase 15 and Phase 16 individual suites exited 0. The Phase 14 state-bundle run produced no bounded completion and was interrupted; no full historical green claim is made. | ? HISTORICAL / INCOMPLETE |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| Conventional scripts/*/tests/probe-*.sh inventory | find scripts -path '*/tests/probe-*.sh' -type f | No conventional probe files present. | ✓ N/A |
| Phase 20 aggregate verifier | rtk Rscript --vanilla scripts/verify_phase20_contracts.R | Fresh process passed inventories (edges=19, outputs=10, requirements=9), public symbols, exact target graph, evidence, five CR probes, fixed-root protections, focused review suites, and three-run fixture replay. It then reported the Phase 14 standings failure and was interrupted during the long Phase 14 state-bundle regression (exit 130). | ✗ HISTORICAL GATE INCOMPLETE; do not call aggregate green |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| UCLRULE-01 | 20-00, 20-01, 20-02, 20-05 | Recomputed 36-club table and qualification bands | SATISFIED (mechanics) | Full-cardinality fixture state, 36 rankings, direct/play-off/eliminated bands, and rank aggregation pass; production Phase 18 source is absent. |
| UCLRULE-02 | 20-00, 20-01, 20-02, 20-05 | Official-order editioned tie-breakers and explicit unresolved rank | SATISFIED | Article 18 criteria and evidence order are editioned; unresolved intervals/traces are retained when evidence is incomplete. |
| UCLRULE-03 | 20-00, 20-01, 20-02, 20-05 | Accepted eight-opponent schedule with matchday/venue/kickoff/status/score | SATISFIED (mechanics) | Schedule validator and 144-row fixture artifact enforce the complete topology and lifecycle/score fields; production acceptance is externally blocked. |
| UCLOUT-01 | 20-00, 20-01, 20-02, 20-05 | Immutable pre-kickoff forecasts only under an approved release | SATISFIED at fixed boundary | Strict cutoff and model/ledger lineage checks pass; completed rows are preserved; the fixed CLI cannot select a release and production stops before writing without Phase 18/19 authority. |
| UCLOUT-02 | 20-00, 20-01, 20-03, 20-05 | Mutually exclusive bands, ranks, and cut-lines conditioned on accepted results | SATISFIED (mechanics) | Complete rank permutation, band, and cut-line contracts pass with conditional fixture sampling. |
| UCLOUT-03 | 20-00, 20-01, 20-03, 20-05 | Legal rank-constrained paths conditioned on an accepted draw artifact | BLOCKED | Local complete-draw/hash checks pass, but a caller-supplied self-consistent draw bypasses the unaccepted edition evidence and the target pipeline drops draw input. |
| UCLOUT-04 | 20-00, 20-01, 20-04, 20-05 | Two legs, aggregate/ET/penalties, no away goals, leg order, neutral final | BLOCKED at production path boundary | Direct tie resolvers and fixture path semantics pass; trusted draw resolution and target/CLI propagation are not wired. |
| UCLOUT-05 | 20-00, 20-01, 20-04, 20-05 | Reconciled monotone progression through play-off, R16, QF, SF, final, champion | SATISFIED (fixture mechanics; unresolved production values) | CR-09 and direct fixture probe confirm the full six-stage/24-event inventory and 288 per-club progression rows with reconciliation; current official draw and production forecast authorities are missing. |
| UCLOUT-06 | 20-00, 20-01, 20-04, 20-05 | Byte-equivalent replay for identical accepted inputs | BLOCKED | Three identical fixture artifact hash vectors pass, but candidate component identity is not enforced and CLI replay repeats identical calls instead of exercising a reversed semantic input. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| R/competition/uefa_champions_league_simulation.R | 976–1033 | ucl_validate_draw_artifact accepts a caller draw based on local shape/content hashes without requiring trusted accepted edition evidence. | 🛑 BLOCKER | A fabricated self-consistent draw can bypass the unaccepted official draw boundary. |
| _targets.R | 444–498 | draw_artifact = NULL is hardcoded in target simulation/path calls; path/stage exceptions return empty data frames. | 🛑 BLOCKER | The ten-target production pipeline cannot consume an accepted draw and can hide runtime errors. |
| R/competition/uefa_champions_league_outcomes.R | 624–711 | Candidate validation regenerates tables but does not compare supplied state/ledger/simulation component hashes with simulation metadata/run identity. | 🛑 BLOCKER | Independently mutated graph, ledger, and run ID objects validate as one candidate. |
| scripts/build_uefa_champions_league_outcomes.R | 367–379 | Replay invokes the same builder twice with identical inputs. | ⚠️ WARNING | replay-check does not test reversed semantic input/order. |
| R/competition/uefa_champions_league_outcomes.R | 596–619 | Unresolved/suppressed progression rows are not required to have NA probability. | ⚠️ WARNING | A downstream consumer can mistake an unresolved numeric value for a real probability. |
| Phase 20 implementation/CLI/verifier files | — | No unreferenced TBD, FIXME, or XXX debt markers found. | ℹ️ INFO | No debt-marker gate; the blockers above are semantic/wiring defects. |

### External, Historical, and Human Verification Items

These are kept separate from the Phase 20 implementation blockers and are not counted as Phase 20 passes:

1. **Phase 18 current UCL authority:** data/competition/registries/ucl_source_current.json has accepted_status: no_incumbent and empty accepted generation/path/hash. The fixed CLI correctly returns phase18_authority_missing and does not mutate protected roots.
2. **Phase 19 club/model authority:** data/club/history_current.json is acceptance_state: blocked with source/license/coverage/lineage/identity/score/temporal blockers; data/club/model_protocol/protocol_state.json is state: blocked, reason_code: no_accepted_club_history, with no accepted generation or fold registry. The production resolver therefore cannot provide source-backed forecast_rows; no production model release may be fabricated.
3. **2026/27 draw procedure:** The committed sidecar deliberately records accepted=false, complete=false, and missing_edition_draw_procedure. Article 19 is only the governing-rule anchor; a same-edition trusted draw artifact still needs owner acceptance and content/lineage review.
4. **Historical Phase 14 regression:** test_phase14_standings.R:686 still fails on a temporary schema-v2 row.names attribute mismatch. The Phase 14 state-bundle run did not complete in the bounded verification window; this is historical/incomplete evidence, not a Phase 20 pass.
5. **Release inspection after authority closure:** Once Phase 18, Phase 19, and the draw procedure are accepted and the implementation gaps above are closed, a human must inspect the actual ten-file production bundle and user-facing progression/probability behavior.

### Gaps Summary

The review fixes materially improved the mechanics: exact accepted-draw inventory and content hashing, full six-stage progression, semantic artifact/manifest comparison, strict cutoff, protected roots, five CR probes, fixed production resolution order, and real ten-artifact replay hashes are present and exercised.

The phase goal is still not achieved in the current codebase. The trusted accepted-draw authority is not enforced and is disconnected from the target/CLI pipeline, and outcome candidates can combine independently mutated state, ledger, and simulation identity components. These are implementation blockers. Separately, the current Phase 18 source, Phase 19 club/model release, and 2026/27 draw evidence are genuinely absent/blocked external authorities; they are reported as typed blockers rather than treated as Phase 20 successes. Historical Phase 14 row-name/resource/model validation remains separate and is not hidden behind the passing Phase 20 mechanics suites.

---

_Verified: 2026-09-22T00:45:42Z_  
_Verifier: the agent (gsd-verifier)_  
