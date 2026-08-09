---
phase: 11-hybrid-ml-and-contextual-priors
plan: 06
subsystem: benchmark
tags: [hybrid, random-forest, targets, proper-scores, research-only]

requires:
  - phase: 11-05
    provides: Phase 11 registries, adapters, protocol contracts, and optional-mode gates
provides:
  - Targets-integrated Phase 11 hybrid challenger evaluation
  - Sealed, checksum-validated research-only benchmark bundle
  - Exact open/rich comparison evidence and Phase 12 shortlist handoff
affects: [phase12-handoff, benchmark-validation]

tech-stack:
  added: []
  patterns: [track-isolated adapters, point-in-time feature replay, staged checksum manifests, fail-closed optional modes]

key-files:
  created:
    - outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/run_manifest.csv
    - outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/manifests/checksum_manifest.csv
    - outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/hybrid_shortlist.csv
    - .planning/phases/11-hybrid-ml-and-contextual-priors/11-06-SUMMARY.md
  modified:
    - _targets.R
    - R/benchmark/hybrid_runner.R
    - R/evaluation/challenger_selection.R
    - tests/testthat/test_hybrid_targets.R

key-decisions:
  - "The Phase 11 leaderboard remains open-default research evidence; enriched and external modes are companion evidence only."
  - "Context candidates remain explicitly inactive when strict common-panel travel evidence is unavailable; no imputation is permitted."
  - "Comparison denominator validation sums the 12 fold rows and separately checks exact headline/pooled denominators."

patterns-established:
  - "Every forecast track receives isolated fixture sequences, seed views, and score-distribution namespaces."
  - "All persisted candidate, comparison, mode, and shortlist rows carry research-only and sealed-WC2026 flags."

requirements-completed: [HYBRID-01, HYBRID-02, HYBRID-03, HYBRID-04, HYBRID-05]

coverage:
  - id: D1
    description: "Six-node Phase 11 targets DAG runs downstream from Phase 09/10 and local Phase 11 registries."
    requirement: HYBRID-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_hybrid_targets.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Canonical hybrid bundle contains exact 630 open, 609 rich, and G=40 evidence with checksums."
    requirement: HYBRID-02
    verification:
      - kind: integration
        ref: "validate_hybrid_challenger_bundle(outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers)"
        status: pass
      - kind: other
        ref: "run_manifest.csv plus score_distributions.csv row/count inspection"
        status: pass
    human_judgment: false
  - id: D3
    description: "Optional xG, context, structural, enriched, and external modes are separated and fail closed with explicit reasons."
    requirement: HYBRID-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_xg_gate.R"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_hybrid_structural_prior.R"
        status: pass
      - kind: other
        ref: "modes/mode_registry.csv and selection/candidate_evidence.csv"
        status: pass
    human_judgment: false
  - id: D4
    description: "Research-only comparisons and a non-exclusive evidence-linked shortlist are ready for Phase 12."
    requirement: HYBRID-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_targets.R"
        status: pass
      - kind: other
        ref: "selection/all_baseline_paired_comparisons.csv and selection/hybrid_shortlist.csv"
        status: pass
    human_judgment: false
  - id: D5
    description: "Protected-path flags seal WC2026 and keep Phase 12 as the only decision authority."
    requirement: HYBRID-05
    verification:
      - kind: integration
        ref: "research_only_report.txt and run_manifest.csv flag validation"
        status: pass
    human_judgment: false

metrics:
  duration: 12h 51m
  completed: 2026-08-09
status: complete
---

# Phase 11 Plan 06: Targets-integrated hybrid challenger research bundle

**Deterministic Phase 11 RF hybrid evaluation with exact open/rich panels, G=40 score grids, sealed research flags, checksums, comparisons, and a Phase 12 evidence shortlist.**

## Performance

- **Duration:** 12h 51m
- **Started:** 2026-08-08T22:39:46Z
- **Completed:** 2026-08-09T11:30:23Z
- **Tasks:** 2
- **Files modified or created:** 20 implementation and bundle files, plus this summary

## Accomplishments

- Added the six-node `benchmark_phase11_*` targets chain with explicit Phase 09/10, Phase 11 registry, runtime, and local feature parents.
- Ran the full deterministic hybrid challenger evaluation without opening WC2026 holdout data; the manifest records `open_fixture_count=630`, `rich_fixture_count=609`, `selected_g=40`, `research_only=TRUE`, `wc2026_sealed=TRUE`, `network_free=TRUE`, and `phase12_decision_authority=FALSE`.
- Published and validated the canonical bundle at `outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/`: 1,260 active predictions (630 frozen, 630 updating), 1,260 score-distribution IDs, 2,118,060 score cells (1,681 per ID; goals 0–40), 20 SHA-256 parent inputs, 449 comparison rows, and three non-exclusive shortlist rows.
- Kept optional modes fail-closed: seven context candidates are inactive for missing/imputed `travel_km`, xG-gated evidence is inactive because its gate fails, structural prior evidence is inactive because the snapshot lacks PRK, and the external market mode is inactive because its manual snapshot is absent.

## Task Commits

Each task was committed atomically:

1. **Task 1: Phase 11 runner, comparisons, and research shortlist** - `83d0d9f` (test), `48061a8` (feat)
2. **Task 2: Targets chain and canonical bundle publication** - `431c33d` (test), `16ff9e5` (feat)

