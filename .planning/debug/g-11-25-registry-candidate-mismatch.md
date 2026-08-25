---
status: resolved
trigger: "Find the root cause of UAT gap G-11-25 in /Users/davidzenz/R/xGelo. Diagnose only; do not edit files or commit.\n\nSymptom: The focused hybrid/Transfermarkt test run has exactly two failures at tests/testthat/test_hybrid_context_features.R:77-78. The canonical registry now has nine candidates, adding phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open, while the test still expects the older seven-candidate list. Confirm the exact mismatch, whether production registry/target contracts are otherwise consistent, and the smallest fix direction. Write a debug session under .planning/debug/ if possible, but do not modify production code or planning files.\n\nFiles to read: .planning/phases/11-hybrid-ml-and-contextual-priors/11-UAT.md; .planning/STATE.md; tests/testthat/test_hybrid_context_features.R; R/benchmark/hybrid_protocol.R; tests/testthat/test_hybrid_targets.R; data/benchmark/phase11/model_registry.csv"
created: 2026-08-09T00:00:00+02:00
updated: 2026-08-11T21:36:55+02:00
---

## Current Focus

bug_class: bohrbug
hypothesis: "CONFIRMED: the two UAT failures are caused by a stale test expectation; test_hybrid_context_features.R still asserts the historical seven-candidate registry while the canonical production registry intentionally contains nine candidates."
test: "Compare the failing expected_ids vector with the protocol and adapter outputs, validate the committed protocol, run the target-contract suite, search all Phase 11 references, and compare canonical registry construction with the committed CSV."
expecting: "The test expectation omits exactly the xG-gated and structural IDs; protocol, adapter, canonical constructor, committed registry, and target DAG agree on nine candidates."
next_action: "Archive the resolved session and report that the nine-ID test expectation is already present; no production fix is required."
candidate_causes:
  - "code: test_hybrid_context_features.R retains a pre-merge seven-ID expected_ids vector"
  - "data: the canonical Phase 11 registry expanded to nine rows with two valid candidates"
  - "config/environment: stale target or runtime wiring could expose a different candidate set (tested and not observed)"
and_gate: "no — the deterministic failure is fully explained by the stale test expectation versus the nine-row registry; no second contributing condition is required."

## Symptoms

expected: "The focused hybrid/Transfermarkt test run should pass, and the test should reflect the canonical nine-candidate phase11 registry."
actual: "Exactly two failures occur at tests/testthat/test_hybrid_context_features.R:77-78 because the test expects the older seven-candidate list while the canonical registry has nine candidates."
errors: "Two test failures at tests/testthat/test_hybrid_context_features.R:77-78; exact assertion mismatch to be confirmed from the files."
reproduction: "Run the focused hybrid/Transfermarkt test run and inspect the assertions at tests/testthat/test_hybrid_context_features.R:77-78."
started: "After the canonical registry added phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open; the test retained the prior seven-candidate expectation."

## Eliminated

## Evidence

- timestamp: 2026-08-09T00:00:00+02:00
  checked: "Active debug-session directory and project debug configuration"
  found: "No active debug session was present; project config is yolo mode with commit_docs true, and no project-specific agent skill mapping was configured for gsd-debugger."
  implication: "A new diagnose-only session can be created; no prior session needs to be resumed."

- timestamp: 2026-08-09T22:36:17+02:00
  checked: "Requested UAT, state, test, protocol, target-contract, and committed model-registry artifacts"
  found: "11-UAT.md records G-11-25 as the only minor regression issue and explicitly identifies two stale assertions at test_hybrid_context_features.R:77-78. The test's expected_ids at lines 68-76 contains seven IDs: the open tracer plus the context bundle and five drop-one variants. R/benchmark/hybrid_protocol.R defines six context IDs at lines 1115-1123 and canonical_phase11_model_registry_rows() appends the xG-gated and structural candidates at lines 1182-1184, yielding nine rows. The committed model_registry.csv has those nine candidate rows, including phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open. The target test checks a six-node downstream-only DAG and registry-file dependencies, not a seven-candidate allow-list."
  implication: "The initial evidence supports a deterministic stale-test expectation rather than a production registry or target-DAG contract defect; the focused run is needed to confirm the exact failure output and any unrelated failures."

- timestamp: 2026-08-09T22:44:32+02:00
  checked: "Focused testthat run: tests/testthat filtered by hybrid|transfermarkt"
  found: "The run exited with status 1 and exactly two failures, both in test_hybrid_context_features.R:77:3 and :78:3. Both assertions compare a nine-ID actual set against the same seven-ID expected_ids vector and report exactly the two missing IDs: phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open. hybrid_targets, hybrid_modes, hybrid_random_forest, hybrid_structural_prior, hybrid_xg_gate, and transfermarkt_benchmark completed without failures."
  implication: "The UAT symptom is deterministic and exactly reproduced. The failure is an expectation-only mismatch; the production loader and target suite did not fail in the same run."

- timestamp: 2026-08-09T22:48:11+02:00
  checked: "Standalone read-only protocol and adapter probe using load_and_validate_hybrid_protocol() and hybrid_phase11_candidate_ids(protocol)"
  found: "The committed protocol validates with protocol_valid=TRUE; model_registry has 9 rows; the registry ID sequence and adapter helper ID sequence are identical. Both added IDs are present, and the registry's complete sequence is open tracer, full context, five context drops, xG-gated context, structural prior."
  implication: "The production registry and candidate allow-list are internally consistent. The stale seven-ID vector exists only in the test assertion examined so far."

