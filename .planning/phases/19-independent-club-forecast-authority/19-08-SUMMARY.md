---
phase: 19-independent-club-forecast-authority
plan: "08"
subsystem: release-authority
tags: [club-release, immutable-selector, domain-separation, fail-closed, tdd]

requires:
  - phase: 19-07
    provides: Fixture-ineligible decision vocabulary and source-validated production promotion gates
provides:
  - Immutable exact-inventory fixture club release staging, validation, installation, selector, and resolver
  - Shared closed forecast-domain assertion with explicit national-team projection at legacy boundaries
  - Bidirectional club/national rejection at release roots, selectors, contracts, objects, and forecast entrypoints
  - Production club publication gate that remains selector-less without genuine accepted authority
affects: [phase-19-09, phase-19-10, phase-20, club-forecast-consumers]

tech-stack:
  added: []
  patterns: [metadata-first validation, atomic selector replacement, explicit expected-domain guard, fixture-only authority]

key-files:
  created:
    - R/release/domain_contract.R
    - R/club/release.R
    - tests/testthat/test_phase19_club_release.R
  modified:
    - R/release/release_contract.R
    - R/competition/forecast_layer.R

key-decisions:
  - "Legacy national release files remain unchanged; national consumers project absent domain metadata to national_team at their boundary."
  - "Fixture evidence is accepted only by the explicit fixture resolver and cannot create production authority or a production selector."
  - "A declared club domain is rejected by every national release/forecast boundary before forecast use, while a declared national domain is rejected by club release validation."

patterns-established:
  - "Validate trusted root, exact inventory, parent hashes, and artifact hashes before loading RDS; recheck object identity and reread the selector afterward."
  - "Keep club and national selector roots disjoint and require explicit expected-domain assertions rather than structural compatibility."

requirements-completed: [CLUBMOD-01, CLUBMOD-05]

coverage:
  - id: D1
    description: "Fixture-backed club release staging, exact validation, atomic install, rollback, selector reread, and adversarial path/hash/object checks are implemented."
    requirement: CLUBMOD-01
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase19_club_release.R#fixture release round trip and attack coverage"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_release.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "Club/national domain guards and production publication gates reject cross-domain or relabeled fixture authority."
    requirement: CLUBMOD-04
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase19_club_release.R#national boundaries project national_team and reject club authority"
        status: pass
      - kind: other
        ref: "rtk Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_release.R"
        status: pass
      - kind: integration
        ref: "Phase 12/14 regression command"
        status: fail
    human_judgment: true
    rationale: "The national regression fixture is incomplete in the shared checkout: its tracked release is missing model/approved_model.rds, so Phase 12 and dependent Phase 14 tests cannot reach their assertions."

duration: 48min
completed: 2026-09-20
status: complete
---

# Phase 19 Plan 08: Immutable Club Release Authority Summary

**Immutable fixture club releases now have exact inventory, model-card and parent-hash binding, atomic selector publication, and symmetric rejection at national consumer boundaries while production remains fail-closed.**

## Performance

- **Duration:** 48 min
- **Started:** 2026-09-20T20:09:00Z
- **Completed:** 2026-09-20T20:57:18Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a closed `club` / `national_team` domain contract and used it at both release and forecast boundaries.
- Implemented a complete fixture-only club release lifecycle: exact recursive inventory, no-symlink and containment checks, parent/artifact hashes, model-card projection, metadata-first validation, post-load object checks, atomic install, lock handling, rollback, and selector reread.
- Added national compatibility projection without rewriting legacy release files; national roots, selectors, contracts, models, calibrators, and direct Phase 14 calls reject declared club authority.
- Kept the production club writer blocked before output-root creation until genuine accepted history/current-UCL identity, review, protocol, roster, and promotion evidence exists.

## Task Commits

Each task was committed atomically with strict RED/GREEN ordering:

1. **Task 19-08-01 RED:** `6d31363` — `test(19-08): add immutable club release red tests`
2. **Task 19-08-01 GREEN:** `72b95c2` — `feat(19-08): publish immutable fixture club release authority`
3. **Task 19-08-02 RED:** `d7eb2ff` — `test(19-08): add bidirectional domain and publication gate red tests`
4. **Task 19-08-02 GREEN:** `8c7ce2d` — `feat(19-08): enforce bidirectional release domain guards`

## Verification

