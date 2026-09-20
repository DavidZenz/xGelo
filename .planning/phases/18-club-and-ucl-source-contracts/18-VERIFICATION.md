---
phase: 18-club-and-ucl-source-contracts
verified: 2026-09-20T16:20:04Z
status: human_needed
score: "5/5 roadmap must-haves verified"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "0/5"
  gaps_closed:
    - "Trustworthy live-key acceptance authority"
    - "Edition-scoped credential-safe current UCL artifacts"
    - "Atomic last-known-good refresh and provider-exit state"
    - "Stable validity-aware club identity authority"
    - "Pinned, recomputed, temporally safe historical corpus authority"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Complete the real football-data.org owner review and opt-in live-key acceptance probe for UCL 2026/27."
    expected: "All seven owner dimensions, exact 16-capability evidence, four-resource schema/cardinality/freshness checks, and token scan pass before automation becomes enabled."
    why_human: "Provider rights, account scope, current terms, and the behavior of a real external credential cannot be established from fixture replay."
  - test: "Review current and historical club token mappings and their half-open validity intervals."
    expected: "Only explicitly approved club mappings enter registry authority; ambiguous, inactive, cross-domain, and unresolved tokens remain blocked."
    why_human: "Entity identity and historical rename/merger interpretation require domain-owner judgment."
  - test: "Review the pinned historical source commits, paths, license evidence, expected counts, and resulting corpus manifest."
    expected: "A corpus becomes training-eligible only after every pin, license, coverage, identity, score, lineage, duplicate, and temporal gate passes."
    why_human: "The repository intentionally has no accepted real historical generation until source and license evidence is supplied and reviewed."
---

# Phase 18: Club and UCL Source Contracts Verification Report

**Phase Goal:** Operators can acquire and audit lawful Champions League current and historical data through stable club identities without risking credentials or accepted state.

**Verified:** 2026-09-20T16:20:04Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure and final code-review remediation

## Goal Achievement

All five roadmap truths are implemented and behaviorally exercised. The prior 15 critical defects, four warnings, six follow-up blockers, and four follow-up warnings are closed by production-facing regressions. The automated phase gate passed in fresh processes with 142 tests and 840 assertions while proving that verification itself did not mutate production evidence.

The remaining checks are intentionally external judgments: real provider terms/key behavior, real club mappings, and real source/license evidence. Production correctly remains fail-closed until those checks occur, so no fabricated provider, accepted-current-state, club identity, or training authority exists.

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | An operator can run a live-key acceptance check that records lawful-use, attribution, retention, quota, schema, completeness, and freshness evidence before automation | VERIFIED | `phase18_validate_terms_review()`, exact reviewed edition expectations, exact 16-capability evidence, typed/cardinality-aware four-resource fingerprints, immutable acceptance generations, safe edition containment, and live-probe/CLI tests all pass. The committed decision is `not_run`, `missing_credential`, `automation_enabled=FALSE`. |
| 2 | Current fixtures, results, standings, clubs, and lifecycle metadata become edition-scoped, credential-safe, provenance-visible artifacts | VERIFIED | The fixed four-endpoint adapter feeds its canonical eight-column fingerprint table unchanged into the bundle builder; provider/manual/fixture authority binds exact edition and ordered raw hashes; lexical symlinks and hidden/surplus inventory fail. Fixture and integration tests cover real production interfaces without persisting credentials. |
| 3 | Failed, empty, stale, incomplete, concurrent, interrupted, or provider-exit refreshes preserve truthful accepted state | VERIFIED | Immutable accepted/evidence generations become visible through one self-hashed pointer; lock losers mutate nothing; prior ledger/sidecar/incumbent state is prevalidated; post-commit notification faults cannot contradict committed state; provider exit is incumbent- and terms-bound. Production pointer validates as `no_incumbent`. |
| 4 | Current and historical clubs resolve through one stable validity-aware authority that rejects ambiguous and national-team identities | VERIFIED | Canonical-v2 registries, collision-safe tuple grouping, closed club status enum, positive half-open intervals, source-ID-first lookup, exact reviewed aliases, active-at-event enforcement, immutable registry generation publication, and ambiguity/cross-domain tests pass. Production registries contain zero fabricated identities. |
| 5 | Historical club data is pinned and audited for licensing, point-in-time availability, coverage, duplicates, and score semantics before training | VERIFIED | Corpus validation recomputes every gate from bound source/match/registry/review evidence; conservative completion floors and strict cutoffs reject leakage; immutable audit/accepted generation linkage is atomic. Production history validates as `blocked` with no accepted generation. |

