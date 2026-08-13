---
phase: 11-hybrid-ml-and-contextual-priors
plan: 04
subsystem: benchmark
tags: [R, testthat, hybrid-benchmark, xG, structural-prior, World-Bank, provenance, shrinkage, G=40]

# Dependency graph
requires:
  - phase: 11-02
    provides: Sealed open RF goal-mean challenger, registered ranger settings, common negative-binomial G=40 scoring path
  - phase: 11-03
    provides: Point-in-time context registry, adapter dispatch, and common open-core runner/comparison path
  - phase: 11-07
    provides: Checksum-backed ranger 0.18.0 provenance and offline Phase 11 runtime wiring
provides:
  - Fail-closed D-12 xG activation manifest and inactive/no-score adapter and runner evidence
  - Official World Bank WDI 2000 structural snapshot with metadata, parent checksums, canonical row-set hash, and prior manifest
  - Registered HGR-inspired sparse-team structural prior with continuous recency-weighted effective counts and post-prediction shrinkage
  - Structural adapter and runner integration preserving the open-core 630/609 denominator, sealed WC2026 boundary, and G=40 support
affects: [phase-11-hybrid-benchmark, phase-12-candidate-selection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Optional evidence is candidate-local and fail-closed: source-absent inputs publish inactive/no-score status rather than becoming observed zero.
    - External structural inputs are committed offline snapshots validated through source, metadata, row-set, and file SHA-256 parents.
    - Sparse structural information is applied only after the inherited RF mean prediction through continuous prior shrinkage.
    - Mixed active/inactive candidate evidence is union-bound before common runner aggregation so one unavailable optional source cannot block unrelated candidates.

key-files:
  created:
    - R/forecast/structural_prior.R
    - data/benchmark/phase11/xg_gate_manifest.csv
    - data/benchmark/phase11/structural_sources.csv
    - data/benchmark/phase11/structural_sources_metadata.csv
    - data/benchmark/phase11/structural_sources_checksums.csv
    - data/benchmark/phase11/structural_prior_manifest.csv
  modified:
    - R/benchmark/hybrid_protocol.R
    - R/benchmark/hybrid_adapters.R
    - R/benchmark/hybrid_runner.R
    - data/benchmark/phase11/model_registry.csv
    - tests/testthat/test_hybrid_xg_gate.R
    - tests/testthat/test_hybrid_structural_prior.R

key-decisions:
  - Current xG remains inactive: coverage and forecast coverage are 0, variance is 0, provenance is incomplete, and the gate requires 0.80 coverage plus nonzero variance and complete provenance.
  - Structural evidence is frozen as official World Bank WDI 2000 GDP-per-capita and population values, transformed only into a registered cross-country structural prior; raw GDP/population fields never enter the RF predictor set.
  - The structural prior uses prior_strength 4, half-life 730 days, prior scale 0.15, bounds 0.65 to 1.55, and prior_weight = prior_strength / (prior_strength + effective_match_count).
  - Official-source rows unavailable for a project team, including PRK in this snapshot, remain source-absent and make the structural candidate inactive; no imputation or missing-as-zero behavior is allowed.
  - STATE.md and ROADMAP.md remain orchestrator-owned and were not modified.

patterns-established:
  - Gate and prior manifests carry registered candidate identities, evidence cutoffs, source parents, settings hashes, research_only, and wc2026_sealed flags.
  - Structural source validation refuses ad hoc filenames, current/latest vintages, malformed ISO3 keys, duplicate rows, restricted licenses, post-cutoff values, and checksum drift.

requirements-completed: [HYBRID-03, HYBRID-04]

coverage:
  - id: D1
    description: D-12 xG coverage/variance/provenance gate stays explicitly inactive under current repository evidence.
    requirement: HYBRID-03
    verification:
      - kind: unit
        ref: tests/testthat/test_hybrid_xg_gate.R via testthat::test_file
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_contracts.R via testthat::test_file
        status: pass
    human_judgment: false
  - id: D2
    description: Vintage-safe structural sources and continuous shrinkage reject unregistered, current, post-cutoff, or checksum-mismatched evidence.
    requirement: HYBRID-04
    verification:
      - kind: unit
        ref: tests/testthat/test_hybrid_structural_prior.R via testthat::test_file
        status: pass
    human_judgment: false
  - id: D3
    description: The registered structural adapter applies prior diagnostics to inherited RF means and emits the sealed G=40 schema.
    requirement: HYBRID-04
    verification:
      - kind: integration
        ref: Local Phase 11 ranger 0.18.0 active structural adapter smoke
        status: pass
    human_judgment: false
  - id: D4
    description: The structural candidate reaches predictions, proper-score metrics, comparison inputs, and the common 630/609/G=40 runner manifest.
    requirement: HYBRID-04
    verification:
      - kind: integration
        ref: Local Phase 11 ranger 0.18.0 active structural runner smoke
        status: pass
      - kind: integration
        ref: tests/testthat/test_benchmark_contracts.R via testthat::test_file
        status: pass
    human_judgment: false

# Metrics
duration: 1h
completed: 2026-08-08
status: complete
---

# Phase 11 Plan 04: Hybrid ML and Contextual Priors Summary

**Fail-closed xG activation plus an official-vintage, checksum-backed structural sparse-team prior integrated through the sealed hybrid RF runner.**

## Performance

- **Duration:** 1h
- **Started:** 2026-08-08T19:27:16Z
- **Completed:** 2026-08-08T20:27:39Z
- **Tasks:** 3
- **Files modified:** 12 plan-owned files

## Accomplishments

- Added the D-12 xG gate manifest, registry candidate, adapter dispatch, and runner evidence. Current xG coverage, variance, and provenance facts remain inactive with score rows suppressed.
- Replaced the initial schema-only structural source fixture with official World Bank WDI 2000 downloadable snapshots for NY.GDP.PCAP.KD and SP.POP.TOTL. The committed artifact contains 142 rows across 71 project-mapped countries; PRK remains absent where the official GDP row is unavailable.
- Implemented structural source loading, ISO3/vintage/cutoff/license/checksum validation, cross-country log/z prior construction, continuous recency-weighted effective match counts, and bounded sparse-team shrinkage.
- Registered phase11_structural_sparse_prior_open as an open_core, research-only, WC2026-sealed candidate inheriting the RF/NB path and preserving 630 open fixtures, 609 rich fixtures, and G=40.
- Routed structural predictions through the common adapter and runner. The real local ranger 0.18.0 smoke produced 2 predictions, 3,362 distribution rows, 28 score metrics, and 1 comparison-input row with prior/effective-count/pre/post-shrinkage diagnostics.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fail-closed xG activation manifest** - e057ed9 (feat)
2. **Task 2: Freeze structural source snapshots and manifest parents** - 1a96fb7 (feat)
3. **Task 3: Vintage-safe structural prior and shrinkage** - dd855d5 (feat)

The official-source provenance correction was committed separately as a task-scoped fix:

- a13e06e (fix): replace structural placeholders with the official WDI snapshot and recompute all dependent hashes.

The final documentation commit is created after this summary self-check.

## Files Created/Modified

- R/forecast/structural_prior.R - checksum-first structural snapshot loader, prior signal, recency-weighted effective counts, and shrinkage helper.
- R/benchmark/hybrid_protocol.R - xG and structural manifests, registry rows, validators, and protocol loading.
- R/benchmark/hybrid_adapters.R - xG and structural candidate dispatch, explicit inactive results, structural diagnostics, and G=40 distributions.
- R/benchmark/hybrid_runner.R - candidate-local inactive handling, mixed-schema binding, score/comparison evidence, and sealed run metadata.
- data/benchmark/phase11/xg_gate_manifest.csv - current D-12 inactive gate facts and source hashes.
- data/benchmark/phase11/structural_sources.csv - frozen official WDI 2000 values and per-row provenance hashes.
- data/benchmark/phase11/structural_sources_metadata.csv - vintage, license, acquisition, and transformation policy.
- data/benchmark/phase11/structural_sources_checksums.csv - source-file, metadata-file, canonical-row-set, and official parent archive SHA-256 registry.
- data/benchmark/phase11/structural_prior_manifest.csv - registered prior settings, cutoff, source parents, and research/sealed flags.
- data/benchmark/phase11/model_registry.csv - xG-gated and structural-prior candidates with registration/settings/manifest hashes.
- tests/testthat/test_hybrid_xg_gate.R - gate thresholds, source-absence semantics, and inactive/no-score runner contracts.
- tests/testthat/test_hybrid_structural_prior.R - structural provenance rejection, continuous weights, registry identity, and inactive runner contracts.

## Decisions Made

- xG is not activated by the presence of zero-valued columns. The manifest records source-absent/value-absent/imputed semantics, coverage 0, variance 0, incomplete provenance, and no-score status.
- Structural indicators are official World Bank annual values frozen at source year 2000 with an explicit vintage ID. Benchmark execution reads only committed CSVs and performs no network access.
- Structural values influence only post-RF goal means through registered shrinkage; no raw structural predictor columns are accepted by the RF feature set.
- A structural source gap is a candidate-local validation failure. It yields explicit inactive/no-score evidence and cannot alter or block the base RF/context candidates.
- Phase 11 remains research-only and sealed from WC2026 holdout outcomes; no promotion, calibration, dashboard, or Phase 12 selection authority was added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Made optional structural failures candidate-local and mixed evidence schemas bindable**

- **Found during:** Task 3 (Vintage-safe structural prior and shrinkage)
- **Issue:** Structural manifest/source validation and mixed active/inactive evidence needed to remain isolated to the structural candidate while the common runner still aggregates unrelated RF/context candidates.
- **Fix:** Captured structural validation errors as explicit inactive/no-score candidate evidence and added union-column binding for mixed candidate frames.
- **Files modified:** R/benchmark/hybrid_protocol.R, R/benchmark/hybrid_adapters.R, R/benchmark/hybrid_runner.R
- **Verification:** xG gate, structural prior, benchmark contract suites, and active/inactive runner smoke paths passed.
- **Committed in:** dd855d5

**2. [Rule 1 - Bug] Replaced schema-valid structural placeholders with official WDI snapshot values**

- **Found during:** Final provenance audit after Task 3
- **Issue:** The first generated structural CSV satisfied the schema and checksum contracts but contained deterministic placeholder values rather than official source observations.
- **Fix:** Used the official World Bank WDI downloadable indicator snapshots, preserved source-absent PRK rather than imputing it, and recomputed row, file, canonical-row-set, manifest, and registry hashes after CSV round-trip normalization.
- **Files modified:** data/benchmark/phase11/structural_sources.csv, data/benchmark/phase11/structural_sources_metadata.csv, data/benchmark/phase11/structural_sources_checksums.csv, data/benchmark/phase11/structural_prior_manifest.csv, data/benchmark/phase11/model_registry.csv
- **Verification:** Structural loader validated 142 rows/71 countries; all three focused test files and both real-ranger smoke paths passed.
- **Committed in:** a13e06e

**Total deviations:** 2 auto-fixed (Rule 1: 1, Rule 2: 1).

**Impact on plan:** Both fixes were required for correctness, provenance, and the requested fail-closed optional-candidate behavior. No architectural scope, data-access, or research-boundary expansion was introduced.

## Verification

- PASS - xG gate suite: 43 expectations, 0 failures, 0 warnings.
- PASS - structural prior suite: 39 expectations, 0 failures, 0 warnings.
- PASS - benchmark contract suite: 62 expectations, 0 failures, 0 warnings.
- PASS - protocol/source validation: 142 official snapshot rows, 71 countries, one registered structural vintage, and 9 model-registry rows.
- PASS - active adapter smoke with the project-local ranger 0.18.0 runtime: 2 predictions and 3,362 distributions (2 x 41 x 41).
- PASS - active runner smoke: 2 predictions, 3,362 distributions, 28 score metrics, 1 comparison-input row, and preserved 630/609/G=40 run metadata.
- PASS - R parsing and git diff checks.

## Auth Gates

None.

## Issues Encountered

- The sandbox initially blocked repository index writes; a narrowly scoped approved escalation was used for the atomic commits. No unrelated files were staged.
- Bare R processes do not automatically include the project-local Phase 11 library; active verification prepended data/cache/phase11-library to .libPaths(), then loaded the registered ranger 0.18.0 runtime successfully.
- Unrelated user/generated files remained untouched and unstaged throughout execution.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. The xG zero-valued source columns referenced by the tests are intentional source-absent evidence for the inactive D-12 gate, not placeholder forecast output.

## Next Phase Readiness

The xG-gated and structural-prior candidates are registered and common-contract compatible for research comparison. Structural source gaps remain explicit inactive states, all evidence is offline and checksum-backed, and the 2026 holdout remains sealed. The orchestrator should update shared STATE.md and ROADMAP.md; this plan intentionally did not modify them.

---
*Phase: 11-hybrid-ml-and-contextual-priors*
*Completed: 2026-08-08*

## Self-Check: PASSED

- Summary file exists at the required path.
- Task commits e057ed9, 1a96fb7, dd855d5, and corrective commit a13e06e exist in git history.
- Official structural source, metadata, checksum, manifest, registry, and gate artifacts validate on disk.
- STATE.md and ROADMAP.md were not modified or staged by this plan.
