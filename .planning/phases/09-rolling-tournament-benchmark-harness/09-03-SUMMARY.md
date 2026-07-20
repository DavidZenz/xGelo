---
phase: 09-rolling-tournament-benchmark-harness
plan: "03"
subsystem: evaluation-governance
tags: [r, testthat, proper-scoring, tournament-bootstrap, calibration, promotion-protocol, sha256]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    plan: "02"
    provides: common benchmark contracts, frozen panels/models/seeds, baseline adapters, and normalized score-support audit
provides:
  - Tournament-first proper scores and fixed-bin calibration on the locked 12-edition estimand
  - Exact paired fixture comparisons with 12-fold deltas, breadth, regression, LOTO, and deterministic tournament bootstrap
  - Canonical checksum-backed D-16 through D-20 promotion protocol and pure ordered gate
  - Rich-panel production-hybrid gate plus mandatory 630-fixture open-core companion gate
affects: [09-04-runner, phase-10-challengers, phase-11-hybrid-models, phase-12-model-release]

tech-stack:
  added: []
  patterns: [tournament-first aggregation, fixed shared calibration bins, tournament-level paired bootstrap, retain-incumbent governance, canonical JSON self-checksum]

key-files:
  created:
    - R/evaluation/benchmark_scores.R
    - tests/testthat/test_benchmark_scoring.R
    - R/evaluation/promotion.R
    - tests/testthat/test_benchmark_promotion.R
    - data/benchmark/phase09/promotion_protocol.json
  modified: []

key-decisions:
  - "Use the registered 920001 seed for exactly 10,000 type-8 bootstrap replicates over 12 paired tournament deltas, never fixtures."
  - "Canonicalize recursively sorted JSON without the self-referential protocol_sha256 field, then store and verify that SHA-256 in the protocol."
  - "Classify hard contract, observed coverage, provenance, licensing, checksum, freeze, and reproducibility failures as vetoes; clean statistical misses retain the incumbent."
  - "Derive rich-panel eligibility only from post-adapter output completeness, frozen point-in-time provenance, and the per-edition floor, while requiring the open companion on all 630 fixtures."

patterns-established:
  - "Shared estimand: score fixtures once, average within edition, then average all 12 edition means equally; pooled fixtures remain a labelled secondary estimate."
  - "Promotion inputs remain full precision; inclusive and strict operators are evaluated directly without display rounding."
  - "Optional-data promotion is conjunctive: rich effect/uncertainty/breadth/regression plus a complete non-regressing default-open companion and all common vetoes."

requirements-completed: [BENCH-05]

coverage:
  - id: D1
    description: "Shared fixture scorer emits locked proper scores, fixed tournament-weighted calibration, equal-tournament headlines, and inspectable paired diagnostics."
    requirement: BENCH-05
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_scoring.R"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_worldcup_scoring.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-16 through D-20 promotion gates are boundary-exact for core, rich, and open-companion comparisons with ordered machine-readable reasons."
    requirement: BENCH-05
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_promotion.R"
        status: pass
    human_judgment: false
  - id: D3
    description: "Canonical promotion JSON binds all tournament, fixture, panel, feature, model, seed, and normalized support-audit hashes before WC2026 labels can be opened."
    requirement: BENCH-05
    verification:
      - kind: integration
        ref: "load_promotion_protocol('data/benchmark/phase09/promotion_protocol.json')"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_benchmark_promotion.R#normalized audit and parent tampering"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-07-20
status: complete
---

# Phase 09 Plan 03: Scoring, Uncertainty, and Promotion Protocol Summary

**A single tournament-weighted scorer now feeds a checksum-frozen promotion gate with exact paired uncertainty, rich-panel evidence, and mandatory open-core non-regression.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-07-20T19:03:45Z
- **Completed:** 2026-07-20T19:21:16Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added shared fixture scoring for normalized 1X2 RPS, multiclass Brier, natural-log loss, joint scoreline log loss, goal-marginal RPS, totals, BTTS, exact-score hits, and descriptive winner accuracy.
- Added explicit tournament, equal-tournament headline, and fixture-weighted pooled grains; fixed `[0,.1), ... [.9,1]` one-vs-rest bins give each tournament equal calibration weight.
- Added exact candidate/incumbent fixture pairing, all 12 fold deltas, World Cup/Euro breadth, maximum positive regression, leave-one-tournament-out stability, and a deterministic 10,000-replicate type-8 tournament bootstrap.
- Froze D-16 through D-20 in canonical JSON, including all threshold operators, ordered vetoes, incumbent/panel/seed identities, model registration/settings hashes, selected G=40, and the complete normalized support-audit hash.
- Enforced the same rich-panel practical-effect and uncertainty gate against `production_hybrid_nb`, plus the mandatory 630-fixture open companion against `open_nb_incumbent` with its exact non-regression boundaries.

