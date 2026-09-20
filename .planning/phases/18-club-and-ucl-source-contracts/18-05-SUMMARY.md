---
phase: 18-club-and-ucl-source-contracts
plan: "05"
subsystem: data-contracts
tags: [r, club-history, provenance, sha256, atomic-promotion, tdd]

requires:
  - phase: 18-club-and-ucl-source-contracts
    provides: validity-aware club identity authority and reviewed-token bootstrap from Plan 18-02
provides:
  - Deterministic pinned-source and normalized club-match contracts with explicit score and evidence-time semantics
  - Exact coverage, identity, duplicate, score, lineage, license, pin, and temporal eligibility gates
  - Eight-artifact atomic audit publisher with independent hash and eligibility recomputation
  - Truthful blocked five-season, six-source-family production audit with no unsafe accepted fallback
affects: [18-06-canonical-source-bundle, phase-19-club-model, club-training-data]

tech-stack:
  added: []
  patterns: [strict prior-information cutoff, complete blocked audit, self-hashed corpus manifest, atomic accepted-only promotion]

key-files:
  created:
    - R/club/history_contract.R
    - scripts/build_club_history_corpus.R
    - data/club/history_sources.csv
    - data/club/history_audits/club-history-2026-01/corpus_manifest.csv
    - tests/testthat/test_phase18_club_history_contract.R
    - tests/fixtures/phase18/openfootball/score_cases.csv
  modified:
    - .gitignore

key-decisions:
  - "The 2021/22–2025/26 six-family panel is an audit panel, not model authority; absent verified pins, paths, licenses, expected counts, and owner mappings remain blocked evidence."
  - "Date-only rows become available at the next UTC day boundary and eligibility uses the strict evidence_available_at_utc < cutoff_utc rule."
  - "A complete audit is always publishable, but accepted state is created or replaced only after independent recomputation of every exact gate."

patterns-established:
  - "Historical evidence: retain unresolved rows and typed reasons, but never turn them into model-eligible observations."
  - "Corpus transaction: canonical tables -> component hashes -> self-hashed manifest -> audit publication -> accepted-only atomic promotion."

requirements-completed: [CLUBHIST-01]

coverage:
  - id: D1
    description: Pinned history normalization with stable club identity, split scores, and conservative evidence time
    requirement: CLUBHIST-01
    verification:
      - kind: unit
        ref: tests/testthat/test_phase18_club_history_contract.R#history-normalization-and-score-semantics
        status: pass
    human_judgment: false
  - id: D2
    description: Exact all-or-nothing historical corpus audit and atomic accepted-only publisher
    requirement: CLUBHIST-01
    verification:
      - kind: integration
        ref: tests/testthat/test_phase18_club_history_contract.R#corpus-transaction-and-tamper-tests
        status: pass
    human_judgment: false
  - id: D3
    description: Production five-season, six-family evidence readiness
    requirement: CLUBHIST-01
    verification:
      - kind: manual_procedural
        ref: data/club/history_audits/club-history-2026-01/corpus_manifest.csv
        status: pass
    human_judgment: true
    rationale: "The manifest truthfully reports blocked status; real commit/path/license/count evidence and every historical identity mapping still require owner review before any accepted corpus can exist."

duration: 15min
completed: 2026-09-20
status: complete
---

# Phase 18 Plan 05: Historical Club Corpus Contract Summary

**A deterministic club-history transaction now normalizes point-in-time match evidence, recomputes strict eligibility gates, and preserves a complete blocked audit without fabricating an accepted training corpus.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-20T09:23:24Z
- **Completed:** 2026-09-20T09:38:24Z
- **Tasks:** 3
- **Files modified:** 14

## Accomplishments

- Added immutable source metadata and stable normalized match contracts with explicit regulation, extra-time, final, and shootout scores plus strict point-in-time availability.
- Added boundary-tested equality and zero-tolerance gates for source pins, licenses, coverage, lineage, identity, duplicates, score semantics, and temporal safety.
- Added an inventory-only CLI that always emits the exact eight-file audit, validates all hashes in a fresh read, and promotes accepted state only after independently recomputing every gate.
- Recorded the first production audit panel truthfully: all 30 rows remain `blocked_pending_review`, `accepted_for_training=FALSE`, and no accepted corpus directory was created.

## Task Commits

Each task followed RED/GREEN TDD; the final production evidence is a separate generated-artifact commit:

1. **Task 18-05-01: Normalize pinned source rows** — `13a931e` (test), `2267a81` (feat)
2. **Task 18-05-02: Declare inventory and audit gates** — `b42d07e` (test), `50f72a4` (feat)
3. **Task 18-05-03: Publish audited corpus** — `99cf41f` (test), `88f51c3` (feat), `91a3941` (chore)

## Files Created/Modified

- `R/club/history_contract.R` - Source, normalized match, audit, publisher, and independent corpus-validation contracts.
- `scripts/build_club_history_corpus.R` - Trusted-root, inventory-only blocked-or-accepted corpus command.
- `data/club/history_sources.csv` - Five completed seasons across England, Spain, Germany, Italy, France, and Champions League source families, all explicitly blocked pending evidence.
- `data/club/history_audits/club-history-2026-01/*.csv` - Exact eight-artifact production audit with component and manifest hashes.
- `tests/testthat/test_phase18_club_history_contract.R` - Forty-nine assertions for pins, scores, timing, thresholds, duplicates, replay, tamper, symlink, and atomic promotion behavior.
- `tests/fixtures/phase18/openfootball/score_cases.csv` - Fictional regulation, date-only, extra-time, penalties, and unknown-score cases.
- `.gitignore` - Keeps `data/club/local_raw/` outside version control.

## Decisions Made

- The declared source families and seasons measure feasibility only; they do not become a Phase 19 model panel until every evidence field and owner review is complete.
- Missing kickoff time is never inferred. Date-only rows retain blank kickoff and use next-day midnight UTC as conservative availability.
- Stable match identity excludes score values, so corrected scores retain match identity while changing row and corpus hashes.
- Blocked audits are durable first-class outputs. They cannot create, replace, or imply accepted training state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved textual scalar representations during CSV read-back**
- **Found during:** Task 18-05-03 corpus transaction verification
- **Issue:** Base CSV inference converted fixed-width fraction strings to numeric values, changing the canonical manifest payload on fresh-process validation.
- **Fix:** Corpus CSV reads now load every column as character before validation, preserving byte-stable canonical scalar representations.
- **Files modified:** `R/club/history_contract.R`
- **Verification:** Blocked and accepted fixture bundles validate after write/read; tampering still fails.
- **Committed in:** `88f51c3`

**2. [Rule 1 - Bug] Corrected inconsistent planning-state fields after SDK updates**
- **Found during:** Plan close-out
- **Issue:** The state SDK advanced plan counts but left frontmatter percent at zero, the milestone row at 3/6, the prior activity description, and new decisions labeled `Phase ?`.
- **Fix:** Reconciled those fields to the authoritative four summaries and Phase 18 context before the metadata commit.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE and ROADMAP both report 4/6 plans and 67 percent progress.
- **Committed in:** plan metadata commit

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs).
**Impact on plan:** The fix is required for deterministic read-back and adds no scope.

## Issues Encountered

- No verified external repository commit/path inventory, license review, expected completed-match counts, or owner-authored historical club mappings were available in scope. Per the source contract, the panel remains blocked rather than using guessed or mutable evidence.
- The production manifest therefore reports zero source-pin, license, lineage, and identity fractions. Coverage, score, and temporal gates also fail because no active rows exist. Duplicate zero-tolerance passes vacuously, but this is insufficient for acceptance.

## Known Stubs

None. Blank production evidence fields and the absent accepted directory are intentional fail-closed state, each paired with explicit `blocked_pending_review` or manifest reasons.

## User Setup Required

Before a production corpus can be accepted, an owner must provide and review full source commits and paths, license evidence, raw hashes/bytes, expected completed-match counts, and evidence-bound club mappings with validity intervals. The CLI must then be rerun against the pinned local raw root.

## Verification

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` — 49 assertions passed.
- `phase18_validate_club_history_corpus("data/club/history_audits/club-history-2026-01")` — passed with recomputed `accepted_for_training=FALSE`.
- Audit root contains exactly eight declared artifacts; accepted root does not exist.
- `git ls-files data/club/local_raw` — empty.
- TDD gate sequence contains test commits before feature commits for all three tasks.

## Next Phase Readiness

- Plan 18-06 can bind this complete blocked audit into the canonical source bundle without overstating model readiness.
- Phase 19 can consume only a future validating accepted corpus. Current production state deliberately blocks club-model training until evidence and identity review are complete.

## Self-Check: PASSED

All declared implementation, fixture, inventory, audit, and test files exist; all seven task/evidence commits exist; focused tests and independent production audit validation passed; no accepted corpus was falsely created.

---
*Phase: 18-club-and-ucl-source-contracts*
*Completed: 2026-09-20*
