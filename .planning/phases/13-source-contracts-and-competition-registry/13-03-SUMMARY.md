---
phase: 13-source-contracts-and-competition-registry
plan: "03"
subsystem: competition-registry
tags: [R, UEFA, team-identity, lifecycle, provenance, SHA-256, Phase-12-release]

# Dependency graph
requires:
  - phase: 13-source-contracts-and-competition-registry/01
    provides: Wave 0 identity and edition registry APIs, compact fixtures, and contract tests
  - phase: 13-source-contracts-and-competition-registry/02
    provides: Accepted source bundles, artifact registries, and truthful EURO pre-draw snapshots
provides:
  - Stable, provenance-backed xGelo team identity registry with visible normalized-name fallback
  - Checked Nations League and EURO qualifying edition registry with lifecycle and blocked overlays
  - Trusted Phase 12 model-release pin validation and compact committed registry CSVs
affects: [phase-14-shared-competition-state, source-refresh, forecasting, dashboards]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Deterministic source-ID-first identity resolution with warning-bearing normalized aliases
    - Edition registries validate source-bundle foreign keys and preflight trusted release metadata
    - Blocked refreshes retain the active last-accepted output while lifecycle state remains explicit

key-files:
  created:
    - data/competition/registries/team_identity.csv
    - data/competition/registries/competition_editions.csv
  modified:
    - R/competition/team_identity.R
    - R/competition/edition_registry.R
    - tests/testthat/test_phase13_competition_registry.R

key-decisions:
  - "Keep xGelo team_id canonical and stable while preserving FIFA code, UEFA source ID, current display name, and reviewed aliases."
  - "Allow only deterministic exact normalized-name fallback, and require visible warning/audit metadata for it."
  - "Preflight the sole approved Phase 12 release manifest before accepting competition-edition model pins."
  - "Represent EURO qualifying as explicit pre_draw metadata with real source/output slots and no fabricated structures."

patterns-established:
  - "Identity rows carry mapping method, warning, review state, source bundle, and order-stable row SHA-256."
  - "Edition lifecycle is forward-only; blocked is an auditable overlay requiring operator action and validation for recovery."

requirements-completed: [DATA-03, COMP-01]