- Task 19-08-01 focused suite: **6 tests / 23 assertions**, pass.
- Task 19-08-02 focused suite: **8 tests / 31 assertions**, pass.
- Domain smoke checks for national root, contract, forecast, and calibrator club attacks: pass with `phase19_domain_error`.
- `rtk git diff --check`: pass.
- The required combined national regression command could not complete because the existing Phase 12 release is missing `outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds`; seven Phase 12 tests and dependent Phase 14 fixture setup fail at that pre-existing missing file. The Phase 14 suite itself was not usable until that source artifact is restored.

## Files Created/Modified

- `R/release/domain_contract.R` - Shared strict expected-domain guard.
- `R/club/release.R` - Fixture/production writers, exact validator, atomic installer, selector, and resolver.
- `R/release/release_contract.R` - National-domain projection, root/selector/contract/object guards, and domain-aware selector compatibility.
- `R/competition/forecast_layer.R` - National direct forecast and calibrator guards.
- `tests/testthat/test_phase19_club_release.R` - TDD fixture, attack, rollback, domain, and production-gate coverage.

## Decisions Made

- Existing national release bytes are not rewritten to add a field; the consumer projection makes the expected domain explicit at runtime.
- Fixture releases use temporary roots and a separate resolver/selector namespace and are permanently non-promotable.
- No production selector is created or changed while accepted Phase 18/19 authority evidence is absent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved exact release inventory names during validation**
- **Found during:** Task 19-08-01 GREEN
- **Issue:** Path-derived names could make exact-inventory comparisons fail even when the artifact set was correct.
- **Fix:** Normalized path projections with `unname()` before comparison and hashing.
- **Files modified:** `R/club/release.R`
- **Verification:** Fixture round-trip and surplus/missing/path attack tests pass.
- **Committed in:** `72b95c2`

**2. [Rule 1 - Bug] Kept successfully returned staged roots alive**
- **Found during:** Task 19-08-01 GREEN
- **Issue:** The staging cleanup hook could remove a staged root after the writer returned it to the installer.
- **Fix:** Clear the cleanup hook only after preflight succeeds and ownership transfers to the caller.
- **Files modified:** `R/club/release.R`
- **Verification:** Fixture install, selector reread, and rollback tests pass.
- **Committed in:** `72b95c2`

**3. [Rule 3 - Blocking] Preserved legacy national selector compatibility**
- **Found during:** Task 19-08-02 GREEN
- **Issue:** Existing national selectors predate the explicit domain column, while new cross-domain rejection requires a domain-aware boundary.
- **Fix:** Validate the legacy five-column selector self-hash unchanged, project `national_team` in returned metadata, and reject domain-aware club selectors.
- **Files modified:** `R/release/release_contract.R`
- **Verification:** Domain-focused suite passes; legacy selector bytes remain untouched.
- **Committed in:** `8c7ce2d`

**Total deviations:** 3 auto-fixed correctness/compatibility issues. **Impact:** No production authority was broadened; all fixes strengthen fail-closed behavior.

## Issues Encountered

- The shared checkout lacks the national release model artifact `outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds`, although its manifest and contract refer to it. This pre-existing fixture gap blocks the required Phase 12/14 regression command and must be restored before those regressions can serve as a green completion gate.
- An attempt to append the unrun regression to `.planning/WINDOWS.md` was rejected because the pre-existing ledger frontmatter counts already disagree with its rows (`23/0/5/28` vs. `22/0/6/28`). No ledger file was changed.
- Shared-checkout index contention caused transient `index.lock` write failures; retrying without deleting the lock succeeded.

## Known Stubs

None in the files created or modified by this plan. Production non-promotion is intentional and is bound to missing genuine accepted authority, not a placeholder implementation.

## User Setup Required

Restore the genuine tracked Phase 12 national model artifact before rerunning the required Phase 12/14 regression command. Production club publication additionally requires owner-reviewed Phase 18 history/current-UCL identity, policy/fold review, protocol, roster/component coverage, and promoted decision evidence.

## Next Phase Readiness

The club release lifecycle and bidirectional domain mechanics are ready for Plans 19-09/19-10 and Phase 20 integration. Phase 19 remains `human_needed` for production authority, and the national regression gate remains pending the pre-existing Phase 12 model artifact restoration.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- TDD RED/GREEN commits `6d31363`, `72b95c2`, `d7eb2ff`, and `8c7ce2d` exist in repository history.
- Focused fixture/domain tests and diff hygiene passed; the only unrun regression gate is documented above with its pre-existing missing-artifact cause.

---
*Phase: 19-independent-club-forecast-authority*
*Completed: 2026-09-20*
