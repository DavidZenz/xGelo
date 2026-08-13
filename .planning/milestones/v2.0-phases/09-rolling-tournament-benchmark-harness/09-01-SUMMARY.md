---
phase: 09-rolling-tournament-benchmark-harness
plan: "01"
subsystem: benchmark-infrastructure
tags: [r, testthat, rolling-origin, sha256, provenance, leakage-prevention]

requires:
  - phase: 08-forecast-ledger-and-wc-2026-retrospective
    provides: strict pre-kickoff scoring, immutable ledger, and checksum patterns
provides:
  - Frozen 12-edition, 630-fixture World Cup and Euro benchmark registry
  - Date-complete frozen and updating boundary state service
  - Purpose-gated World Cup 2026 outcome seal
  - Canonical SHA-256 and project-local provenance validation
affects: [09-02-model-contracts, 09-03-promotion, 09-04-runner, phase-10-challengers, phase-11-hybrid-models]

tech-stack:
  added: []
  patterns: [registry-first evaluation, strict-exclusive cutoffs, canonical row hashing, pre-adapter holdout sealing]

key-files:
  created:
    - R/benchmark/registry.R
    - R/benchmark/cutoffs.R
    - data/benchmark/phase09/fixtures.csv
    - data/benchmark/phase09/boundaries.csv
    - data/benchmark/phase09/corrections.csv
    - tests/testthat/helper_benchmark.R
    - tests/testthat/test_benchmark_registry.R
    - tests/testthat/test_benchmark_cutoffs.R
    - tests/testthat/test_benchmark_seal.R
  modified: []

key-decisions:
  - "Represent historical groups with stable edition-local component IDs rather than infer unverified display letters."
  - "Derive regulation scores from checked local goal events through minute 90 while retaining final and shootout outcomes separately."
  - "Permit absolute registry paths only when they normalize inside the single approved project registry root."

patterns-established:
  - "Validate then consume: schema, cardinality, keys, provenance, and hashes all pass before adapters receive data."
  - "Date-complete updates: every fixture completed on date d uses one state containing only evidence strictly before d."
  - "Seal before callback: forbidden WC2026 labels are rejected before any adapter invocation."

requirements-completed: [BENCH-01, BENCH-02, BENCH-03]

coverage:
  - id: D1
    description: "Canonical 12-tournament and 630-fixture registry with stable team/FIFA identities, format routes, and verified correction lineage"
    requirement: BENCH-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_benchmark_registry.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Frozen and updating date-batch states enforce strict prior-only evidence with stable hashes"
    requirement: BENCH-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_cutoffs.R"
        status: pass
    human_judgment: false
  - id: D3
    description: "World Cup 2026 outcomes cannot enter fitting, selection, tuning, or calibration callbacks"
    requirement: BENCH-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_benchmark_seal.R"
        status: pass
    human_judgment: false
  - id: D4
    description: "Historical regulation and shootout corrections retain source titles, URLs, local artifacts, licenses, and matching SHA-256 values"
    requirement: BENCH-03
    verification:
      - kind: integration
        ref: "row-by-row local goalscorer/shootout reconciliation command from Plan 09-01 execution"
        status: pass
    human_judgment: true
    rationale: "Phase 09 validation retains a final human governance review of authoritative source attribution before the full benchmark freeze."

duration: 21min
completed: 2026-07-20
status: complete
---

# Phase 09 Plan 01: Historical Registry and Leakage Boundary Summary

**A locally auditable 630-fixture tournament denominator with deterministic date-batch cutoffs, canonical hashes, and a pre-adapter World Cup 2026 outcome seal**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-20T17:58:09Z
- **Completed:** 2026-07-20T18:19:00Z
- **Tasks:** 3
- **Files modified:** 14

## Accomplishments

- Frozen the six World Cups and six Euros in D-01 as 630 checked fixtures, 72 stable team identities, three format families, 76 route rules, and 284 boundaries.
- Reconciled all assessment goals to the local event archive and recorded 72 regulation/shootout corrections with verified local source SHA-256 values.
- Added fail-fast registry/path/provenance validators, order-stable manifests, strict date-complete state construction, and adversarial WC2026 seal tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Wave 0 benchmark fixtures and executable contract tests** - `9323851` (test)
2. **Task 2: Curate and freeze the canonical historical registries** - `3218492` (feat)
3. **Task 3: Implement registry validation, deterministic boundaries, and the WC2026 seal** - `c498a4c` (feat)

