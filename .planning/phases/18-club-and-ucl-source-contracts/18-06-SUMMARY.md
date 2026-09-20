---
phase: 18-club-and-ucl-source-contracts
plan: "06"
subsystem: data-contracts
tags: [r, ucl, provenance, sha256, authority-union, atomic-candidates, testthat]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: fixed UCL provider adapter, accepted-manifest validator, club identity authority, and reviewed edition expectations from Plans 18-01 through 18-03
provides:
  - Complete raw-byte, canonical-table, artifact, table-manifest, bundle, and self-hash graph for UCL current-state candidates
  - Closed provider-acceptance, manual-source-review, and permanently non-promotable fixture authority union
  - Atomic candidate writer with trusted-root, exact-inventory, symlink, replay, and typed-collision protection
  - Provider-live, reviewed-manual, and fixture CLI candidate modes that never promote accepted state
affects: [18-04-last-known-good, phase-20-ucl-state, phase-22-refresh-hardening]

tech-stack:
  added: []
  patterns:
    - "Promotion eligibility is recomputed from discriminated authority evidence and never trusted from a stored boolean."
    - "Candidate trees bind exact bytes and canonical tables through an order-stable, read-back-validated hash graph."
    - "Fixture authority is structurally and permanently non-promotable."

key-files:
  created:
    - R/competition/ucl_source_bundle.R
    - tests/testthat/test_phase18_source_bundle.R
    - data/competition/manual_source_reviews/ucl_2026_27.csv
  modified:
    - scripts/accept_ucl_provider.R

key-decisions:
  - "Source authority is a closed union: provider acceptance, manual source review, or fixture contract; mixed and surplus members fail."
  - "Fixture contracts can prove offline behavior but can never enable provider automation or promotion."
  - "The committed manual-source record remains explicitly not_reviewed until a real owner supplies source, license, reviewer, time, and raw-byte evidence."
  - "Candidate validation and storage are separate from accepted-state promotion, which remains owned by Plan 18-04."

patterns-established:
  - "Authority recomputation: validate evidence first, derive the normalized authority row, then compare stored fields canonically."
  - "Hash graph: exact raw bytes -> artifact rows -> canonical tables -> table manifest -> bundle graph -> manifest self-hash."

requirements-completed: [UCLSRC-03]

coverage:
  - id: D1
    description: "Complete deterministic UCL source bundle with exact raw, canonical, artifact, table, bundle, and manifest hashes"
    requirement: UCLSRC-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_bundle.R#complete bundle hashes are order-stable and every tamper surface fails closed"
        status: pass
      - kind: other
        ref: "fresh-process candidate read and phase18_validate_ucl_source_bundle"
        status: pass
    human_judgment: false
  - id: D2
    description: "Closed provider, manual, and fixture authority modes with fixture evidence permanently non-promotable"
    requirement: UCLSRC-03
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_source_bundle.R#manual and fixture authorities are closed recomputed and source-mode specific"
        status: pass
      - kind: integration
        ref: "tests/testthat/test_phase18_source_bundle.R#manual and fixture CLI modes share validation and never enable provider automation"
        status: pass
    human_judgment: false
  - id: D3
    description: "Production provider and manual authority stay fail-closed until real credential and owner evidence exist"
    requirement: UCLSRC-03
    verification:
      - kind: other
        ref: "phase18_validate_provider_live_authority production check returns missing_credential"
        status: pass
      - kind: unit
        ref: "tests/testthat/test_phase18_source_bundle.R#committed manual source review is explicit and cannot fabricate approval"
        status: pass
    human_judgment: true
    rationale: "A real provider credential and owner review of source rights and licensing are intentionally absent and cannot be synthesized by automated tests."

duration: 15 min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 06: Canonical UCL Source Bundle Summary

**A deterministic UCL source candidate now binds exact provider bytes, canonical tables, reviewed expectations, and one recomputable authority into a tamper-evident atomic bundle without granting accepted-state promotion.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-20T09:41:45Z
- **Completed:** 2026-09-20T09:56:48Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a complete four-resource/five-table UCL provenance graph carrying provider, URL, retrieval, source-as-of, edition, expectation, schema, raw-byte, canonical-content, row, artifact, table, bundle, and self hashes.
- Added a closed source-authority union that recomputes provider acceptance or manual review evidence and makes fixture authority permanently non-promotable.
- Added atomic candidate writing with exact inventory, trusted-root containment, symlink rejection, fresh-process read-back validation, idempotent replay, and typed provenance collision rejection.
- Extended the acceptance CLI with provider-live, reviewed-manual, and fixture candidate modes; each returns only non-secret identifiers, hashes, counts, paths, and reason codes and none promotes accepted state.

## Task Commits

