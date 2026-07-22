---
phase: 10-statistical-goal-model-challengers
plan: "02"
subsystem: dependency-provenance
tags: [r, cran, glmnet, sha256, supply-chain, targets]

requires:
  - phase: 09-rolling-tournament-benchmark-harness
    provides: Accepted Phase 9 bundle identity, checksum self-hash, parent graph, G=40 support, and sealed run manifest
provides:
  - Official-CRAN index, package metadata, dependency, archive, and installed-content provenance for glmnet 5.0
  - Offline fail-closed validation of the exact glmnet/Matrix runtime and complete Phase 9 parent bundle
  - Targets package declarations and source ordering for the audited Phase 10 optimizer environment
affects: [10-03, 10-07, 10-08, statistical-challengers, runtime-provenance]

tech-stack:
  added: [glmnet 5.0]
  patterns: [verified-local-archive-install, project-local-constrained-library, offline-content-revalidation, immutable-parent-gate]

key-files:
  created:
    - R/benchmark/challenger_preflight.R
    - data/benchmark/phase10/glmnet_provenance.csv
  modified:
    - _targets.R

key-decisions:
  - "Install the official glmnet 5.0 source archive into the ignored project-local data/cache/phase10-library with dependencies disabled."
  - "Treat the official PACKAGES.gz bytes plus selected package-row hash as the repository snapshot identity, and read C++17 from the checksum-verified archive DESCRIPTION because PACKAGES.gz omits that field."
  - "Require full Phase 9 output file hashes, checksum self-hash, parent graph, sealed run flags, and bundle SHA before any Phase 10 candidate work."

patterns-established:
  - "Network-separated provenance: capture downloads official metadata/archive before installation; all runtime checks are offline."
  - "Content-addressed R environment: package versions alone are insufficient; canonical installed-file hashes are mandatory."

requirements-completed: [STAT-01, STAT-02, STAT-03, STAT-04]

coverage:
  - id: D1
    description: Official CRAN provenance capture verifies the glmnet 5.0 repository index, package metadata, complete dependency inventory, archive checksum, archive SHA-256, and exact local installation.
    requirement: STAT-01
    verification:
      - kind: integration
        ref: 10-02 exact capture/install/archive/dependency/content verification command
        status: pass
      - kind: other
        ref: archive-SHA mutation rejection check
        status: pass
    human_judgment: false
  - id: D2
    description: Offline challenger environment validation reproduces the accepted Phase 9 bundle, checksum-self, and parent-graph hashes while rejecting parent identity drift.
    requirement: STAT-01
    verification:
      - kind: integration
        ref: require_challenger_environment() complete Phase 9 artifact-hash verification
        status: pass
      - kind: other
        ref: incorrect Phase 9 bundle identity rejection check
        status: pass
    human_judgment: false
  - id: D3
    description: The targets manifest declares glmnet and Matrix and sources the challenger preflight before later Phase 10 modules without executing a benchmark.
    requirement: STAT-01
    verification:
      - kind: integration
        ref: targets::tar_manifest() returned 41 target declarations
        status: pass
    human_judgment: false

duration: 11 min
completed: 2026-07-22
status: complete
---

# Phase 10 Plan 02: Audited Challenger Runtime Provenance Summary

**Official-CRAN glmnet 5.0 provenance, constrained local installation, exact installed-content hashes, and a complete offline Phase 9 parent gate now protect every later statistical challenger fit.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-22T12:47:05Z
- **Completed:** 2026-07-22T12:58:16Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments

- Added an official-CRAN capture/install service that pins `glmnet` 5.0, inventories all `Depends`/`Imports`/`LinkingTo` packages, permits no dependency installation, verifies the official MD5 plus an independent SHA-256, and installs only the checked local source archive.
- Persisted repository index identity, package-row metadata hash, dependency inventory hash, archive hash, exact `glmnet` and `Matrix` versions/content hashes, and inherited Phase 9 bundle identities in one durable provenance artifact.
- Added an offline runtime gate that recomputes installed package contents and all ten Phase 9 output file hashes, verifies the checksum self-row and parent graph, reproduces bundle SHA `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069`, and checks sealed/reproducible/network-free run flags.
- Declared `glmnet` and `Matrix` in the targets environment and sourced the preflight before later Phase 10 modules; `bivpois` was neither installed nor declared.

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify official CRAN provenance, install glmnet, and implement fail-fast preflights** - `61336ae` (feat)

## Files Created/Modified

- `R/benchmark/challenger_preflight.R` - Official CRAN capture, dependency inventory, archive verification, installed-content hashing, and offline environment/parent validation.
- `data/benchmark/phase10/glmnet_provenance.csv` - Immutable repository, metadata, dependency, archive, package-content, and Phase 9 parent identities.
- `_targets.R` - Project-local Phase 10 library bootstrap, `glmnet`/`Matrix` declarations, and preflight source ordering.

## Decisions Made

