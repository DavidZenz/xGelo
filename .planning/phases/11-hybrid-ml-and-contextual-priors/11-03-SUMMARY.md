---
phase: 11-hybrid-ml-and-contextual-priors
plan: 03
subsystem: forecasting
tags: [r, random-forest, context-features, provenance, ablations, benchmark]

# Dependency graph
requires:
  - phase: 11-hybrid-ml-and-contextual-priors
    provides: sealed open-core RF challenger, common score path, and ranger provenance from plan 11-02
provides:
  - deterministic point-in-time host, neutral, rest, country-proxy travel, and stage evidence
  - committed Natural Earth country-centroid registry with metadata and parent hashes
  - registered context bundle and five one-feature-drop ablations on open_core
  - adapter and runner dispatch through the inherited G=40 common benchmark path
affects: [phase-11-contextual-priors, phase-12-candidate-selection]

# Tech tracking
tech-stack:
  added: [geosphere country-proxy travel, Natural Earth Admin 0 provenance]
  patterns: [strict point-in-time evidence companions, registry-backed drop-one ablations, research-only sealed benchmark candidates]

key-files:
  created:
    - data/benchmark/phase11/country_centroids.csv
    - data/benchmark/phase11/country_centroids_metadata.csv
    - data/benchmark/phase11/context_ablation_registry.csv
  modified:
    - R/forecast/context_features.R
    - R/benchmark/hybrid_protocol.R
    - R/benchmark/hybrid_adapters.R
    - R/benchmark/hybrid_runner.R
    - data/benchmark/phase11/model_registry.csv
    - data/benchmark/phase11/feature_contract.csv
    - tests/testthat/test_hybrid_context_features.R

key-decisions:
  - "Use frozen WGS84 Natural Earth Admin 0 country proxies for travel; do not imply stadium-level travel precision."
  - "Keep the inherited RF tuning and NB distribution identity while assigning each context candidate its own registry and provenance hashes."
  - "Require complete open-context evidence before context fitting or prediction, including ablation runs, so drop-one comparisons retain the common 630/609 panel."

patterns-established:
  - "Fixture-derived context records source/vintage/derivation/missingness companions without fabricating source dates."
  - "Every context candidate is open_default, open_core, research_only, WC2026-sealed, and scored with G=40."

requirements-completed: [HYBRID-02]

coverage:
  - id: D1
    description: "Point-in-time host, neutral, rest, travel, and tournament-stage evidence is built with explicit companions and no silent imputation."
    requirement: HYBRID-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_context_features.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Country-centroid rows and metadata validate offline with source, vintage, license, derivation, and parent SHA-256 provenance."
    requirement: HYBRID-02
    verification:
      - kind: integration
        ref: "Rscript --vanilla -e 'source(\"R/benchmark/hybrid_protocol.R\"); write_phase11_hybrid_protocol()'"
        status: pass
    human_judgment: false
  - id: D3
    description: "The full context bundle and five named drop-one ablations are registry-backed on the unchanged open_core denominator."
    requirement: HYBRID-02
    verification:
      - kind: unit
        ref: "tests/testthat/test_hybrid_context_features.R"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_benchmark_contracts.R"
        status: pass
    human_judgment: false
  - id: D4
    description: "Context candidates dispatch through the common adapter, proper-score runner, and sealed G=40 score-distribution schema."
    requirement: HYBRID-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_hybrid_context_features.R"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_hybrid_random_forest.R"
        status: pass
    human_judgment: false

# Metrics
duration: 18min
completed: 2026-08-08
status: complete
---

# Phase 11 Plan 03: Hybrid ML and Contextual Priors Summary

**Deterministic open tournament-context evidence with provenance-backed RF ablations on the sealed common benchmark.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-08T19:06:17Z
- **Completed:** 2026-08-08T19:24:33Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Added strict point-in-time host, neutral, rest, country-centroid travel, and stage features with evidence companions and fail-closed missingness.
- Committed 21 WGS84 country proxies plus metadata, parent-source provenance, row hashes, and offline validation.
- Registered one full context RF candidate and five drop-one ablations, then dispatched all six through the common proper-score runner while preserving 630/609/G=40, `open_core`, `research_only`, and sealed WC2026 boundaries.
- Added adapter/runner integration coverage and retained the inherited open RF tracer behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Derive open-context feature evidence** - `c734516` (feat)
2. **Task 2: Register context bundle and ablations** - `04cacaa` (test/RED), `6a49869` (feat/GREEN)

The Task 1 RED contract was introduced by the preceding plan's shared Wave 0 test commit `7d2c122` and was completed here by `c734516`.

## Files Created/Modified

