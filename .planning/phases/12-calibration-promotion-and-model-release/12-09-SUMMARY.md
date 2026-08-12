---
phase: 12-calibration-promotion-and-model-release
plan: 09
subsystem: release-consumer-boundary
tags: [release, preflight, dashboard, sha256, testthat]

requires:
  - phase: 12-calibration-promotion-and-model-release
    provides: "Frozen Phase 12 release bundle, promotion evidence, and dashboard consumer surface"
provides:
  - "Metadata-only trusted release preflight before model loading"
  - "Contract-declared model artifact authority and candidate identity checks"
  - "Fail-closed exported dashboard builders with focused release regressions"
affects: [dashboard, release-installation, PROMO-03]

tech-stack:
  added: []
  patterns:
    - "Validate release metadata and candidate authority with load_models = FALSE before RDS reads"
    - "Preserve default model-loading behavior for publisher and installer callers"
    - "Reject raw model and baseline arguments at exported dashboard boundaries"

key-files:
  created:
    - ".planning/phases/12-calibration-promotion-and-model-release/12-09-SUMMARY.md"
  modified:
    - "R/release/release_contract.R"
    - "R/release/release_bundle.R"
    - "R/release/release_install.R"
    - "R/visualization/worldcup_dashboard.R"
    - "tests/testthat/test_phase12_release.R"
    - "tests/testthat/test_worldcup_dashboard.R"

key-decisions:
  - "Metadata preflight exhaustively enumerates the trusted root manifest and every immediate-child manifest, rejecting ambiguous topology."
  - "The preflight validates contract-declared distinct model paths and requires both paths to map to artifact_role = model rows."
  - "The embedded benchmark evidence identity remains separate from final-evaluation external promotion-report hash provenance."

patterns-established:
  - "Preflight returns pinned metadata only; the full resolver loads only after identity and hash validation."
  - "Dashboard model authority comes exclusively from the validated release resolver."

requirements-completed: [PROMO-03]

coverage:
  - id: D1
    description: "Trusted Phase 12 release metadata is validated without loading model RDS files."
    requirement: "PROMO-03"
    verification:
      - kind: integration
        ref: "Rscript --vanilla -e 'preflight_phase12_approved_release(...)'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Exported dashboard builders reject null release roots and raw model or baseline authority."
    requirement: "PROMO-03"
    verification:
      - kind: unit
        ref: "tests/testthat/test_worldcup_dashboard.R"
        status: pass
    human_judgment: false
  - id: D3
    description: "Invalid topology, contract, role, hash, and direct-resolver ordering cases fail closed."
    requirement: "PROMO-03"
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase12_release.R"
        status: pass
    human_judgment: false

duration: 2h 16m
completed: 2026-08-12
status: complete
---

# Phase 12 Plan 09: Approved consumer boundary gap closure Summary

**Metadata-only Phase 12 release preflight now gates contract-authoritative model loading and fail-closed dashboard consumers**

## Performance

- **Duration:** 2h 16m
- **Started:** 2026-08-12T15:00:13Z
- **Completed:** 2026-08-12T17:16:12Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added exhaustive trusted-root candidate discovery and metadata-only complete-bundle validation, including candidate authority from bundled benchmark/freeze/final-evaluation evidence, contract path/hash checks, labels, G=40, and independent promotion-hash semantics.
- Refactored the direct resolver to preflight before RDS reads, preserve default-loading behavior, and load only the validated contract-declared model and calibrator artifacts.
- Enforced release-only model authority in both exported dashboard builders and added fail-closed regressions for topology, malformed metadata, hash/role drift, invalid model bytes, null roots, and raw argument bypasses.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add metadata-only release preflight and enforce it at both exported dashboard boundaries** - `275bb58` (feat)
2. **Task 2: Convert fixtures and add separate preflight and exported-consumer regressions** - `1ddc7d2` (test)
3. **Rule 1 correction: Keep raw-argument guard at dashboard boundary** - `caabf24` (fix)

## Files Created/Modified

- `R/release/release_contract.R` - Trusted-root preflight, bundled candidate authority, direct-resolver ordering, and metadata projection.
- `R/release/release_bundle.R` - Opt-in metadata-only validation with default-preserving RDS validation.
- `R/release/release_install.R` - Propagated the validator seam without changing installation defaults.
- `R/visualization/worldcup_dashboard.R` - Release-only dashboard resolution and raw/baseline argument rejection.
- `tests/testthat/test_phase12_release.R` - Temporary release fixtures and zero-load fail-closed regressions.
- `tests/testthat/test_worldcup_dashboard.R` - Release-backed dashboard fixture and exported-boundary regressions.

## Decisions Made

- Keep `candidate_id` authoritative in `release_manifest.csv`; the model contract remains compatible with its selected/incumbent/status identity shape.
- Keep `final_evaluation_manifest.csv` promotion-report hashes as uniform external-file provenance and do not compare them with the embedded benchmark decision identity.
- Preserve the exact incumbent-retained release and existing dashboard presentation behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed an accidentally misplaced raw-argument guard**

- **Found during:** Task 2 verification
- **Issue:** An intermediate edit placed the dashboard argument guard inside `make_knockout_route_estimator()`, where its variadic context was invalid and broke valid dashboard builds.
- **Fix:** Removed the misplaced guard and retained it only at the exported `build_worldcup_dashboard()` boundary.
- **Files modified:** `R/visualization/worldcup_dashboard.R`
- **Verification:** Focused dashboard suite passed with 456 assertions.
- **Committed in:** `caabf24`

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Necessary in-scope correction; no unrelated files were changed or staged.

## Issues Encountered

- The first commit attempt was blocked by sandbox permissions on Git's index lock. The scoped commit was retried with elevated permission and succeeded; no worktree cleanup or unrelated staging was performed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

PROMO-03's approved-consumer boundary is implemented and focused release/dashboard verification is green. Planning state and roadmap counts are updated for Phase 12 completion.

## Self-Check: PASSED

- Summary path will be verified on disk after write.
- Task commits `275bb58`, `1ddc7d2`, and `caabf24` are present.
- Focused release suite: PASS (21 assertions, 0 failures, 0 warnings).
- Focused dashboard suite: PASS (456 assertions, 0 failures, 0 warnings).
- Tracer source/load and preflight/resolver smoke checks: PASS.
- Production/test diff from the pre-plan commit is limited to the six declared files.
