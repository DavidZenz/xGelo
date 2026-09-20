---
phase: 18-club-and-ucl-source-contracts
plan: "08"
subsystem: data-authority
tags: [ucl, provider-acceptance, canonical-hash, atomic-publication, cli-security]

requires:
  - phase: 18-07
    provides: Phase 18 canonical-v2 hashing primitives
  - phase: 18-14
    provides: Canonical-first production and test loader ordering
provides:
  - Exact durable owner, edition, 16-capability, and four-resource schema authority
  - Immutable acceptance generations selected by one hash-bound atomic pointer
  - Fixed-edition CLI containment with tagged results and documented process exits
affects: [18-09, 18-10, provider-live, ucl-source-bundles, refresh]

tech-stack:
  added: []
  patterns: [canonical-v2 durable evidence, immutable generation pointer, tagged CLI result union]

key-files:
  created:
    - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/current.json
    - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/
  modified:
    - R/competition/ucl_source_acceptance.R
    - scripts/accept_ucl_provider.R
    - tests/testthat/test_phase18_source_acceptance.R

key-decisions:
  - "Production acceptance reads stored canonical-v2 hashes exactly and never upgrades or rehashes durable evidence on load."
  - "Acceptance publication makes a complete immutable generation visible through one atomic, self-hashed current.json replacement."
  - "The operator CLI supports only football_data_org_v4/ucl_2026_27 and reports success, blocked, rejected, usage, and runtime outcomes with stable exit classes."

patterns-established:
  - "Authority evidence: constructors create hashes; durable readers preserve bytes; validators independently recompute authority."
  - "Publication: stage and validate all files, install an immutable generation, then atomically replace a small pointer."
  - "CLI: validate fixed identifiers and containment before filesystem access, then return a tagged decision or bundle result."

requirements-completed: [UCLSRC-01]

coverage:
  - id: D1
    description: Durable provider authority requires exact approved review, exact edition, exact 16-capability evidence, and independently recomputed four-resource fingerprints.
    requirement: UCLSRC-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase18_source_acceptance.R#durable authority exploit regressions
        status: pass
    human_judgment: false
  - id: D2
    description: Acceptance publication is generation-atomic under killed writers and concurrent subprocess readers.
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase18_source_acceptance.R#writer termination and concurrent reader subprocesses
        status: pass
    human_judgment: false
  - id: D3
    description: The fixed-edition CLI rejects unsafe paths and emits mode-correct tagged results and exit codes.
    requirement: UCLSRC-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase18_source_acceptance.R#CLI traversal and six-mode subprocess matrix
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 08: Exact and Atomic Provider Acceptance Summary

**Canonical-v2 provider authority with immutable generation publication, killed-writer/concurrent-reader proof, and a fixed-edition CLI result contract**

## Performance

- **Duration:** 45 min
- **Started:** 2026-09-20T11:45:00Z
- **Completed:** 2026-09-20T12:28:33Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Replaced trust in stored acceptance claims with exact durable validation of owner review, approved UCL 2026/27 expectations, all 16 capability decisions, capability-specific observations, and the actual four-row schema-fingerprint table.
- Migrated the fail-closed production evidence into an immutable generation selected by a canonical-v2 `current.json`; real process termination and a concurrent reader process observed only complete old or new generations.
- Restricted the operator CLI to the fixed provider/edition root and added tagged decision/bundle output with exits 0 (success), 2 (blocked), 3 (rejected), 64 (usage), and 70 (runtime).
- Preserved the production truth: no owner/key approval was fabricated, and the selected committed generation remains `not_run` / `missing_credential` with automation disabled.

## Task Commits

Each task was committed atomically with its TDD gates:

1. **Task 1 RED: authority exploits** - `2d57eda` (test)
2. **Task 1 GREEN: canonical acceptance authority** - `32ef9d3` (feat)
3. **Task 2 RED: generation publication contract** - `f950a32` (test)
4. **Task 2 GREEN: immutable acceptance generations** - `0d4f226` (feat)
5. **Task 3 RED: path and exit contract gaps** - `c1bfd6c` (test)
6. **Task 3 GREEN: contained CLI and stable exits** - `125703e` (feat)

