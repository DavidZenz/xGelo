---
phase: 12-calibration-promotion-and-model-release
plan: 10
subsystem: release-integrity-and-dashboard
tags: [release-contract, trusted-root, calibration, dashboard, testthat]

requires:
  - phase: 12-calibration-promotion-and-model-release
    provides: frozen calibration, promotion evidence, and incumbent-retained release bundle
provides:
  - symlink-safe, fresh-preflight release resolution with exact decision and freeze identities
  - calibrated 1X2 propagation through match, group, stage, and knockout dashboard consumers
  - temporary adversarial regression coverage for release and dashboard boundaries
affects: [PROMO-03, dashboard, release-validation, model-consumer-boundary]

tech-stack:
  added: []
  patterns: [metadata-only preflight before RDS loading, explicit calibrated outcome view, temporary checksum mutation fixtures]

key-files:
  created: [tests/testthat/test_phase12_release.R additions, tests/testthat/test_worldcup_dashboard.R additions]
  modified:
    - R/release/release_contract.R
    - R/release/release_bundle.R
    - R/visualization/worldcup_dashboard.R
    - tests/testthat/test_phase12_release.R
    - tests/testthat/test_worldcup_dashboard.R

key-decisions:
  - "Bind release authority to normalized trusted-root topology, canonical artifact identities, exact decision-token hashes, and unconditional freeze/evaluation links."
  - "Keep the immutable incumbent-retained raw release behind an explicit compatibility branch while requiring complete identity for calibrated releases."
  - "Apply calibration only to derived 1X2 outcome views; retain raw scoreline distributions and scoreline-derived fields for bookkeeping and evidence."

patterns-established:
  - "Every resolver call performs fresh metadata-only preflight and validates any supplied handoff against trusted paths and identity fields."
  - "Dashboard group ranking consumes an explicit per-match outcome view rather than inferring calibrated outcomes from raw scoreline samples."

requirements-completed: [PROMO-03]

coverage:
  - id: D1
    description: "Trusted release roots, evidence, artifact identities, and loaded objects fail closed before model use."
    requirement: PROMO-03
    verification:
      - kind: unit
        ref: tests/testthat/test_phase12_release.R#12-10 trusted release topology rejects symlink roots and candidates
        status: pass
      - kind: integration
        ref: Rscript --vanilla -e 'validate_phase12_complete_release_bundle(...); resolve_phase12_approved_release(...)'
        status: pass
    human_judgment: false
  - id: D2
    description: "Calibrated 1X2 probabilities flow through dashboard consumers without changing scoreline evidence."
    requirement: PROMO-03
    verification:
      - kind: unit
        ref: tests/testthat/test_worldcup_dashboard.R#12-10 calibrated outcome view changes 1X2 fields but preserves scorelines
        status: pass
      - kind: unit
        ref: tests/testthat/test_worldcup_dashboard.R#12-10 calibrated group outcomes drive points while raw scores drive goals
        status: pass
      - kind: unit
        ref: tests/testthat/test_worldcup_dashboard.R#12-10 calibrated knockout route changes advancement components only
        status: pass
    human_judgment: false
  - id: D3
    description: "Release and dashboard focused regressions plus the full test suite pass with warnings treated as failures."
    requirement: PROMO-03
    verification:
      - kind: integration
        ref: tests/testthat/test_phase12_release.R and tests/testthat/test_worldcup_dashboard.R
        status: pass
      - kind: integration
        ref: Rscript --vanilla -e 'testthat::test_dir("tests/testthat", stop_on_failure=TRUE, stop_on_warning=TRUE)'
        status: pass
    human_judgment: false

duration: 37min
completed: 2026-08-13
status: complete
---

# Phase 12 Plan 10: Calibration promotion and model release gap closure Summary

**Trusted release integrity is now fail-closed and calibrated 1X2 outcomes flow through the dashboard while raw scoreline evidence remains unchanged.**

## Performance

- **Duration:** 37 minutes
- **Started:** 2026-08-13T07:34:37Z
- **Completed:** 2026-08-13T08:11:31Z
- **Tasks:** 3
- **Files modified:** 5 product/test files; 1 planning summary artifact

## Accomplishments

- Rejected symlink and trusted-root escapes, forged or stale preflight handoffs, canonical artifact-path swaps, malformed evidence links, and loaded identity drift before model or forecast use.
- Bound embedded promotion identity to canonical evidence, the exact raw release decision token, and selected model identity; preserved the explicit immutable incumbent raw-release compatibility rule.
- Added calibrated per-match outcome data flow through group ranking and knockout route probabilities while preserving raw scoreline distributions, expected goals, and scoreline-derived markets.
- Added temporary adversarial and consumer regressions, then passed focused suites and the full test suite with warnings treated as failures.