- Selected the official source archive `glmnet_5.0.tar.gz` so one audited artifact can be retained and revalidated independently of platform repository availability.
- Used `data/cache/phase10-library` and `data/cache/phase10-cran` for the constrained installation and retained official artifacts; the existing `data/cache/` ignore rule prevents generated package binaries from entering git.
- Required the complete Phase 9 output byte hashes instead of trusting only manifest-declared canonical hashes, so output tampering cannot preserve a superficially valid bundle identity.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Read system requirements from the verified archive DESCRIPTION**
- **Found during:** Task 1 exact capture verification
- **Issue:** CRAN's source `PACKAGES.gz` row omits `SystemRequirements`, although the package page and source DESCRIPTION declare `C++17`; requiring the field in the index caused a correct fail before installation.
- **Fix:** Verify the archive's official MD5 first, extract only `glmnet/DESCRIPTION`, and require exact package/version/`C++17` metadata before installation and during offline replay.
- **Files modified:** `R/benchmark/challenger_preflight.R`
- **Verification:** Exact capture/install command passed; a changed archive SHA is rejected.
- **Committed in:** `61336ae`

**2. [Rule 1 - Bug] Preserve exact version text when reading provenance**
- **Found during:** Task 1 post-install offline validation
- **Issue:** Default CSV type inference converted the pinned text version `5.0` to numeric `5`, causing the exact-version check to fail despite the correct installation.
- **Fix:** Read every provenance field as character and explicitly parse only booleans/byte counts where required.
- **Files modified:** `R/benchmark/challenger_preflight.R`
- **Verification:** Fresh-process `require_challenger_environment()` returns exact package version `5.0`.
- **Committed in:** `61336ae`

**3. [Rule 1 - Bug] Preserve empty trailing dependency fields**
- **Found during:** Task 1 dependency-inventory replay
- **Issue:** Base `strsplit()` dropped trailing empty fields for dependencies without repository version/system requirements, making the persisted six-column inventory appear malformed.
- **Fix:** Added a sentinel while splitting each canonical row so all six fields round-trip without altering the stored inventory hash.
- **Files modified:** `R/benchmark/challenger_preflight.R`
- **Verification:** Dependency replay returns zero unexpected entries and the exact persisted inventory SHA-256.
- **Committed in:** `61336ae`

---

**Total deviations:** 3 auto-fixed bugs.
**Impact on plan:** All fixes strengthened exact fail-closed behavior; package scope, benchmark scope, and production dependencies did not expand.

## Issues Encountered

- The sandbox initially denied creation of `.git/index.lock`; the same explicit-file staging and normal hooked commit succeeded with repository write approval.

## Verification

- Exact Plan 10-02 capture/install command: passed; `glmnet` 5.0 installed from the checked local official-CRAN source archive and `targets::tar_manifest()` loaded 41 declarations.
- Official provenance: index SHA `108ea89c2368ce0f831243a7fcf0d5148e2f0f08686729c3a7ffd1e3d0e9f2c2`; package metadata SHA `e41e4ae81f214cb4925be1d15e4af42f8aed4603d7a4cf7be1154174d07d9cb7`; archive SHA `f0b23da6383a45d502cd138b64da6300422d9b8d7b2c4f14627d412cde79d2a0`.
- Runtime provenance: dependency inventory SHA `39f4ed23d6ac746978d415aef17e3e958d43fc6be6696c30a0b71021dbe40187`; installed `glmnet` content SHA `87fa205f76e55c7a310e4941e3d8398b74757798bd412906d83063448e4de2f0`; installed `Matrix` content SHA `862b472db0fb6caaa1a53b9b74d6c3616be8a00ab9e800d8def41e4568a776b0`.
- Parent provenance: Phase 9 bundle `977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069`, checksum self `4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309`, parent graph `19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584`.
- Fail-closed mutations: incorrect archive SHA and incorrect Phase 9 bundle SHA both raised errors.
- Scope checks: the constrained library contains only `glmnet`; no `bivpois`, `tar_make`, benchmark runner call, or model-fitting call exists in the three task artifacts.
- `git diff --check`: passed before commit.
- No model fitting or benchmark run occurred.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Plans 10-03, 10-07, and 10-08 can require one exact optimizer/runtime provenance record and copy its hashes into later model/run manifests.
- Candidate execution remains blocked automatically if CRAN archive bytes, installed package contents, dependency inventory, or the immutable Phase 9 parent drift.
- No model registry, candidate fit, benchmark output, promotion decision, or WC2026 path was created or executed.

## Self-Check: PASSED

- Verified all three task files and this summary exist on disk.
- Verified task commit `61336ae` exists and contains only the three planned files.
- Verified every recorded provenance hash against the accepted command output.
- Verified there were no task-commit deletions and all unrelated working-tree changes remain unstaged.

---
*Phase: 10-statistical-goal-model-challengers*
*Completed: 2026-07-22*