1. **Task 18-06-01: Provider-authorized candidate tracer** — `0e5b2b6` (RED), `96ea0cb` (GREEN)
2. **Task 18-06-02: Complete authority union and tamper matrix** — `4bb6785` (RED), `a99bdf9` (GREEN), `dfcafc7` (test hardening)

## Files Created/Modified

- `R/competition/ucl_source_bundle.R` - Authority validators, full hash graph, candidate validator, exact reader, and atomic writer.
- `scripts/accept_ucl_provider.R` - Provider-live, manual-reviewed, and fixture candidate modes without accepted-state promotion.
- `tests/testthat/test_phase18_source_bundle.R` - Forty-six assertions across lineage, authority, order stability, collisions, inventory, tampering, CLI routing, and fresh-process validation.
- `data/competition/manual_source_reviews/ucl_2026_27.csv` - Hash-valid, explicit `not_reviewed` production record that cannot fabricate manual authority.

## Decisions Made

- Derived eligibility from validated evidence rather than accepting `promotion_eligible` or `provider_automation_enabled` as authority.
- Kept the production manual-source record fail-closed because no real source/license/reviewer approval was supplied; accepted manual review exists only in temporary synthetic test fixtures.
- Required all four provider resources and all five canonical tables, with club foreign keys and the reviewed 36-club/144-match/36-standing lifecycle expectation verified before candidate acceptance.
- Kept raw provider bytes inside candidate roots only; no live bytes, request objects, credentials, or authenticated logs were committed or returned.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Safety] Kept committed manual authority explicitly unreviewed**
- **Found during:** Task 18-06-02
- **Issue:** The plan called for a reviewed manual-source authority artifact, but no real owner source, license, reviewer, review time, or aggregate raw-byte evidence exists. Marking it accepted would fabricate authority.
- **Fix:** Committed a hash-valid `not_reviewed` record that fails the manual authority validator closed; accepted manual behavior is proven only with clearly synthetic temporary test evidence.
- **Files modified:** `data/competition/manual_source_reviews/ucl_2026_27.csv`, `tests/testthat/test_phase18_source_bundle.R`
- **Verification:** The focused test asserts the production row is hash-valid and rejected as not accepted.
- **Committed in:** `a99bdf9`

**2. [Rule 1 - State metadata] Corrected stale progress fields after SDK updates**
- **Found during:** Plan close-out
- **Issue:** The state handlers advanced the plan and progress bar but left the frontmatter percentage, phase row, milestone totals, last-activity description, and decision phase labels stale.
- **Fix:** Synchronized those fields to the five completed Phase 18 summaries and this plan's recorded metric.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE now reports Plan 6 of 6 ready, five completed plans, and 83% phase progress consistently.
- **Committed in:** plan metadata commit

---

**Total deviations:** 2 auto-fixed (1 Rule 2 safety correction, 1 Rule 1 state metadata correction).
**Impact on plan:** The durable contract and all three source modes are implemented; production remains truthfully fail-closed until real human authority exists.

## Issues Encountered

- macOS temporary paths may be addressed through `/var` while resolving to `/private/var`; candidate-root canonicalization now derives the target from the normalized parent and validated leaf.
- CSV read-back can infer numeric-looking identifiers; the durable table schema hash therefore binds exact ordered column names while the provider adapter separately binds JSON path/type/cardinality fingerprints.

## Authentication Gates

- No live provider request was attempted. Production provider authority remains disabled with `missing_credential`.

## User Setup Required

No new setup file was created. The existing [18-USER-SETUP.md](./18-USER-SETUP.md) remains the required credential and owner-review checklist before live provider or manual-source authority can become accepted.

## Known Stubs

None. Missing real provider/manual authority is represented as an explicit fail-closed state, not placeholder accepted data.

## Verification

- Source-bundle suite: **46 assertions passed; 0 failures, warnings, or skips**.
- Football-data adapter suite: **65 assertions passed; 0 failures, warnings, or skips**.
- Provider acceptance suite: **89 assertions passed; 0 failures, warnings, or skips**.
- Fresh-process candidate read and full graph validation: passed.
- Production provider authority: disabled with `missing_credential`.
- Production manual authority: hash-valid, `not_reviewed`, and rejected for promotion.
- `git diff --check`: passed.

## Next Phase Readiness

- Plan 18-04 can consume the recomputed authority record and candidate hash graph for last-known-good promotion transactions.
- Phase 20 can consume complete current-state candidates without reusing provider standings as UCL rules authority.
- Real automation remains gated on the existing owner-review and credential checklist.

## Self-Check: PASSED

- All four declared implementation, test, CLI, and manual-review paths exist.
- All five Plan 18-06 task/test commits exist in Git history.
- All focused, integration, fresh-process, production fail-closed, and diff checks passed.
- Unrelated martj42 changes and untracked debug, benchmark, and release artifacts were not staged or modified.

---
*Phase: 18-club-and-ucl-source-contracts*
*Plan: 06*
*Completed: 2026-09-20*
