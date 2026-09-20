---
phase: 18-club-and-ucl-source-contracts
verified: 2026-09-20T10:37:52Z
status: gaps_found
score: "0/5 roadmap must-haves verified"
behavior_unverified: 0
overrides_applied: 0
next_action: "Gaps found. Plan the fixes, then re-run execute-phase before shipping."
next_command: "/gsd:plan-phase 18 --gaps"
gaps:
  - truth: "An operator can run a trustworthy live-key acceptance check before automation is enabled."
    status: failed
    reason: "Acceptance authority can be forged or enabled from incomplete evidence: row hashes collide, review loading re-hashes tampered rows, pending default expectations validate, four resource rows enable automation without the exact 16-capability matrix, schema fingerprints are not recomputed, and edition IDs can escape the provider evidence directory."
    artifacts:
      - path: "R/competition/ucl_source_acceptance.R"
        issue: "Ambiguous hashing and incomplete review, expectation, capability, and schema-fingerprint validation permit forged accepted authority."
      - path: "scripts/accept_ucl_provider.R"
        issue: "Unvalidated edition IDs permit path traversal during the no-key write path."
    missing:
      - "Use a versioned unambiguous canonical encoding for every Phase 18 row/table hash and migrate persisted hashes."
      - "Validate durable review hashes without rewriting them and require an explicit production review set."
      - "Require approved expectation review metadata and the exact 16-row capability/evidence matrix."
      - "Recompute and validate the durable four-row schema fingerprint from the actual table."
      - "Allow only the supported edition ID and verify the resolved evidence path remains contained."
  - truth: "Current UCL resources are ingested into edition-scoped, credential-safe, tamper-evident artifacts."
    status: failed
    reason: "Candidate authority is not bound to the candidate edition or raw bytes, in-root symlinks pass the guard, and resource freshness is reported true after checking only competition metadata."
    artifacts:
      - path: "R/competition/ucl_source_bundle.R"
        issue: "Manual/provider authority and exact inventories are not fully bound to candidate bytes, edition, or symlink-free paths."
      - path: "R/competition/football_data_org_adapter.R"
        issue: "Stale team/match/standings timestamps can pass with freshness_passed=TRUE."
    missing:
      - "Bind every authority variant to the exact candidate edition and canonical aggregate of the four raw resource hashes."
      - "Check lexical path components for symlinks before resolution and enforce exact hidden/evidence inventories."
      - "Validate freshness for every required resource and relevant row; derive freshness_passed from those checks."
  - truth: "Failed or concurrent refreshes preserve an atomic last-known-good bundle and auditable state."
    status: failed
    reason: "Readers can observe partial accepted trees, lock losers mutate shared history without the lock, invalid prior history is retained while a refresh reports accepted, and provider exit can act on an unrelated or unreadable incumbent."
    artifacts:
      - path: "R/competition/ucl_source_refresh.R"
        issue: "File-by-file publication, unlink-before-rename writers, unlocked collision evidence, missing pre-validation, and unbound provider-exit review violate the transaction contract."
    missing:
      - "Publish complete generations through one atomic directory/pointer swap without unlink-before-rename windows."
      - "Never mutate shared evidence without the transaction lock."
      - "Validate incumbent history/sidecar before mutation and validate the resulting ledger before commit."
      - "Load and validate the incumbent bundle and bind provider exit to its provider, edition, decision ID, decision hash, and inventory."
  - truth: "Every current and historical club resolves through a stable, validity-aware, fail-closed club identity contract."
    status: failed
    reason: "The shared delimiter-ambiguous row hash permits distinct identity rows to collide, and club validity/status metadata is not consistently validated or enforced during resolution."
    artifacts:
      - path: "R/club/identity.R"
        issue: "Row integrity is collision-prone; club timestamps/status values are not fully validated and inactive states may still resolve."
    missing:
      - "Adopt unambiguous row encoding for identity artifacts and recompute all registries."
      - "Validate club validity intervals and a closed status enum, and enforce active status during resolution."
  - truth: "The historical club corpus is independently pinned and audited for safe model-training eligibility."
    status: failed
    reason: "Evidence that predates kickoff is treated as model-eligible, and corpus validation trusts stored identity/duplicate/score/temporal audit claims instead of recomputing them from normalized matches and bound registry/review artifacts."
    artifacts:
      - path: "R/club/history_contract.R"
        issue: "Temporal leakage and self-consistent forged audit claims can pass accepted_for_training validation."
    missing:
      - "Require result evidence at or after a conservative match completion instant and before cutoff."
      - "Recompute every eligibility gate from matches/source rows and verify the exact registry/review artifact hashes."
      - "Publish audit and accepted state as one generation and reject hidden/surplus inventory."