## Task Commits

Each task was committed atomically:

1. **Task 1: Re-establish the trusted release-to-resolver integrity path** - `64ab2ff` (feat)
2. **Task 2: Apply calibrated 1X2 output through the dashboard forecast graph** - `e2ea8a7` (feat)
3. **Task 3: Complete adversarial release and consumer regression coverage** - `f8fb5d0` (test; includes the directly required Phase 12 calibrator-identity compatibility fix)

## Files Created/Modified

- `R/release/release_contract.R` - trusted topology, fresh handoff validation, exact decision identity, and candidate authority.
- `R/release/release_bundle.R` - canonical artifact, freeze/evaluation cross-links, and loaded-object identity validation.
- `R/visualization/worldcup_dashboard.R` - calibrated outcome view wiring across match, group, and knockout consumers.
- `tests/testthat/test_phase12_release.R` - temporary release-boundary adversarial regressions.
- `tests/testthat/test_worldcup_dashboard.R` - calibrated consumer and direct-caller regressions.
- `12-10-SUMMARY.md` - execution record and verification evidence.

## Verification

- Focused release suite: 44 assertions, 0 failures, 0 warnings.
- Focused dashboard suite: 473 assertions, 0 failures, 0 warnings.
- Full `tests/testthat`: 2,592 assertions, 0 failures, 0 warnings.
- Fresh metadata-only/full release validation and resolver: passed for `incumbent retained` / `open_nb_incumbent` / `raw_1x2`.
- Durable `outputs/` inventory: unchanged from baseline (289 files); `data/` inventory unchanged (211 files).
- `_targets.R` and `scripts/update_worldcup_dashboard.R`: unchanged.

## Decisions Made

- Release authority is tied to canonical paths and byte hashes only after trusted-root topology and evidence links pass.
- The current immutable retained fixture is accepted only through its documented raw-only missing-freeze-self compatibility derivation; new contracts require `freeze_self_sha256`.
- The established Phase 12 calibrator API's `probability_view = derived_1x2` identity is mapped to the release/dashboard `calibrated_1x2` consumer view.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed calibration-only arguments from the raw simulation call**
- **Found during:** Task 2
- **Issue:** Passing `calibrator = NULL` and `primary_probability_view = NULL` through the raw `simulate_fixture()` path caused unused-argument failures.
- **Fix:** Strip those control arguments before forwarding the remaining simulation arguments.
- **Files modified:** `R/visualization/worldcup_dashboard.R`
- **Verification:** Focused dashboard suite and full suite passed.
- **Committed in:** `e2ea8a7`

**2. [Rule 3 - Blocking] Accepted the established calibrated calibrator identity field**
- **Found during:** Task 3
- **Issue:** The production Phase 12 calibration API records `probability_view = derived_1x2`, while the release consumer contract names the applied view `calibrated_1x2`; strict consumer validation would reject a valid calibrated artifact.
- **Fix:** Validate the complete API identity and normalize that established field to the consumer view without weakening required candidate, track, fit, temperature, and distribution invariants.
- **Files modified:** `R/release/release_bundle.R`, `R/visualization/worldcup_dashboard.R`
- **Verification:** Focused release/dashboard suites and full suite passed.
- **Committed in:** `f8fb5d0`

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3)
**Impact on plan:** Both changes were directly required to complete the planned release-to-dashboard path; no caller, durable output, or product-scope expansion occurred.

## Issues Encountered

- Initial git index writes required repository-write escalation from the sandbox. The same scoped staging/commit commands succeeded after approval; no unrelated files were staged.
- The first full-suite attempt ran before the Task 3 source/test commit and correctly failed the project’s freeze cleanliness gate. Re-running after the atomic commit passed all tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

PROMO-03 is implemented and verified for the accepted incumbent-retained release and calibrated consumer contract. The worktree’s unrelated pre-existing dirty/generated paths remain untouched and are not part of this plan’s execution delta.

## Self-Check: PASSED

- All five product/test files exist and are committed in `64ab2ff`, `e2ea8a7`, and `f8fb5d0`.
- The summary artifact exists at this path.
- No `_targets.R` or `scripts/update_worldcup_dashboard.R` changes were detected.
- Durable output inventories match the captured pre-edit inventories.

---
*Phase: 12-calibration-promotion-and-model-release*
*Completed: 2026-08-13*