- timestamp: 2026-08-09T22:51:06+02:00
  checked: "Standalone testthat run for tests/testthat/test_hybrid_targets.R"
  found: "The target-contract file completed with exit status 0 and no failures (35 passing expectations)."
  implication: "The Phase 11 target DAG and its explicit research-only/downstream-only contract are consistent with the current production registry; the reported gap is not a target-contract failure."

- timestamp: 2026-08-09T22:54:42+02:00
  checked: "Repository-wide references for the added IDs and seven-candidate wording"
  found: "Phase 11 production protocol, adapters, runner wiring, selection feature map, xG/structural tests, manifests, and the committed registry all recognize the two added IDs. The only stale seven-ID Phase 11 assertion is the expected_ids vector in test_hybrid_context_features.R:68-78. The other 'exact seven' wording is in the Phase 10 statistical challenger runner/test and uses a separate seven-candidate registry."
  implication: "No second Phase 11 production allow-list or target contract is stale. The fix scope is confined to the Phase 11 context-feature test, but its ablation assertion must remain a six-context-ID check rather than blindly using the expanded nine-ID registry list."

- timestamp: 2026-08-09T22:57:18+02:00
  checked: "Canonical registry constructor versus committed data/benchmark/phase11/model_registry.csv"
  found: "canonical_phase11_model_registry_rows() returned 9 rows; the committed CSV returned 9 rows; candidate_id sequences were identical, in the same order, including both added candidates."
  implication: "The production registry file is not stale or malformed. Updating the test's expected registry set is the smallest corrective direction."

- timestamp: 2026-08-09T22:59:46+02:00
  checked: "Final git status after read-only tests and probes"
  found: "The worktree contains existing output and untracked artifacts, including the phase11 bundle outputs, but no modified R/ or tests/ paths. The only new diagnostic artifact from this session is .planning/debug/g-11-25-registry-candidate-mismatch.md."
  implication: "No production code or test file was edited by this diagnosis. Unrelated worktree changes were preserved and not reverted."

- timestamp: 2026-08-11T21:36:55+02:00
  checked: "Current test expectation and focused hybrid/Transfermarkt suite"
  found: "tests/testthat/test_hybrid_context_features.R currently lists all nine canonical candidate IDs, including phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open. The focused hybrid|transfermarkt test_dir run completed with exit status 0 and no failures."
  implication: "The smallest test-only correction is already present in the current tree; no additional edit is needed to resolve the reported mismatch."

- timestamp: 2026-08-11T21:36:55+02:00
  checked: "Current Phase 11 target-contract suite"
  found: "tests/testthat/test_hybrid_targets.R completed with exit status 0."
  implication: "The production target contract remains green after the registry expectation correction."

## Eliminated

- hypothesis: "The canonical Phase 11 registry or its committed CSV is missing, malformed, or out of sync with the production constructor"
  evidence: "load_and_validate_hybrid_protocol() returned valid=TRUE; canonical_phase11_model_registry_rows() and the committed CSV both returned the identical nine-ID sequence."
  timestamp: 2026-08-09T22:57:18+02:00

- hypothesis: "The Phase 11 adapter allow-list or target DAG still encodes the obsolete seven-candidate set"
  evidence: "hybrid_phase11_candidate_ids(protocol) exactly matched the nine registry IDs, and tests/testthat/test_hybrid_targets.R passed all 35 expectations; _targets.R passes the dynamic helper output into run_hybrid_challenger_benchmark()."
  timestamp: 2026-08-09T22:57:18+02:00

- hypothesis: "A Transfermarkt or environment/data issue causes the reported failures"
  evidence: "The focused hybrid|transfermarkt run reproduced the same two deterministic set mismatches while all Transfermarkt and other focused Phase 11 suites completed without failures."
  timestamp: 2026-08-09T22:57:18+02:00

## Resolution

root_cause: "tests/testthat/test_hybrid_context_features.R:68-78 defines expected_ids with only the historical seven Phase 11 candidate IDs, but both the canonical constructor and committed data/benchmark/phase11/model_registry.csv now contain nine IDs; the omitted IDs are phase11_rf_dynamic_elo_context_xg_gated_open and phase11_structural_sparse_prior_open."
fix: "The test-only expected registry set now includes the two added IDs while the ablation assertion remains scoped to the six context IDs. This correction was already present in the current tree, so this continuation made no source-file edit; no production registry, adapter, target, or planning-file fix is indicated."
verification: "The original focused run reproduced exactly two failures at test_hybrid_context_features.R:77-78; protocol validation passed; canonical and committed registry IDs matched at nine; hybrid_phase11_candidate_ids matched the registry; the current focused hybrid|transfermarkt suite passed with exit status 0; and standalone test_hybrid_targets.R passed with exit status 0."
files_changed: []

## Postmortem

why_not_caught: "The canonical Phase 11 registry expanded without updating the corresponding test allow-list in the same change."
guard: "Keep the nine-ID registry assertion synchronized with canonical_phase11_model_registry_rows() and run the focused hybrid|transfermarkt suite after registry changes."