deferred: []
---

# Phase 18: Club and UCL Source Contracts Verification Report

**Phase Goal:** Operators can acquire and audit lawful Champions League current and historical data through stable club identities without risking credentials or accepted state.

**Verified:** 2026-09-20T10:37:52Z  
**Status:** gaps_found  
**Re-verification:** No — initial verification

## Goal Achievement

The phase is not ready to proceed. All planned artifacts exist and the nominal Phase 18 suite passes, but adversarial execution reproduced every one of the 15 blockers in `18-REVIEW.md`. These failures invalidate all five roadmap success criteria and all six Phase 18 requirements.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | Live-key acceptance records lawful-use, attribution, retention, quota, schema, completeness, and freshness evidence before automation | FAILED | A four-row machine matrix enabled automation; pending default expectations validated; tampered owner review was re-hashed and accepted; schema fingerprint tampering remained authoritative; unsafe edition traversal wrote outside the provider directory. |
| 2 | Current UCL data becomes edition-scoped, credential-safe, provenance-visible artifacts | FAILED | A wrong-edition/unrelated-raw manual review produced a promotion-eligible candidate; an in-root symlink passed; a 2020 team timestamp produced `freshness_passed=TRUE`. |
| 3 | Failed, empty, stale, incomplete, or concurrent refreshes preserve last-known-good accepted state | FAILED | A promotion hook observed a one-file accepted tree; lock collision wrote history without the lock; invalid prior history was appended and the refresh returned accepted; unrelated incumbent bytes accepted provider-exit review. |
| 4 | Current and historical club records resolve through a stable validity-aware club identity contract | FAILED | Distinct identity rows collide under the shared delimiter hash; club status/validity metadata is not consistently enforced. |
| 5 | Historical club data is independently pinned/audited before training | FAILED | Pre-kickoff result evidence returned `counts_for_model=TRUE`; a bundle with a blank club identity and rehashed stored claims still validated as training-accepted. |

**Score:** 0/5 roadmap truths verified.

## Required Artifacts

The artifact existence checker passed 27/27 declared artifacts. Existence is not the failure mode; substantive validation and transaction semantics are.

| Plan | Artifacts | L1 Exists | L2 Substantive | L3 Wired | Final status |
|---|---:|---|---|---|---|
| 18-01 provider acceptance | 7/7 | yes | yes | yes | FAILED behavior/authority |
| 18-02 club identity | 6/6 | yes | yes | yes | FAILED integrity/status |
| 18-03 provider adapter | 3/3 | yes | yes | yes | FAILED freshness |
| 18-04 refresh transaction | 4/4 | yes | yes | yes | FAILED atomicity/ledger/exit |
| 18-05 historical corpus | 4/4 | yes | yes | yes | FAILED temporal/audit recomputation |
| 18-06 source bundle | 3/3 | yes | yes | yes (manual trace) | FAILED authority/path binding |

The automated key-link checker reported 13/15 links. Its two 18-06 misses were pattern false negatives: manual tracing confirms adapter bytes/URLs flow into `phase18_build_ucl_source_bundle()`, and refresh calls `phase18_validate_ucl_source_bundle()` plus source-authority checks. The links are present, but their security semantics are incomplete.

## Data-Flow Trace (Level 4)

