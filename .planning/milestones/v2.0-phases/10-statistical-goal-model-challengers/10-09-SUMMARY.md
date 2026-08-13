---
phase: 10-statistical-goal-model-challengers
plan: "09"
subsystem: benchmark-protocol
tags: [r, canonical-hashing, chronology, selection-governance, storage-preflight]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: accepted checksum-backed rolling benchmark bundle and exact parent graph
  - phase: 10-statistical-goal-model-challengers
    provides: verified glmnet 5.0 environment and immutable Phase 9 preflight from Plan 10-02
provides:
  - Exact seven-candidate Phase 10 overlay with canonical parent, feature, tuning, and chronology validation
  - Research-only ablation and selection protocol with frozen thresholds and recursive no-decision boundary
  - Deterministic measured 2,118,060-row G=40 storage pilot and fail-closed projection gate
affects: [10-03, 10-04, 10-05, 10-06, 10-07, 10-08, phase12-model-release]

tech-stack:
  added: []
  patterns: [canonical expected-artifact reconstruction, mutation-complete fail-closed validation, deterministic streaming storage pilot]

key-files:
  created:
    - R/benchmark/challenger_protocol.R
    - data/benchmark/phase10/model_registry.csv
    - data/benchmark/phase10/feature_contract.csv
    - data/benchmark/phase10/tuning_editions.csv
    - data/benchmark/phase10/tuning_grid.csv
    - data/benchmark/phase10/ablation_registry.csv
    - data/benchmark/phase10/selection_protocol.json
    - data/benchmark/phase10/storage_preflight.csv
    - tests/testthat/test_statistical_registry_protocol.R
    - tests/testthat/test_statistical_storage_preflight.R
  modified: []

key-decisions:
  - "Reconstruct the Phase 9 model-registry identity from its normalized canonical table and require agreement with both durable manifests, rather than confusing the canonical SHA with raw CSV bytes."
  - "Represent every chronology edge with an exact eligible-match-ID hash from the four pre-2002 editions and all strictly prior Phase 9 assessment editions."
  - "Keep Phase 10 selection vocabulary research-only and recursively reject promotion, release, final-holdout, and WC2026 decision surfaces."
  - "Freeze the storage gate from two byte-identical seeded gzip pilots instead of an estimated fixed-GiB allowance."

patterns-established:
  - "Canonical overlay: builders define exact schemas, row order, values, foreign keys, and hashes; persisted files must match byte-level scalar representations after independent hash recomputation."
  - "Research boundary: shortlist evidence remains structurally unable to invoke or encode a release decision."
  - "Storage evidence: cardinality, compressed footprint, replay hash, projections, worker ceiling, and current free space are independently recomputed."

requirements-completed: [STAT-01, STAT-02, STAT-03, STAT-04]

coverage:
  - id: D1
    description: "Exact Phase 9 parent, seven candidates, 33-row tuning grid, 114-row chronology, and pre-2002 diagnostic are canonical and fail closed."
    requirement: STAT-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_statistical_registry_protocol.R"
        status: pass
      - kind: other
        ref: "run_pre2002_grid_diagnostic()"
        status: pass
    human_judgment: false
  - id: D2
    description: "Complete ablation graph, ten thresholds, three shortlist slots, and recursive no-decision boundary are frozen."
    requirement: STAT-04
    verification:
      - kind: integration
        ref: "tests/testthat/test_statistical_storage_preflight.R#ablation and selection mutation matrix"
        status: pass
    human_judgment: false
  - id: D3
    description: "Exact-cardinality production-schema storage pilot is byte-deterministic and its projection/free-space formula is validated."
    requirement: STAT-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_statistical_storage_preflight.R#storage preflight"
        status: pass
      - kind: other
        ref: "measure_challenger_partition_storage() full 2,118,060-row replay"
        status: pass
    human_judgment: false

duration: 20 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 09: Canonical Challenger Protocol Summary

**Checksum-reconstructed Phase 9 parenting, exact challenger/chronology/selection contracts, and a measured deterministic G=40 storage gate now prevent post-outcome protocol discovery.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-22T13:28:58Z
- **Completed:** 2026-07-22T13:49:09Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Reconstructed the exact accepted Phase 9 bundle, normalized model-registry, checksum-self, and parent-graph identities before validating seven ordered Phase 10 candidates, 49 feature rows, 33 tuning rows, and 114 chronology relations.
- Froze the six-node ablation graph, ten numerical selection thresholds, three non-exclusive shortlist slots, exact dependence preferences, and recursive rejection of promotion/release/final-holdout/WC2026 surfaces.
- Streamed two format-identical 2,118,060-row pilots with identical SHA-256 `eb13096422d8482a4ca1450277e31ff516b09a932529d9248e4c0be265075f1f`, measuring 27,170,610 compressed bytes and a 4,170,989,111-byte minimum free-space gate.

## Task Commits

Each TDD task was committed as a failing contract followed by its implementation:

1. **Task 1 RED: canonical parent/registry/grid/chronology contract** — `c8f8a46` (test)
2. **Task 1 GREEN: challenger registry protocol** — `2c49834` (feat)
3. **Task 2 RED: ablation/selection/storage contract** — `635b941` (test)
4. **Task 2 GREEN: selection and measured storage protocol** — `83785f4` (feat)

## Files Created/Modified

- `R/benchmark/challenger_protocol.R` — Canonical builders, parent reconstruction, mutation-proof validators, pre-2002 diagnostic, selection boundary, and storage measurement.
- `data/benchmark/phase10/model_registry.csv` — Seven ordered, parent-bound candidate registrations.
- `data/benchmark/phase10/feature_contract.csv` — Unchanged inherited Phase 9 rows plus eight explicit shrinkage/dynamic/dependence/inactive evidence fields.
- `data/benchmark/phase10/tuning_editions.csv` — Exact 114-row outer-to-strictly-prior-inner relation.
- `data/benchmark/phase10/tuning_grid.csv` — Exact 33-row ridge/lasso/pseudo-exposure/dependence specification.
- `data/benchmark/phase10/ablation_registry.csv` — Root, scored Elo-only child, and four auditable zero-coverage inactive children.
- `data/benchmark/phase10/selection_protocol.json` — Canonical research-only thresholds, operators, fold breadth, dependence preference, and shortlist.
- `data/benchmark/phase10/storage_preflight.csv` — Measured bytes, replay hashes, exact cardinalities, projections, worker ceiling, and free-space result.
- `tests/testthat/test_statistical_registry_protocol.R` — Task 1 identity, mutation, chronology, and diagnostic suite.
- `tests/testthat/test_statistical_storage_preflight.R` — Task 2 ablation, selection, forbidden-surface, and storage mutation suite.

## Measured Storage Values

- Pilot rows: `2,118,060` (`630 fixtures × 2 tracks × 41 × 41`)
- Pilot compressed bytes (`B`): `27,170,610`
- Seven-partition score projection (`7 × B`): `190,194,270`
- One-bundle projection with headroom: `1,263,936,094`
- Minimum free bytes (`ceiling(3 × bundle × 1.10)`): `4,170,989,111`
- Measured available bytes: `17,110,360,064`
- Worker ceiling: `2`
- Free-space gate: passed

## Decisions Made

- Used the Phase 9 runner's normalized canonical model-registry SHA semantics and cross-checked the result against both checksum and run manifests.
- Hashed sorted exact match identities for every eligible inner edition, retaining strict `inner_final_date < outer_opener_date` chronology.
- Kept all deeper xG/form ablations present but inactive because all 20,160 relevant Phase 9 open-core evidence rows are source-absent, value-absent, imputed, and inactive.
- Measured storage with deterministic high-entropy identifiers and normalized probabilities in the exact production score-distribution CSV schema.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The required Phase 9 registry identity is a normalized canonical table SHA, not the raw CSV byte SHA. The validator now recomputes that canonical value and requires exact agreement with both durable parent manifests.
- An initial chronology test used alphabetically ordered `table()` levels; it was corrected to assert counts against the frozen chronological outer-edition order.

## TDD Gate Compliance

- Task 1: RED `c8f8a46` → GREEN `2c49834`.
- Task 2: RED `635b941` → GREEN `83785f4`.
- Both RED failures were caused by missing production APIs, and both final mutation suites pass with warning stops enabled.

## Verification Results

- `test_statistical_registry_protocol.R`: passed all parent, schema, row, order, scalar, hash, chronology, and diagnostic assertions.
- `test_statistical_storage_preflight.R`: passed all ablation, selection, recursive forbidden-surface, storage operand, boolean, formula, and hash assertions.
- `run_pre2002_grid_diagnostic()`: valid; exact editions `wc1994`, `euro1996`, `wc1998`, `euro2000`; maximum evidence date `2000-07-02`; assessment rows absent; before/after grid SHA `3ba5e68f4abfc1f228bc1851d4b87db92737edec6be599d22135f992c56de546`.
- Complete protocol load: 7 candidates, 33 tuning rows, 114 chronology rows, 6 ablation nodes, exact thresholds/shortlist, and current free-space gate passed.
- Phase 9 registry and accepted bundle paths have no tracked diff from the accepted source commit.
- No candidate model was fitted and no 2002-2024 tournament benchmark was run.

## Known Stubs

None. Empty parent IDs, discrete-grid bounds, and source/value fields are intentional canonical contract values, not placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Candidate implementation plans can consume `load_and_validate_challenger_protocol()` without defining grids, chronology, thresholds, ablations, or storage rules elsewhere.
- The storage gate leaves over four times the frozen minimum available at measurement time.
- Final release authority remains outside Phase 10 by construction.

## Self-Check: PASSED

- Verified all 10 planned source, registry, and test files exist.
- Verified task commits `c8f8a46`, `2c49834`, `635b941`, and `83785f4` exist in history.
- Re-ran both task suites, the pre-2002 diagnostic, complete protocol load, and storage formula validation successfully.
- Confirmed no unplanned model fitting, historical benchmark execution, package installation, Phase 9 mutation, or generated pilot file remains.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
