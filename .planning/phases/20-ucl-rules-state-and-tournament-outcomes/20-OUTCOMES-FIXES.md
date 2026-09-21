# Phase 20 outcome-wiring fixes

This handoff records the outcome-boundary and pipeline changes applied after the Phase 20 review. Production remains fail-closed and non-promotable.

## Implemented

- Outcome candidates now compute canonical expected artifacts, compare any caller-supplied tables against those bytes, validate every row/table hash, and bind all manifest rows plus the manifest self-hash.
- Candidate validation requires the complete six-stage/24-event inventory and complete per-club progression reconciliation before mechanics can be valid.
- The public cutoff parser and fixed CLI reject malformed/sentinel cutoffs, negative seeds, conflicting modes, and authority/path overrides.
- Result contracts preserve the ten artifact hashes and artifacts, hard-code unsafe production flags false, and make unexpected failures nonzero with a reason.
- The default production builder resolves the fixed Phase 18 current source, then the fixed Phase 19 release, before entering state/ledger/simulation/validation. Graph injection is fixture-only.
- All ten UCL targets now call executable state, ledger, simulation, path, stage, candidate, manifest, and result helpers while retaining typed blockers.
- Replay and aggregate gate checks compare real artifact hash vectors; historical regression checks execute selected suites in fresh processes and do not claim green when they fail.

## Verification

Passing focused checks:

- `test_phase20_outcomes_wiring_review.R`: 5 tests, 0 failures/errors.
- `test_phase20_simulation_review.R`: 7 tests, 0 failures/errors.
- R parse checks for both scripts, `_targets.R`, outcomes, and the dedicated test.
- `targets::tar_manifest()` confirms the ten UCL targets are present.

The aggregate verifier passed its Phase 20 inventories, focused suites, fixed-root blocker checks, root-rejection checks, and fixture replay checks. Its honest historical regression execution reports existing Phase 13 raw-resource/release-artifact failures in Phase 14–16 suites; the run is therefore not a green aggregate gate. The Phase 19 check remains explicitly labeled a parse-only known-blocker smoke check.