| Artifact | Data flow | Result |
|---|---|---|
| Provider acceptance | CLI -> owner review / edition expectations / machine checks -> acceptance manifest | Data flows, but the loader rewrites review hashes and the enabling conjunction accepts incomplete/unreviewed evidence. |
| Current adapter | Four fixed responses -> canonical clubs/matches/standings/lifecycle -> coverage | Real response data flows, but per-resource freshness is not validated and the success boolean is constant. |
| Source bundle | Raw bytes + canonical tables + authority -> candidate manifests/tree | Data flows, but manual/provider authority is not bound to the same edition and raw-byte aggregate; symlink and inventory checks are incomplete. |
| Refresh | Candidate -> staged files -> reader-visible accepted root -> history/sidecar | Data flows, but publication is file-by-file and ledger mutations are not consistently lock-protected or prevalidated. |
| Historical corpus | Pinned source rows -> normalized matches -> stored audits -> corpus manifest | Data flows, but pre-kickoff evidence is eligible and validation trusts stored audit assertions instead of recomputing them. |

## Adversarial Finding Validation

All 15 review blockers were independently confirmed against the current code.

| Finding | Classification | Independent evidence |
|---|---|---|
| CR-01 delimiter-ambiguous hashes | BLOCKER confirmed | `("x|y","z")` and `("x","y|z")` produced the same SHA-256. |
| CR-02 owner review re-hashing/fixture preference | BLOCKER confirmed | A stale-hash review changed to reviewer `attacker`; `phase18_read_terms_review()` replaced hashes and validation returned true. |
| CR-03 unreviewed expectations | BLOCKER confirmed | `reviewer=pending_owner_review` returned `valid=TRUE`. |
| CR-04 incomplete capability evidence | BLOCKER confirmed | Four resource rows produced `automation_enabled=TRUE` and `decision=accepted`; the other 12 required capabilities were absent. |
| CR-05 schema fingerprint not validated | BLOCKER confirmed | A modified fingerprint table still passed `phase18_validate_source_authority(provider_live, ...)`. |
| CR-06 authority not bound to bytes/edition | BLOCKER confirmed | Review edition `ucl_wrong_edition` with unrelated aggregate raw hash produced a promotion-eligible `ucl_2026_27` candidate. |
| CR-07 symlink guard bypass | BLOCKER confirmed | An in-root file symlink returned `symlink_result=accepted`. |
| CR-08 mixed-state/crash windows | BLOCKER confirmed | An observer hook saw `artifacts.csv` alone in the accepted root during promotion; writers also unlink incumbents before rename. |
| CR-09 lock loser mutates history | BLOCKER confirmed | `concurrent_refresh` wrote one history row while the competing lock existed. |
| CR-10 invalid history accepted | BLOCKER confirmed | A `not-a-hash` prior row remained in a two-row ledger while refresh returned `accepted`; post-validation failed. |
| CR-11 provider exit not incumbent-bound | BLOCKER confirmed | A self-hashed provider review retained an arbitrary two-file tree with no valid provider bundle. |
| CR-12 pre-kickoff result leakage | BLOCKER confirmed | Kickoff 18:00, evidence 10:00 produced `counts_for_model=TRUE`. |
| CR-13 partial freshness validation | BLOCKER confirmed | A team last updated in 2020 produced `freshness_passed=TRUE` in a 2026 projection. |
| CR-14 stored audit claims trusted | BLOCKER confirmed | After blanking `home_club_id`, recomputing only row/component/manifest hashes preserved `accepted_for_training=TRUE`. |
| CR-15 edition path traversal | BLOCKER confirmed | Edition `../../escaped` created `escaped/acceptance_manifest.csv` outside the evidence root. |

### Warnings validated

| Finding | Status | Impact |
|---|---|---|
| WR-01 club status/validity inconsistency | WARNING confirmed | Club timestamps/status enum are not fully validated; resolution does not require active status. |
| WR-02 hidden/surplus inventory ignored | WARNING confirmed | `all.files=FALSE` and incomplete authority-evidence inventory checks omit hidden/surplus files. |
| WR-03 candidate CLI success footer | WARNING confirmed | Candidate modes return metadata without `manifest`, while the executable footer always dereferences `result$manifest`. |
| WR-04 audit/accepted split transaction | WARNING confirmed | Audit publication occurs before accepted publication, allowing roots to disagree on failure. |