## Files Created/Modified

- `_targets.R` - Phase 11 registry, prediction, scoring, comparison, and bundle targets with downstream-only ancestry.
- `R/benchmark/hybrid_runner.R` - deterministic runner, track isolation, point-in-time Elo, context fail-closed handling, exact-panel validation, staged bundle writer, and checksums.
- `R/evaluation/challenger_selection.R` - open-only paired comparisons and evidence-linked research shortlist.
- `tests/testthat/test_hybrid_targets.R` - DAG, flag, distribution-namespace, and denominator-contract tests.
- `outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/` - durable predictions, distributions, scores, manifests, modes, comparisons, report, and shortlist.

## Decisions Made

- Open-default evidence is the only leaderboard pool. Enriched squad data and external market references remain separate companion modes and cannot enter open comparisons.
- Missing context evidence causes explicit inactive evidence rather than imputation. This preserves the strict common-panel contract and prevents silent optional-data activation.
- Score-distribution IDs are namespaced by forecast track because public adapter IDs repeat across frozen/updating tracks while the durable bundle requires globally unique distribution identities.
- The targets run used an isolated temporary targets store (`/private/tmp/xgelo-phase11-debug-2`) to protect shared project state; it wrote and validated the canonical output directory.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added a plan-local targets import-cycle compatibility shim**
- **Found during:** Task 2 (targets chain)
- **Issue:** The pre-existing validator/helper import cycle prevented targets graph loading in the Phase 11 execution environment.
- **Fix:** Added a lazy, local source shim in `_targets.R` for the validator dependencies without changing unrelated context tests or global package structure.
- **Verification:** `test_hybrid_targets.R` and the full Phase 11 targets chain pass.
- **Committed in:** `16ff9e5`

**2. [Rule 2 - Missing Critical] Enforced point-in-time Elo and dynamic feature replay**
- **Found during:** Task 2 (prediction target)
- **Issue:** The benchmark feature file alone did not provide the strict replay guarantees needed for frozen rolling evaluation.
- **Fix:** Replayed dynamic goal ability and sourced Elo strictly before each evidence cutoff, with explicit source dates and missingness fields.
- **Verification:** Full deterministic target run and bundle validation pass.
- **Committed in:** `16ff9e5`

**3. [Rule 1 - Bug] Isolated track identities and score-distribution namespaces**
- **Found during:** Task 2 (prediction validation)
- **Issue:** Shared public fixture/distribution identities caused cross-track collisions and duplicate-cell validation failures.
- **Fix:** Reset internal per-track sequences and namespace distribution IDs while preserving public forecast sequence values; repeated 41x41 cells within each distribution remain valid.
- **Verification:** Distribution namespace test passes; bundle contains exactly 1,681 rows per ID and validates.
- **Committed in:** `16ff9e5`

**4. [Rule 2 - Missing Critical] Kept optional context, xG, structural, and market paths fail-closed**
- **Found during:** Task 2 (candidate execution)
- **Issue:** The strict open panel lacks complete travel context, the xG gate fails, the structural snapshot lacks PRK, and the manual market snapshot is unavailable.
- **Fix:** Persisted explicit inactive candidate/mode evidence and reasons; no imputation, automatic collection, or restricted raw-data publication was added.
- **Verification:** Mode and candidate evidence inspection plus bundle validation pass.
- **Committed in:** `16ff9e5`

**5. [Rule 1 - Bug] Corrected exact comparison denominator validation**
- **Found during:** Task 2 (post-evaluation bundle validation)
- **Issue:** The first validator incorrectly required every diagnostic row, including per-edition folds and NA-denominator diagnostics, to equal 630/609.
- **Fix:** Validate 12 fold rows by exact summed denominator and separately validate headline/pooled rows at 630/609.
- **Verification:** Regression test passes; corrected full target run and canonical bundle validation pass.
- **Committed in:** `16ff9e5`

**Total deviations:** 5 auto-fixed (Rules 1–3)
**Impact on plan:** All fixes were directly required for deterministic correctness, leakage prevention, or fail-closed security boundaries; no scope creep was introduced.

## Issues Encountered

- `tests/testthat/test_hybrid_context_features.R` retains the pre-existing Phase 11 context-registry mismatch documented by Plan 11-05: it expects seven candidates while the merged registry exposes nine, including the xG-gated and structural candidates. The test reports two expectation failures; it was not modified because the mismatch is outside this plan unless it blocks execution. The Phase 11 target and bundle execute those candidates as explicit inactive evidence.
- No authentication or external-service gates occurred.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 12 has a durable, hash-linked research evidence bundle and non-exclusive shortlist. The bundle is sealed against WC2026, carries no promotion/release authority, and does not update the dashboard. `STATE.md` and `ROADMAP.md` were intentionally left untouched per the execution request so the orchestrator can update shared tracking.

---
*Phase: 11-hybrid-ml-and-contextual-priors*
*Completed: 2026-08-09*

## Self-Check: PASSED

- Summary file exists at the required phase path.
- Task commits `83d0d9f`, `48061a8`, `431c33d`, and `16ff9e5` are present in git history.
- Canonical bundle validation passed before summary creation.
