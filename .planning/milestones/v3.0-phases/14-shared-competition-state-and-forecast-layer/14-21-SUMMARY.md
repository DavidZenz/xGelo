---
phase: 14-shared-competition-state-and-forecast-layer
plan: "21"
subsystem: release-calibration
tags: [r, testthat, nested-calibration, vector-scaling, immutable-evidence, phase12-gates]
requires:
  - phase: 09-rolling-tournament-benchmark
    provides: frozen 630-fixture incumbent updating/open-core development panel
  - phase: 12-release-artifacts-and-installation
    provides: immutable calibration recipe, promotion protocol, selectors, registry pins, and decision gates
  - phase: 14-shared-competition-state-and-forecast-layer
    plan: "04"
    provides: original immutable blocked calibration gate and manifest
  - phase: 14-shared-competition-state-and-forecast-layer
    plan: "05"
    provides: fail-closed checkpoint routing remediation to Plan 14-21
provides:
  - frozen 45-candidate raw/scalar/vector calibration-remediation contract
  - nested strictly-prior selection and replay-sufficient fits for all 12 outer tournaments
  - immutable 630-fixture candidate graph with an unchanged Phase 12 approved outer gate
  - post-pass fitted vector calibrator candidate for independent Plan 14-22 acceptance
affects: [14-22, calibration-release, forecast-authority, FORECAST-01]
tech-stack:
  added: []
  patterns:
    - nested tournament selection with explicit raw fail-closed fallback
    - replay-sufficient per-outer fit records with canonical row and graph hashes
    - final candidate fitting only after a zero-reason authoritative outer pass
key-files:
  created:
    - R/release/calibration_remediation.R
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/remediation_contract.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/outer_fold_selection.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/outer_fold_fits.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibrator.rds
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibrated_predictions.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibration_gate.csv
    - outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibration_revision_manifest.csv
  modified:
    - tests/testthat/test_phase14_calibration_remediation.R
key-decisions:
  - "The frozen search contains raw identity plus 16 shrunk-scalar and 28 regularized-vector candidates; no exploratory value controls selection."
  - "The unchanged Phase 12 outer gate is CALIBRATION_RELEASE_APPROVED with zero reasons, but this graph remains non-authoritative candidate evidence pending Plan 14-22 acceptance."
  - "The final candidate vector_w400_p0p010 was selected and fitted on all 630 development rows only after the actual outer pass."
patterns-established:
  - "Outer replay: each fit row binds ordered prior tournaments, inner validation/training maps, support, recipe, seed, convergence, parameters, and source-panel hash."
  - "Immutable graph: original gate/manifest, protocol, recipe, selectors, registry pins, all new artifacts, and manifest self-hash are validated together."
requirements-addressed: [FORECAST-01]
requirements-completed: []
coverage:
  - id: D1
    description: Frozen nested selector evaluates raw identity, shrunk temperature, and regularized vector scaling without outer-label leakage.
    requirement: FORECAST-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase14_calibration_remediation.R#frozen-grid-nested-selection-and-leakage-contracts
        status: pass
    human_judgment: false
  - id: D2
    description: Twelve replay-sufficient outer fits regenerate all 630 persisted probabilities while preserving fixture and score-distribution identities.
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase14_calibration_remediation.R#complete-graph-and-independent-replay
        status: pass
      - kind: integration
        ref: phase14_validate_calibration_remediation(require_promoted=TRUE)
        status: pass
    human_judgment: false
  - id: D3
    description: The unchanged Phase 12 gates approve the outer evidence and permit the final vector fit only after that pass.
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase14_calibration_remediation.R#canonical-phase12-decision-and-post-pass-fit
        status: pass
      - kind: integration
        ref: tests/testthat/test_phase12_calibration.R
        status: pass
    human_judgment: false
duration: 1h21m
completed: 2026-08-17
status: complete
---

# Phase 14 Plan 21: Nested Calibration Remediation Summary

**Nested strictly-prior calibration selected vector scaling across the supported outer folds, improved RPS and calibration error under every unchanged Phase 12 veto, and produced a hash-bound post-pass candidate without mutating release authority.**

## Performance

- **Duration:** 1 hour 21 minutes
- **Started:** 2026-08-17T07:14:04Z
- **Completed:** 2026-08-17T08:34:37Z
- **Tasks:** 2
- **Files created:** 8
- **Files modified:** 1

## Accomplishments