## Files Created/Modified

- `R/competition/ucl_source_acceptance.R` - Canonical-v2 review, edition, capability, fingerprint, manifest, pointer, generation-reader, and generation-writer authority.
- `scripts/accept_ucl_provider.R` - Fixed provider/edition containment, tagged result constructors/rendering, and documented executable exits.
- `tests/testthat/test_phase18_source_acceptance.R` - Authority exploits, real killed-writer/concurrent-reader tests, traversal/symlink tests, and the subprocess mode matrix.
- `data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/current.json` - Hash-bound current-generation descriptor.
- `data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/` - Immutable six-file fail-closed production generation.

## Decisions Made

- Constructors and durable readers are separate: durable loaders preserve stored hashes exactly, while validators recompute and compare them.
- Generated edition defaults remain pending and non-authoritative; only the exact supported edition with explicit owner review can authorize a live acceptance.
- Prior generations remain available for rollback; writers clean only their own incomplete staging and publish through the pointer.
- Provider-live remains blocked in the committed production state because no real owner/key/source approval exists; manual and fixture candidate modes may succeed without enabling provider automation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a legacy transaction override from the runtime path**
- **Found during:** Task 2 (immutable generation publication)
- **Issue:** A later legacy function definition shadowed the generation-aware live acceptance writer, causing pointer publication tests to fall back to loose-file promotion.
- **Fix:** Made the final public definition generation-aware and verified real writer termination on both sides of the pointer swap.
- **Files modified:** `R/competition/ucl_source_acceptance.R`
- **Verification:** Focused acceptance suite and killed-writer subprocess tests pass.
- **Committed in:** `0d4f226`

**2. [Rule 1 - Bug] Corrected sourced-CLI script identity resolution**
- **Found during:** Task 3 (Rscript mode matrix)
- **Issue:** A subprocess harness `--file` argument could be mistaken for `accept_ucl_provider.R`, resolving production dependencies beneath the temporary directory.
- **Fix:** Prioritized the sourced file and admitted only candidates named `accept_ucl_provider.R`.
- **Files modified:** `scripts/accept_ucl_provider.R`
- **Verification:** All six modes execute in real Rscript subprocesses with their expected result schema and exit class.
- **Committed in:** `125703e`

---

**Total deviations:** 2 auto-fixed bugs
**Impact on plan:** Both fixes were necessary to make the planned generation transaction and subprocess CLI contract execute as designed; no feature scope was added.

## Issues Encountered

- Concurrent reader validation is intentionally expensive because every iteration recomputes all authority hashes; the test uses a bounded 120-read subprocess loop and completed without transient errors.
- Provider-live success was not synthesized against production. Its subprocess proof is the truthful blocked path until real owner/key/source acceptance exists; live-acceptance success and manual/fixture bundle success are covered with test-only evidence.

## Known Stubs

None. Placeholder strings found by the scan are rejection values in owner-review validators, not UI/runtime stubs.

## User Setup Required

None. Production remains intentionally fail-closed until a real provider credential and owner approval are supplied through the established acceptance workflow.

## Next Phase Readiness

- Plans that consume provider authority can rely on one strict canonical-v2 evidence set and one immutable current-generation pointer.
- Source-bundle and refresh follow-ups must pass the actual schema-fingerprint table through their authority calls and preserve the tagged blocked/success semantics.
- The only external blocker remains the intended one: real rights/owner/key/source approval is required before provider automation can become accepted.

## Self-Check: PASSED

- All created production pointer/generation files exist and validate in a fresh R process.
- All six task commits exist in git history.
- The focused acceptance suite, real subprocess crash/concurrency/mode tests, and `git diff --check` pass.
- Unrelated martj42 and untracked debug/benchmark/release artifacts remain untouched.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
