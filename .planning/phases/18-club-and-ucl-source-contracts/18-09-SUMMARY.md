---
phase: 18-club-and-ucl-source-contracts
plan: "09"
subsystem: data-contracts
tags: [r, canonical-v2, club-identity, freshness, football-data-org]
requires:
  - phase: 18-07
    provides: canonical-v2 length-prefixed hashing primitives
  - phase: 18-14
    provides: canonical-first Phase 18 loader bootstrapping
provides:
  - Canonical-v2 durable club registries, tokens, reviews, and unresolved evidence
  - Active-status and half-open validity-aware club identity resolution
  - Four-family source freshness evidence with exact fail-closed thresholds
  - Closed sanitized acquisition failure classification and stable projection ordering
affects: [18-10, 18-11, 18-13, phase-19-club-models]
tech-stack:
  added: []
  patterns: [domain-separated canonical hashes, per-resource freshness evidence, closed reason enums]
key-files:
  created: []
  modified:
    - R/club/identity.R
    - R/club/identity_bootstrap.R
    - R/competition/football_data_org_adapter.R
    - tests/testthat/test_phase18_club_identity.R
    - tests/testthat/test_phase18_football_data_adapter.R
    - data/club/registries/clubs.csv
    - data/club/identity_reviews/unresolved_club_tokens.csv
key-decisions:
  - "Club identity authority requires canonical-v2 durability plus an active status at the event instant."
  - "Freshness authority is the conjunction of competition, team-row, match-row, and standings-resource evidence; missing standings source time blocks projection."
  - "Provider row order is non-semantic, while exact raw response hashes remain separate provenance evidence."
patterns-established:
  - "Validate stored durable hashes before any constructor or resolver can regenerate authority."
  - "Classify unexpected acquisition exceptions as blocked_unclassified_acquisition without persisting raw messages."
requirements-completed: [UCLSRC-02, CLUBID-01]
coverage:
  - id: D1
    description: "Validity-aware active club identity with canonical-v2 durable evidence"
    requirement: CLUBID-01
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase18_club_identity.R (66 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Independent resource freshness and closed acquisition failure handling"
    requirement: UCLSRC-02
    verification:
      - kind: integration
        ref: "tests/testthat/test_phase18_football_data_adapter.R (139 assertions)"
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 09: Active Club Identity and Resource Freshness Summary

**Canonical-v2 club authority now resolves only active, event-valid identities and accepts a provider window only when all four resource families carry current independent evidence.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-09-20T12:32:02Z
- **Completed:** 2026-09-20T12:48:14Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Migrated registry, token, review, unresolved-ledger, table, and aggregate identity hashes to the shared canonical-v2 encoding and regenerated the truthful production evidence files.
- Enforced positive half-open club intervals, a closed club-status enum, and active-at-event resolution across source IDs, aliases, and canonical clubs.
- Added four-row freshness evidence derived from competition, every team row, every match row, and an independent standings timestamp, including exact stale/future/malformed/missing boundaries.
- Added stable projection ordering and a closed acquisition classifier that sanitizes unknown provider failures.

## Task Commits

1. **Task 18-09-01 RED: Identity and freshness authority gaps** - `9da87d9` (test)
2. **Task 18-09-01 GREEN: Active identity and resource freshness** - `8ca9d3e` (feat)
3. **Task 18-09-02 RED: Identity and acquisition boundary matrix** - `90471cd` (test)
4. **Task 18-09-02 GREEN: Closed deterministic boundaries** - `bfb5518` (feat)

## Files Created/Modified

- `R/club/identity.R` - Canonical-v2 registry validation, closed status/interval rules, and active resolution.
- `R/club/identity_bootstrap.R` - Canonical-v2 token, owner-review, and unresolved evidence contracts.
- `R/competition/football_data_org_adapter.R` - Per-resource freshness rows, closed error classifier, and canonical projection ordering.
- `tests/testthat/test_phase18_club_identity.R` - Durability, adjacency, inactive-status, empty/null, duplicate, and stable-order probes.
- `tests/testthat/test_phase18_football_data_adapter.R` - Freshness threshold, mixed-row, ordering, and unclassified-error probes.
- `data/club/registries/*.csv` - Schema-complete canonical-v2 empty production registries.
- `data/club/identity_reviews/*.csv` - Canonical-v2 empty/not-run token evidence and hash-bound missing-history sentinel.

## Decisions Made

- Raw response SHA-256 remains exact provenance and may change when remote row order changes; semantic projection row hashes exclude that provenance field and therefore remain order-invariant.
- Production identity remains truthfully empty/blocked until owner-reviewed mappings and live source evidence exist; no club mapping or standings timestamp is inferred.
- A one-hour future clock-skew tolerance is inclusive; evidence beyond it is `blocked_future_resource`, and evidence exactly 48 hours old remains current.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated synthetic expectations for the stricter Plan 18-08 authority contract**
- **Found during:** Task 18-09-01
- **Issue:** The adapter fixture still used the now-forbidden `fixture-reviewer` placeholder, so every semantic projection stopped at edition authority.
- **Fix:** Made the fixture an explicitly approved non-placeholder owner expectation through the production v2 constructor.
- **Files modified:** `tests/testthat/test_phase18_football_data_adapter.R`
- **Verification:** Both focused suites pass.
- **Committed in:** `8ca9d3e`

**2. [Rule 2 - Missing Critical] Avoided repeated full registry validation inside an already validated projection**
- **Found during:** Task 18-09-02
- **Issue:** Per-participant resolution recomputed the full registry authority hundreds of times, making the synthetic boundary matrix unnecessarily slow.
- **Fix:** Added internal prevalidated registry/hash parameters used only after the adapter performs one complete validation.
- **Files modified:** `R/club/identity.R`, `R/competition/football_data_org_adapter.R`
- **Verification:** Combined focused suites pass in about 15 seconds while public resolver calls still validate by default.
- **Committed in:** `bfb5518`

---

**Total deviations:** 2 auto-fixed (1 blocking integration adjustment, 1 missing critical performance guard). **Impact:** Both preserve the planned authority semantics; no product scope was added.

## Issues Encountered

- Canonical-v2 hashing exposed the cost of recomputing a complete registry hash for every synthetic participant; the validated projection path now reuses one authority hash.

## Authentication Gates

None.

## User Setup Required

None - no credentials or network access were used. Live acquisition remains disabled without exact accepted external evidence.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` — PASS (66 + 139 assertions).
- `git diff --check` — PASS.
- Fresh-process production registry read-back and canonical-v2 aggregate validation — PASS.

## Threat Flags

None. The existing provider transport boundary was narrowed with sanitized closed failures; no new endpoint, credential path, filesystem trust boundary, or schema authority outside the plan threat model was introduced.

## Next Phase Readiness

- Plan 18-10 can bind source bundles to deterministic canonical-v2 identity and freshness evidence.
- Production remains deliberately blocked until real owner identity mappings and independently reviewable provider timestamps exist.

## Self-Check: PASSED

- All declared key files exist.
- Commits `9da87d9`, `8ca9d3e`, `90471cd`, and `bfb5518` exist in Git history.
- Both focused suites and the plan-level verification command pass.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