coverage:
  - id: D1
    description: "Stable team identity normalization preserves source/display values, aliases, provenance, warning metadata, and hashes while rejecting ambiguous or duplicate mappings."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#team identity registry carries provenance and order-stable row hashes"
        status: pass
      - kind: unit
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_competition_registry.R\")'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both UEFA competition editions validate with lifecycle, blocked retention, source bundle linkage, trusted Phase 12 release pins, explicit output targets, and truthful EURO pre-draw state."
    requirement: COMP-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#competition edition CSV is a checked two-edition release registry"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'source(\"R/competition/edition_registry.R\"); regs <- load_competition_edition_registries(\"data/competition/registries\"); validate_competition_edition_registries(regs)'"
        status: pass
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_dir(\"tests/testthat\")'"
        status: pass
    human_judgment: false

# Metrics
duration: 27 min
completed: 2026-08-13
status: complete
---

# Phase 13 Plan 03: Identity and Competition Registry Summary

**Stable UEFA team identity mappings and trusted, lifecycle-aware Nations League/EURO edition registries are now committed for downstream competition-state work.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-13T20:45:00Z
- **Completed:** 2026-08-13T21:11:53Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Hardened team identity resolution around stable xGelo IDs, duplicate FIFA/source-ID rejection, preserved UEFA display names and aliases, visible normalized-name fallback warnings, and row/table hashes.
- Published `team_identity.csv` with source-bundle provenance and deterministic identity metadata for accepted UEFA team rows.
- Replaced the initial edition registry with a checked two-edition contract that links accepted source bundles, validates the trusted Phase 12 release ID, enforces forward lifecycle transitions, and retains the active output during blocked refreshes.
- Published `competition_editions.csv` with explicit Nations League scheduled state and truthful EURO 2028 qualifying `pre_draw` metadata, including the official 2026-12-06 draw date and non-null source/output slots.

## Task Commits

Each TDD task was committed atomically with RED and GREEN commits:

1. **Task 13-03-01: Harden stable team identity and warning-bearing fallback**
   - `43a5015` — test: add identity and edition registry contract tests (RED)
   - `0ee5812` — feat: harden stable team identity registry (GREEN)
2. **Task 13-03-02: Register both competition editions with lifecycle, blocked state, and release pins**
   - `4ad1f8e` — test: add competition edition registry contract tests (RED)
   - `13ecbba` — feat: register UEFA competition editions (GREEN)

## Files Created/Modified

- `R/competition/team_identity.R` - Stable identity preparation/resolution, strict uniqueness and ambiguity validation, registry loading, and order-stable hashes.
- `R/competition/edition_registry.R` - Edition schema, source-bundle linkage, Phase 12 release preflight, lifecycle transitions, blocked overlay/recovery, repinning audit, loading, and validation.
- `tests/testthat/test_phase13_competition_registry.R` - Focused identity, fallback, empty-input, lifecycle, blocked-retention, release-pin, pre-draw, and registry-hash coverage.
- `data/competition/registries/team_identity.csv` - Compact accepted identity registry with aliases, source bundle, mapping fields, and row hashes.
- `data/competition/registries/competition_editions.csv` - Compact two-edition lifecycle/release/output registry.

## Decisions Made

- Source IDs remain authoritative when present; normalized aliases are an exact-match fallback only and always emit review-visible warning metadata.
- The approved Phase 12 release is resolved from the trusted release root rather than accepted as a caller-supplied model path or literal-only pin.
- Blocked refreshes retain `active_output_bundle_id` as `last_accepted_output_bundle_id`; recovery requires explicit operator action and a passing validation flag.
- EURO qualifying remains `pre_draw` until the official draw snapshot, with no groups, fixtures, standings, or probabilities synthesized in the registry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected vectorized blocked-overlay validation**
- **Found during:** Task 13-03-02 focused registry acceptance gate
- **Issue:** The blocked metadata predicate combined vector-valued checks with scalar `||`, causing valid two-row registries to error during validation.
- **Fix:** Replaced scalar logical operators with element-wise `|` checks inside the row-wise blocked mask.
- **Files modified:** `R/competition/edition_registry.R`
- **Verification:** Focused suite passed with 51 assertions; direct edition load/validation passed; full suite passed.
- **Committed in:** `13ecbba`

**Total deviations:** 1 auto-fixed (Rule 1: 1)
**Impact on plan:** The fix was required for the planned two-edition registry to validate; no architectural scope changed.

## Issues Encountered

None unresolved. The shared checkout contained unrelated benchmark/output changes; they remained unstaged and were not modified by this plan.

## User Setup Required

None - no external service configuration is required for the committed registry and fixture-backed validation workflow.

## Next Phase Readiness

Phase 14 can consume stable `team_id` and edition IDs, accepted source-bundle identities, explicit lifecycle/blocked metadata, and the pinned Phase 12 release without reinterpreting missing fields. Competition-specific standings, form, forecasting, and leakage behavior remain intentionally deferred to Phase 14.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/13-source-contracts-and-competition-registry/13-03-SUMMARY.md`.
- All four task RED/GREEN commits are present in Git history.
- Both committed registry CSVs exist and validate through their production loaders.
- Focused Phase 13 registry tests passed: 51 assertions, 0 failures, 0 warnings, 0 skips.
- Full repository test suite passed: 2,709 assertions, 0 failures, 0 warnings, 0 skips.
- No raw/local or benchmark/output artifacts were staged by this plan.
- Post-write self-check rerun: all required files and task commit hashes were found; `git diff --check` passed.

---
*Phase: 13-source-contracts-and-competition-registry*
*Plan: 03*
*Completed: 2026-08-13*