- Froze exactly 45 candidates: one raw identity, 16 warm-up/shrunk-temperature combinations, and 28 warm-up/vector-penalty combinations.
- Selected each outer recipe from nested tournament-complete evidence whose fit tournaments are strictly earlier than its inner validation tournament and whose inner evidence is strictly earlier than the outer tournament.
- Persisted 12 canonical fit rows and 630 calibrated candidate predictions; independent parameter replay matches every probability within `1e-12` while raw probabilities, auxiliary markets, fixtures, and score distributions remain unchanged.
- Recomputed the complete outer decision through the unchanged Phase 12 support, coverage, identity, RPS, Brier, log-loss, fold-stability, and strict calibration-improvement gates.
- Fitted `vector_w400_p0p010` on all development rows only after the zero-reason outer pass; the candidate graph remains non-authoritative pending Plan 14-22.

## Authoritative Outer Gate

**Disposition:** `CALIBRATION_RELEASE_APPROVED`  
**Ordered reasons:** none (`reason_count = 0`)  
**Primary candidate view:** `calibrated_1x2`

| Metric | Raw | Remediated | Change | Gate |
|---|---:|---:|---:|---|
| RPS | `0.20393028952051301` | `0.20298086993256501` | `-0.000949419587947975` | Pass |
| Brier | `0.60841443265666695` | `0.60845644820275002` | relative `+0.0000690574447733862` | Pass |
| Log loss | `1.01714437308725` | `1.0183418996321201` | relative `+0.00117734175850613` | Pass |
| Maximum outer-fold RPS regression | — | — | `+0.0060715743905756202` | Pass |
| Calibration error | `0.049629738035499402` | `0.034446810098736701` | `-0.015182927936762699` | Pass |

The approved disposition is candidate evidence only: `candidate_authority = FALSE`, `authority_mutated = FALSE`, and `holdout_labels_used = FALSE`. Plan 14-21 did not alter release selectors, registry pins, public suppression, or WC2026 holdout evidence.

## Selected Families by Outer Fold

| Outer tournament | Candidate | Family/status | Fallback reason |
|---|---|---|---|
| `wc2002` | `raw_identity` | raw fallback | `insufficient_nested_support` |
| `euro2004` | `raw_identity` | raw fallback | `insufficient_nested_support` |
| `wc2006` | `raw_identity` | raw fallback | `insufficient_nested_support` |
| `euro2008` | `vector_w60_p0p001` | vector scaling / fitted | — |
| `wc2010` | `raw_identity` | raw fallback | `no_eligible_improvement` |
| `euro2012` | `vector_w60_p0p001` | vector scaling / fitted | — |
| `wc2014` | `vector_w60_p0p010` | vector scaling / fitted | — |
| `euro2016` | `vector_w60_p0p001` | vector scaling / fitted | — |
| `wc2018` | `vector_w60_p0p010` | vector scaling / fitted | — |
| `euro2020` | `vector_w60_p0p010` | vector scaling / fitted | — |
| `wc2022` | `vector_w400_p0p010` | vector scaling / fitted | — |
| `euro2024` | `vector_w400_p0p010` | vector scaling / fitted | — |

Final post-pass fit: `vector_w400_p0p010`, warm-up `400`, vector penalty `0.01`, deterministic optimizer seed `116450559`.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 1 RED:** `c730ca4` — failing nested calibration contracts.
2. **Task 1 GREEN:** `4484031` — frozen nested selector, replay fits, and raw fallback.
3. **Task 2 RED:** `5f55988` — failing complete immutable-graph contracts.
4. **Task 2 GREEN:** `7412cc6` — 12-fold/630-fixture graph and post-pass calibrator.
5. **Focused regression RED:** `7d6fd0b` — option-independent candidate-ID contract.
6. **Focused regression GREEN:** `b48779c` — canonical candidate formatting and rebound manifest.

## Files Created/Modified

- `R/release/calibration_remediation.R` — frozen contract, transforms, nested selection, graph builder, gate evaluator, and producer validator.
- `tests/testthat/test_phase14_calibration_remediation.R` — leakage, support, replay, tamper, holdout, authority, and post-pass-fit regression coverage.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/remediation_contract.csv` — 45 frozen candidate rows and canonical row hashes.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/outer_fold_selection.csv` — outer selection, nested lineage, support, ranking, dates, and fit links.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/outer_fold_fits.csv` — 12 replay-sufficient fitted/fallback parameter rows.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibrator.rds` — final post-pass vector candidate.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibrated_predictions.csv` — all 630 outer predictions with unchanged identities and audit lineage.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibration_gate.csv` — zero-reason unchanged Phase 12 outer decision.
- `outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/calibration_revision_manifest.csv` — authority/input/output hashes plus manifest self-hash.