## Task Commits

Each task followed RED/GREEN TDD and was committed atomically:

1. **Task 1 RED: Benchmark scoring contracts** - `b5c9f48` (test)
2. **Task 1 GREEN: Tournament-weighted scoring and paired diagnostics** - `8e03da3` (feat)
3. **Task 2 RED: Promotion and protocol boundary contracts** - `02300fd` (test)
4. **Task 2 GREEN: Frozen promotion protocol and pure gate** - `59db14c` (feat)

## Files Created/Modified

- `R/evaluation/benchmark_scores.R` - Shared fixture scoring, tournament-first summaries, fixed calibration, exact pairing, bootstrap, breadth, regression, and LOTO diagnostics.
- `tests/testthat/test_benchmark_scoring.R` - Hand calculations, unequal-size weighting, fixed bins, exact coverage, row-order invariance, and deterministic tournament-bootstrap tests.
- `R/evaluation/promotion.R` - Canonical protocol hashing/loading/validation, ordered vetoes, core/rich/open gates, and deterministic candidate selection.
- `tests/testthat/test_benchmark_promotion.R` - Immediate-below/exact/immediate-above boundaries, every common veto, observed rich coverage, support-audit tampering, self-comparison, and tie-break tests.
- `data/benchmark/phase09/promotion_protocol.json` - Frozen protocol checksum `5535217768e395990c7717e2c607904635ce373f6cd4730ecac2f4bbe72aa08d`, support-audit hash `95cbdefb0a6bf569c94657849db63bb350cfe8a4ec6c46651d6844b4e93b15c9`, and selected G=40.

## Decisions Made

- The paired interval samples only the 12 tournament deltas with seed `920001`, 10,000 replicates, and type-8 quantiles. This matches the equal-tournament estimand and cannot silently become a fixture bootstrap.
- The protocol self-checksum covers recursively key-sorted canonical JSON while excluding only its own `protocol_sha256` field. All bound registry and support-audit hashes remain inside the checksum payload.
- Hard evidence/contract failures return `veto`; fully valid candidates that miss an effect, uncertainty, breadth, regression, or supporting-score threshold return `retain_incumbent`.
- Rich declarations alone confer no eligibility. Every declared output must be observed complete after adapter generation, provenance must pass, every edition must meet the frozen floor, and the open companion must remain complete and default-open compatible.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## TDD Gate Compliance

- Task 1 RED failed because `R/evaluation/benchmark_scores.R` did not exist, then GREEN passed the new scoring suite and inherited World Cup score regressions.
- Task 2 RED failed because `R/evaluation/promotion.R` did not exist, then GREEN passed the full exact-boundary and protocol-tampering suite.
- RED and GREEN commits are present in order for both tasks.

## Verification

- `test_benchmark_scoring.R` — passed, including hand-calculated scores, unequal tournament sizes, fixed bins, exact paired scope, 12 folds, LOTO, and 10,000 tournament replicates.
- `test_benchmark_promotion.R` — passed, including all core/rich/open boundaries, supporting vetoes, observed coverage, parent-hash tampering, self-comparison, and deterministic tie-breaks.
- `test_benchmark_contracts.R`, `test_benchmark_baselines.R`, and `test_worldcup_scoring.R` — passed with no failures or warnings.
- Independent protocol load reproduced SHA-256 `5535217768e395990c7717e2c607904635ce373f6cd4730ecac2f4bbe72aa08d`, support-audit SHA-256 `95cbdefb0a6bf569c94657849db63bb350cfe8a4ec6c46651d6844b4e93b15c9`, selected G=40, 10,000 replicates, and seed 920001.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 09-04 can wire one scorer and one promotion service into the cache-only runner and targets DAG.
- Phase 10 and Phase 11 challengers can now be evaluated on identical fixtures, folds, seeds, metrics, and frozen gate semantics.
- No blockers remain; WC2026 labels are still sealed and the protocol exposes no development opening path.

## Self-Check: PASSED

- All five plan-owned implementation, test, and protocol files plus this summary exist on disk.
- Task commits `b5c9f48`, `8e03da3`, `02300fd`, and `59db14c` are present in git history.
- The combined scoring, promotion, contract, baseline, and World Cup scoring suites pass without failures or warnings.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-20*