## Behavioral Spot-Checks

| Check | Result | Status |
|---|---|---|
| Full Phase 18 test set (`testthat::test_dir(..., filter="phase18")`) | 403 assertions across six files, exit 0 | PASS, but insufficient |
| Hash collision probe | Distinct records produced identical hash | FAIL |
| Owner-review tamper probe | Tampered reviewer re-hashed and validated | FAIL |
| Four-row live acceptance probe | Accepted with automation enabled | FAIL |
| Schema/edition/raw authority probes | Tampered or mismatched authority remained valid/promotable | FAIL |
| Symlink and path-traversal probes | Both escaped intended trust boundaries | FAIL |
| Refresh concurrency/atomicity/history probes | Unlocked mutation, partial reader state, and invalid ledger acceptance reproduced | FAIL |
| Historical leakage/audit probes | Pre-kickoff evidence and forged audit claims accepted | FAIL |

The passing suite is therefore misleading evidence for the phase goal: it proves the implemented happy-path contracts, not the adversarial invariants those contracts claim.

## Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probes exist. The verifier ran direct read-only R probes in fresh processes using temporary roots; none modified repository source or durable project data.

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| UCLSRC-01 | BLOCKED | CR-01 through CR-05 and CR-15 permit forged, incomplete, or path-escaped provider acceptance. |
| UCLSRC-02 | BLOCKED | CR-07 and CR-13 allow unsafe paths and stale current resources to pass. |
| UCLSRC-03 | BLOCKED | CR-01, CR-05, CR-06, CR-07, and WR-02 invalidate tamper-evident provenance/authority claims. |
| UCLSRC-04 | BLOCKED | CR-08 through CR-11 violate atomic last-known-good, ledger integrity, lock ownership, and provider-exit authorization. |
| CLUBID-01 | BLOCKED | CR-01 and WR-01 undermine stable registry integrity and active validity semantics. |
| CLUBHIST-01 | BLOCKED | CR-12 and CR-14 allow temporal leakage and forged eligibility audits into accepted training state. |

No Phase 18 requirement is orphaned, and no gap is explicitly deferred by Phases 19–22. Later phases depend on these contracts; they do not repair them.

## Anti-Patterns Found

No unreferenced `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, placeholder, empty-return, or console-only markers were found in the Phase 18 implementation files. The blockers are substantive logic and transaction defects, not visible stubs.

## Prohibitions and Human Verification

The plans contain 20 `[FLAGGED-UNVERIFIED]` prohibitions. They are not silently passed. Several are contradicted by the automated probes (tamper evidence, path containment, fixture/incomplete authority, atomic accepted state, and historical temporal safety); the remainder still require explicit human review after code gaps close.

Deferred end-of-phase human checks remain:

1. Review the real provider account terms, attribution, retention, termination, and live-key evidence.
2. Review every production current/historical club mapping and validity interval.
3. Review pinned historical commits, paths, licenses, expected counts, and the final corpus manifest.
4. Review the technical-failure and provider-exit retain/withdraw matrix against corrected atomic transactions.

Human approval cannot override the reproduced code defects.

## Gaps Summary

Five root concerns block the phase goal:

1. Provider acceptance authority can be forged from ambiguous hashes, rewritten reviews, unreviewed expectations, incomplete capability evidence, unvalidated schema fingerprints, and unsafe edition paths.
2. Current candidate provenance does not bind authority to the exact edition/bytes and does not fully enforce freshness or filesystem trust boundaries.
3. Refresh and provider-exit transactions are not atomic or consistently lock/ledger/incumbent validated.
4. Club registry integrity/status semantics are incomplete.
5. Historical eligibility admits pre-kickoff outcome evidence and trusts stored audit claims.

The correct escalation route is gap planning, not Phase 19:

`/gsd:plan-phase 18 --gaps`

---

_Verified: 2026-09-20T10:37:52Z_  
_Verifier: the agent (gsd-verifier)_