- `R/forecast/context_features.R` - deterministic context derivation, centroid loading, chronology, and evidence validation.
- `data/benchmark/phase11/country_centroids.csv` - frozen Natural Earth Admin 0 country proxy coordinates.
- `data/benchmark/phase11/country_centroids_metadata.csv` - source, license, derivation, registry-parent, and row-set metadata.
- `R/benchmark/hybrid_protocol.R` - context feature contract, model rows, centroid validators, and ablation registry.
- `data/benchmark/phase11/model_registry.csv` - base RF plus full context and five drop-one model registrations.
- `data/benchmark/phase11/feature_contract.csv` - ten open-core RF/context feature rows with parent hashes.
- `data/benchmark/phase11/context_ablation_registry.csv` - six explicit context comparison rows.
- `R/benchmark/hybrid_adapters.R` - context feature preparation, RF fit/predict, NB distributions, and candidate dispatch.
- `R/benchmark/hybrid_runner.R` - multi-candidate scoring, coverage aggregation, parent hashes, and candidate evidence.
- `tests/testthat/test_hybrid_context_features.R` - feature, provenance, registry, missingness, and end-to-end ablation tests.

## Decisions Made

- Country-proxy travel uses committed Natural Earth Admin 0 WGS84 coordinates and `geosphere::distGeo()`; it is explicitly not stadium-level travel.
- Context candidates reuse the registered inherited RF/NB settings but carry distinct context feature-set, ablation, centroid, and metadata identities.
- Context values are computed from strictly prior history and checked fixture metadata; unavailable values are not imputed for open-core comparisons.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made loaded centroid metadata revalidation attribute-stable**
- **Found during:** Task 2 adapter integration
- **Issue:** Loader-attached metadata attributes changed the serialized row-set hash during a subsequent validation call.
- **Fix:** Strip attached attributes before recomputing the canonical centroid row-set hash.
- **Files modified:** `R/forecast/context_features.R`
- **Verification:** Context adapter smoke test and context suite pass.
- **Committed in:** `6a49869`

**2. [Rule 1 - Bug] Prevented source-absent travel rows from fabricating source dates**
- **Found during:** Task 2 adapter integration
- **Issue:** A partially unavailable prior-location pair could leave a travel source date even though `source_present` was false.
- **Fix:** Emit a travel source date only when both prior locations support an observed travel value.
- **Files modified:** `R/forecast/context_features.R`
- **Verification:** Strict context evidence validation and adapter runner integration pass.
- **Committed in:** `6a49869`

**3. [Rule 3 - Blocking] Added context-specific registered RF settings resolution**
- **Found during:** Task 2 adapter integration
- **Issue:** The inherited RF helper intentionally accepted only the base RF candidate identity, blocking context registrations from using the shared tuning safely.
- **Fix:** Resolve immutable RF runtime settings through the base registration, then apply the requested context registration's feature-set and provenance hashes without weakening setting validation.
- **Files modified:** `R/benchmark/hybrid_adapters.R`
- **Verification:** Full context bundle and all five ablations run through the common runner.
- **Committed in:** `6a49869`

**4. [Rule 1 - Bug] Allowed registered multi-candidate dispatch and stage-drop ablations**
- **Found during:** Task 2 adapter integration
- **Issue:** The adapter membership check still required exact equality with the single base candidate, and the stage factor coercion assumed `stage_id` remained active in the stage-drop model.
- **Fix:** Validate candidate membership and conditionally coerce `stage_id` only when registered as active.
- **Files modified:** `R/benchmark/hybrid_adapters.R`, `R/benchmark/hybrid_runner.R`
- **Verification:** All six context candidates score successfully; inherited RF tests remain green.
- **Committed in:** `6a49869`

**Total deviations:** 4 auto-fixed (three Rule 1 bugs, one Rule 3 blocking issue)
**Impact on plan:** Fixes were required for correctness and adapter completion; no architectural scope or research-boundary changes were introduced.

## Issues Encountered

None remaining. Unrelated untracked/generated files were preserved and excluded from all commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The open-context feature set, centroid provenance, full bundle, and individual ablations are ready for Phase 11 research analysis. No WC2026 opening, candidate promotion, calibration, or final-selection output was created.

## Verification Results

- `test_hybrid_context_features.R`: 50 passing assertions.
- `test_benchmark_contracts.R`: 62 passing assertions.
- `test_benchmark_registry.R`: 28 passing assertions.
- `test_benchmark_scoring.R`: 47 passing assertions.
- `test_hybrid_random_forest.R`: 65 passing assertions.
- Canonical protocol write/load: passed with 7 model rows, 10 feature rows, and 6 ablation rows.

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits `c734516`, `04cacaa`, and `6a49869` are present in git history.
- Summary diff passes `git diff --check`.

---
*Phase: 11-hybrid-ml-and-contextual-priors*
*Completed: 2026-08-08*