Task 3 followed the plan's TDD contract: Task 1 supplied the committed RED tests, the missing services failed for the expected reason, and `c498a4c` supplied the GREEN implementation.

## Files Created/Modified

- `R/benchmark/registry.R` - Safe loaders, relational validation, local provenance checks, canonical SHA-256, and completion manifests.
- `R/benchmark/cutoffs.R` - Frozen/updating boundary generation, strict history selection, track states, and the WC2026 purpose gate.
- `data/benchmark/phase09/{tournaments,fixtures,teams,formats,route_rules,corrections,boundaries}.csv` - Referentially closed benchmark source of truth.
- `data/benchmark/phase09/SOURCES.md` - Human-readable source inventory and all 72 correction records.
- `tests/testthat/helper_benchmark.R` - Synthetic registries, histories, formats, distributions, and recording adapter.
- `tests/testthat/test_benchmark_{registry,cutoffs,seal}.R` - Cardinality, identity, tampering, cutoff, determinism, and sealed-holdout contracts.

## Decisions Made

- Group membership is stored as stable edition-local connected-component IDs. The source data prove membership but not display letters, so the registry does not fabricate them.
- Regulation targets count checked goals through minute 90; upstream final scores and shootout winners remain separate fields and provenance records.
- Registry path validation allows a caller's canonical absolute path only when it remains inside `data/benchmark/phase09`; traversal and external roots fail before reads.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved schema versions across CSV type inference**
- **Found during:** Task 3 GREEN verification
- **Issue:** Base R inferred `schema_version = "1.0"` as numeric `1`, causing valid row hashes to fail after loading.
- **Fix:** Normalize the parsed schema version back to its registered string representation before canonical hash validation.
- **Files modified:** `R/benchmark/registry.R`
- **Verification:** Full registry validation and row-hash tampering tests pass.
- **Committed in:** `c498a4c`

**2. [Rule 1 - Bug] Corrected order-agnostic test assertions**
- **Found during:** Task 3 GREEN verification
- **Issue:** Two tests compared table/Date vectors with incidental class or row-order attributes despite the production contract intentionally canonicalizing order.
- **Fix:** Compare integer denominators and align opener dates by `edition_id`; added frozen-boundary hash reconciliation.
- **Files modified:** `tests/testthat/test_benchmark_registry.R`, `tests/testthat/test_benchmark_cutoffs.R`
- **Verification:** All focused and legacy regression tests pass without warnings.
- **Committed in:** `c498a4c`

---

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both fixes preserve the intended canonical-order and byte-stable hash contracts; no scope was added.

## Issues Encountered

- The first sandboxed Git staging attempt could not create `.git/index.lock`; the same scoped normal commit was rerun with repository-write approval and hooks enabled.
- No correction required a blocking approval checkpoint: every correction reconciled to a checked local source row and matching artifact hash.

## Verification

- Focused Wave 0 suite: 57 expectations passed across registry, cutoff, and seal tests.
- Required legacy regressions: 126 expectations passed across Transfermarkt benchmark, World Cup scoring, and World Cup retrospective tests.
- Registry regeneration was byte-stable; the completion manifest sealed seven artifacts with canonical SHA-256 values.
- All 1,260 fixture-track states used evidence strictly before their exclusive cutoff.

## User Setup Required

None - no external service configuration or runtime network access was added.

## Next Phase Readiness

- Plan 09-02 can consume the sealed registry manifest and common boundary states immediately.
- The phase-level governance review should still confirm source-attribution quality before the final pre-WC2026 benchmark freeze; no unresolved local provenance blocks implementation.

## Self-Check: PASSED

- All 14 plan-owned implementation, registry, and test files exist.
- Task commits `9323851`, `3218492`, and `c498a4c` are present in Git history.
- Coverage metadata parsed successfully with no schema errors.

---
*Phase: 09-rolling-tournament-benchmark-harness*
*Completed: 2026-07-20*