**Score:** 5/5 roadmap truths verified; 0 present-but-behavior-unverified.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/common/phase18_canonical_hash.R` | Typed, framed scalar/sequence/row/table hashes | VERIFIED | 277 substantive lines; delimiter, type, missing, control-character, schema, ordering, and multiplicity regressions pass. |
| `R/competition/ucl_source_acceptance.R` + `scripts/accept_ucl_provider.R` | Provider review, acceptance state machine, immutable generations, safe CLI | VERIFIED | Public interfaces exist and are used by the CLI; acceptance generation and self-hashed `current.json` validate. |
| `R/competition/football_data_org_adapter.R` | Fixed four-resource transport/projection and freshness authority | VERIFIED | Fixed host/window, secret boundary, typed schema/cardinality fingerprint, per-resource freshness, identity resolution, and closed failure classification are exercised. |
| `R/competition/ucl_source_bundle.R` | Exact provenance graph and closed authority union | VERIFIED | Bundle construction/validation, lexical symlink checks, snapshot reads, raw/edition binding, recursive exact inventory, replay, and collision paths pass. |
| `R/competition/ucl_source_refresh.R` + current pointer/generation | Atomic last-known-good and provider-exit transaction | VERIFIED | Pointer-selected immutable generations, lock discipline, ledger validation, no-incumbent state, and compliance exits pass failure injection. |
| `R/club/identity.R` + `R/club/identity_bootstrap.R` | Stable validity-aware club identity and atomic registry publication | VERIFIED | Resolver and generation writer are substantive and tested across ambiguity, active status, adjacency, collisions, reader concurrency, and killed writers. |
| `R/club/history_contract.R` + history generation/pointer | Recomputed historical training eligibility | VERIFIED | Pinned-source, normalized-match, exact audit, temporal, inventory, immutable-generation, and pointer readers validate. |
| `scripts/verify_phase18_contracts.R` + eight `test_phase18_*.R` files | Independent adversarial phase gate | VERIFIED | Exact inventory enforced: 15 critical, 4 warning, 15 edge, and 50 prohibition checks; no missing, skipped, warning, or failed test is accepted. |

The generic artifact checker reports four obsolete flat acceptance paths as missing and directory artifacts as `EISDIR`. These are not implementation gaps: Plan 18-08 deliberately replaced the flat six-file acceptance set with the safer `current.json` plus immutable generation layout, and manual read-back validated the selected generation. Other checker misses use function names rather than file paths in plan metadata; the links were traced manually below.

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Provider CLI | Acceptance state machine | Canonical-first source and mode-tagged main | WIRED | CLI calls durable review loader, acceptance-set reader/validator, adapter, bundle builder, and immutable writer. |
| Adapter | Club identity and bundle | Active-at-event resolution plus unchanged fingerprint table | WIRED | Projection calls the club resolver; a dedicated adapter-to-bundle integration test passes without fingerprint substitution. |
| Acceptance pointer | Immutable generation | One captured, self-hashed `current.json` reference | WIRED | Current generation contains the manifest, review, expectations, exact capability matrix, schema fingerprints, and operator explanation. |
| Candidate bundle | Refresh | Full source-authority and bundle recomputation before staging | WIRED | Refresh reads and validates the candidate, revalidates provider authority, stages complete generations, then commits one pointer. |
| Refresh pointer | Transaction/accepted generations | Hash-bound generation IDs, ledgers, sidecar, and accepted ref | WIRED | Production pointer references one valid transaction generation and explicit `no_incumbent`. |
| History validator | Audit builder | Independent recomputation from durable source/match/registry/review snapshots | WIRED | Stored audit claims are exact-compared against rebuilt tables before any accepted authority. |
| History pointer | Audit/accepted generation | One self-hashed descriptor | WIRED | Production points to one blocked audit generation and no accepted generation. |
| Four production CLIs/tests | Canonical hash module | Canonical module sourced before every consumer | WIRED | Loader-order assertions and fresh-process inventory tests pass. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real/explicit data | Status |
|---|---|---|---|---|
| Provider acceptance | review, expectations, capabilities, fingerprint, manifest | immutable selected acceptance generation | Explicit real production state: no credential, no automation | FLOWING, FAIL-CLOSED |
| Current UCL adapter/bundle | four raw resources -> canonical tables -> provenance graph | fixed provider endpoints or explicit manual/fixture authority | Fixture replay proves the path; real provider state is blocked until acceptance | FLOWING, GUARDED |
| UCL refresh | candidate + incumbent + transaction evidence | validated candidate and selected immutable generations | Production truthfully records blocked no-incumbent state | FLOWING, FAIL-CLOSED |
| Club identity | source IDs/aliases/status/intervals | reviewed registry generation or validated legacy-empty set | Production has zero invented identities | FLOWING, FAIL-CLOSED |
| Historical corpus | pinned source rows -> normalized matches -> recomputed audits | exact source and registry/review snapshots | Complete blocked audit exists; no accepted training generation | FLOWING, FAIL-CLOSED |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full Phase 18 contract gate | `Rscript --vanilla scripts/verify_phase18_contracts.R` | `PHASE18_GATE_OK ... files=8 tests=142 assertions=840 production_fail_closed=true` | PASS |
| Production authority read-back | Fresh R process loading acceptance, refresh, history, and club readers | provider `authorized=FALSE reason=missing_credential`; refresh `no_incumbent`; history `blocked`; registries 0/0/0 | PASS |
| Canonical collision/type domain | Fresh R sequence hashes for delimiter collision and character-vs-double | both pairs differ | PASS |
| Repository hygiene | `git diff --check` | exit 0 | PASS |

## Probe Execution

No `probe-*.sh` files are declared. The authoritative R runner is the phase-declared probe and was executed independently with exit code 0. It ran all eight test files in fresh processes, required the exact exploit/edge/prohibition inventories, checked production byte maps before and after, and emitted `PHASE18_GATE_OK`.

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
|---|---|---|---|
| UCLSRC-01 | 18-01, 18-07, 18-08, 18-13, 18-14 | SATISFIED | Exact owner/edition/capability/fingerprint authority, atomic acceptance generations, safe CLI, adversarial regressions. |
| UCLSRC-02 | 18-03, 18-09, 18-13, 18-14 | SATISFIED | Fixed secret-safe adapter, canonical projection, active club identity, per-resource freshness, closed failures. |
| UCLSRC-03 | 18-06, 18-10, 18-13, 18-14 | SATISFIED | Exact edition/raw/fingerprint provenance graph, closed authority union, symlink/snapshot/inventory protection. |
| UCLSRC-04 | 18-04, 18-11, 18-13, 18-14 | SATISFIED | Immutable generation/pointer refresh, lock silence, prevalidated ledger, no-incumbent and provider-exit semantics. |
| CLUBID-01 | 18-02, 18-07, 18-09, 18-13, 18-14 | SATISFIED | Canonical-v2 active validity-aware club authority and atomic registry generations. |
| CLUBHIST-01 | 18-05, 18-12, 18-13, 18-14 | SATISFIED | Conservative temporal policy, exact audit recomputation, source/license gates, atomic audit/accepted visibility. |

No Phase 18 requirement is orphaned. Later phases consume these contracts; none is relied on to repair a Phase 18 gap.

## Anti-Patterns Found

No unreferenced `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, empty implementation, or placeholder-output blocker was found in Phase 18 production files. Matches for `placeholder`, `todo`, and `tbd` are deliberate rejection vocabularies that make human-authority validators fail closed.