## Decisions Made

- Raw fallback remains an explicit candidate with identity parameters and `not_run` optimizer state, preserving forecast availability whenever nested support is insufficient or no candidate is eligible.
- Inner ranking invokes the unchanged canonical `phase12_selection_decision()` in an isolated environment containing one already-validated immutable protocol object; this avoids repeated registry validation without copying or relaxing gate logic.
- The approved candidate graph does not itself mutate release authority. Independent Plan 14-22 acceptance remains required before FORECAST-01 can be completed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed redundant nested-evaluation work without changing the frozen search**
- **Found during:** Task 1 tracer verification
- **Issue:** Repeated warm-up-equivalent optimizer fits, row-wise transforms, long-form score rebuilding, and repeated protocol checksum validation made exhaustive nested replay impractical.
- **Fix:** Cached only mathematically identical deterministic fits, supplied exact optimizer gradients, vectorized fit application/metric calculation, and invoked the unchanged canonical Phase 12 decision with one prevalidated protocol object.
- **Files modified:** `R/release/calibration_remediation.R`, `tests/testthat/test_phase14_calibration_remediation.R`
- **Verification:** Fast metrics and decisions match the canonical Phase 12 scorer/decision to `1e-15`; all frozen candidates still run.
- **Committed in:** `4484031`

**2. [Rule 1 - Bug] Normalized empty zero-reason CSV fields before canonical hash replay**
- **Found during:** Task 2 isolated dry-run validation
- **Issue:** A zero-reason gate serialized `reason_codes` as an empty string, which `read.csv()` inferred as `NA` when the entire column was empty.
- **Fix:** Normalize that documented empty value before gate/manifest self-hash verification.
- **Files modified:** `R/release/calibration_remediation.R`
- **Verification:** Isolated and durable graph builds both pass full producer validation.
- **Committed in:** `7412cc6`

**3. [Rule 1 - Bug] Made candidate IDs independent of global R display precision**
- **Found during:** Post-commit exact-metrics validation with `options(digits = 17)`
- **Issue:** `format()` allowed global display precision to alter vector candidate IDs during contract regeneration.
- **Fix:** Use fixed two-decimal scalar and three-decimal vector labels, then rebind only the manifest producer-code and self hashes.
- **Files modified:** `R/release/calibration_remediation.R`, `tests/testthat/test_phase14_calibration_remediation.R`, `calibration_revision_manifest.csv`
- **Verification:** 126 tests and promoted producer validation pass under default and 17-digit display precision.
- **Committed in:** RED `7d6fd0b`, GREEN `b48779c`

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocking performance issue).  
**Impact on plan:** All fixes preserve the exact grids, canonical Phase 12 gates, artifact identities, and approved empirical result; no scope or authority expansion occurred.

## Verification

- Plan verification: `126` passed, `0` failed, `0` warned, `0` skipped.
- Producer validation: `phase14_validate_calibration_remediation(..., require_promoted = TRUE)` passed in a fresh R process and under `options(digits = 17)`.
- Phase 12 focused regression: `76` passed, `0` failed, `0` skipped after task commits.
- Original Phase 14 calibration-release regression: `93` passed, `0` failed; two pre-existing Wave 0 API guard tests remained intentionally skipped.
- Protected-file audit: original Plan 14-04 gate/manifest, Phase 12 selector/recipe/freeze, model/seed registries, and WC2026 evidence have no working-tree or Plan 14-21 commit diff.

## Known Stubs

None.

## Threat Flags

None. New file-access and candidate-graph trust boundaries were declared in the plan threat model and are covered by hash, holdout, tamper, and authority tests.

## Issues Encountered

- The first broader Phase 12 test run intentionally failed seven cases with `phase12_code_dirty` while Task 2 source/artifacts were uncommitted. The same file passed all 76 assertions after the task commit, confirming no Phase 12 regression.

## User Setup Required

None.

## Next Phase Readiness

- Plan 14-22 can independently validate and accept or reject this separately rooted approved candidate graph.
- FORECAST-01 remains addressed but incomplete until that independent acceptance updates release authority; this plan did not bypass or perform that mutation.

## Self-Check: PASSED

- All nine declared implementation/artifact files and this summary exist.
- All six RED/GREEN/fix commits resolve in git.
- The promoted graph validates from durable bytes, and protected authority paths remain unchanged.

---
*Phase: 14-shared-competition-state-and-forecast-layer*
*Completed: 2026-08-17*