## Disconfirmation Pass

- **Partially realized external requirement:** the real provider/key and historical source evidence are intentionally absent, so the implementation is proven as a safe capability but production remains disabled.
- **Misleading-test check:** the original nominal suite missed 15 critical exploits. The final verdict relies on the explicit adversarial catalog and follow-up review regressions, not nominal happy paths.
- **Error-path check:** unknown adapter errors, post-pointer notification failures, malformed provider-exit reviews, lock losers, killed writers, tampered ledgers, and no-incumbent failures now each have named executable coverage.

## Human Verification Required

### 1. Real provider acceptance

**Test:** Complete owner/legal review, supply `FOOTBALL_DATA_API_TOKEN` out of band, and run the opt-in live acceptance probe.
**Expected:** Exact owner, application, 16-capability, four-resource schema/cardinality/freshness, identity, quota, and secret-scan evidence passes before automation becomes enabled.
**Why human:** External terms, account scope, and real credential-backed endpoint behavior cannot be established offline.

### 2. Club identity review

**Test:** Review every real current and historical club token and its validity interval before applying the bootstrap.
**Expected:** Only unambiguous approved club identities enter registry authority; unresolved or cross-domain rows remain blocked.
**Why human:** Canonical entity identity and historical rename/merger semantics require domain-owner judgment.

### 3. Historical source/license review

**Test:** Supply and review exact historical commit pins, paths, license evidence, expected counts, and resulting corpus manifest.
**Expected:** Training authority remains blocked until every source, coverage, identity, score, duplicate, lineage, license, and temporal gate passes.
**Why human:** Real source licensing and intended dataset coverage are external factual judgments.

## Gaps Summary

No automated implementation gaps remain. All five previous root gaps are closed with no detected regression. Status is `human_needed`, rather than `passed`, solely because the real-provider, real-identity, and real-source/license checks are external human judgments; the implemented and committed production behavior for their absence is the required fail-closed state.

---

_Verified: 2026-09-20T16:20:04Z_
_Verifier: the agent (gsd-verifier)_
