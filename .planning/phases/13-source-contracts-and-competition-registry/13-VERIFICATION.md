---
phase: 13-source-contracts-and-competition-registry
verified: 2026-08-15T14:31:35Z
status: gaps_found
score: 7/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/8
  gaps_closed:
    - "Accepted production fixture and result publication now resolves stable team IDs while preserving UEFA source values and edition provenance."
    - "Failed refresh publication now persists the blocked edition overlay, registry-side blocked_refresh.json, and append-only status history."
    - "Production loaders now validate accepted directories, canonical/raw/manifest hashes, normalized result lineage, and default identity source-bundle provenance."
  gaps_remaining:
    - "Plan 13-12's bounded normalized publication transaction is not wired into the public acquisition entrypoint."
  regressions: []
gaps:
  - truth: "A successful production acquisition routes both trusted source-shaped edition handoffs through the bounded fourteen-target normalized publication transaction."
    status: failed
    reason: "phase13_publish_normalized_editions() is defined and tested, but no production call site reaches it. The public acquisition path publishes one edition through phase13_acquire_publish_accepted() and updates registries separately; invoking the transaction against the current accepted tree fails because its handoff validator expects source-shaped fixtures while the committed tree is already normalized."
    artifacts:
      - path: "scripts/acquire_uefa_snapshot.R"
        issue: "phase13_acquire_main() calls phase13_acquire_publish_refresh(), which calls phase13_acquire_publish_accepted() and phase13_acquire_update_registries(), but never calls phase13_publish_normalized_editions()."
      - path: "R/competition/publication_transaction.R"
        issue: "The lock/snapshot/rollback primitives are substantive and imported, but they do not by themselves connect the production acquisition flow."
      - path: "tests/testthat/test_phase13_publication_integration.R"
        issue: "The integration harness rewrites temporary accepted tables into source-shaped handoffs before calling phase13_publish_normalized_editions(); it does not prove the public acquisition entrypoint invokes that transaction."
    missing:
      - "Wire the complete two-edition normalized transaction into the production acquisition route, or provide an equivalent public orchestration entrypoint that is actually called."
      - "Add an end-to-end regression through phase13_acquire_main()/phase13_acquire_publish_refresh() proving the fourteen-target graph, hash refresh, loader success, and all-or-nothing promotion."
---

# Phase 13: Source Contracts and Competition Registry Verification Report

**Phase Goal:** Analysts can capture authoritative UEFA competition snapshots and register both competition editions under one auditable contract.

**Verified:** 2026-08-15T14:31:35Z

**Status:** gaps_found

**Re-verification:** Yes — after Plans 13-07 through 13-12 and the validation updates.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | An analyst can capture official five-class UEFA snapshots for both editions. | ? UNCERTAIN | Both edition fixture replays pass the CLI dry-run. The repository's own validation record says the undocumented live UEFA JSON endpoints were unavailable; retained “official” evidence is fixture-backed, so live official capture remains a human/operational check. |
| 2 | Accepted snapshots expose URL, retrieval time, raw-byte hash, Git parser identity, fallback status, and stable hashes while raw bytes remain ignored. | ✓ VERIFIED | Current production loader passes against both editions, validating ten raw artifacts, manifests, canonical hashes, and provenance. `data/competition/local_raw/` is ignored and `git ls-files data/competition/local_raw` is empty; the source suite passes 175 expectations. |
| 3 | Reviewed manual fallback is complete, visible, edition-wide, and cannot mix with official artifacts. | ✓ VERIFIED | Focused source/refresh checks pass. The retained fallback evidence has all five Nations League artifacts marked `reviewed_fallback`/`approved` with source, retrieval date, reason, operator note, and checksum; mixed-provenance rejection is covered by the source tests. |
| 4 | Normalized records retain UEFA names while resolving to stable team and edition IDs in the accepted production path. | ✓ VERIFIED | `phase13_acquire_publish_accepted()` calls `phase13_normalize_fixture_rows()` and `phase13_normalize_accepted_result_rows()` before staged promotion. Current accepted Nations League fixtures/results contain stable team IDs, UEFA IDs/display names, edition IDs, and both artifact links; the source and registry suites pass 175 and 155 expectations. EURO remains schema-complete and empty. |
| 5 | Both edition registry rows contain lifecycle, source bundle, approved model release, and output target. | ✓ VERIFIED | `load_competition_edition_registries()` and the trusted Phase 12 release preflight pass. Current rows contain source bundle IDs, `phase12-wc2026-incumbent-retained-v1`, output targets, and lifecycle states `scheduled` and `pre_draw`. |
| 6 | Failed refreshes fail closed, retain the active output, and mark the edition blocked. | ✓ VERIFIED | The focused refresh suite passes 40 expectations. Its temporary-copy failure path updates `competition_editions.csv`, writes the registry-side `blocked_refresh.json` and append-only `status_history.csv`, retains accepted/source bytes, and exercises sidecar rollback and explicit recovery. |
| 7 | Lifecycle transitions are forward-only, blocked recovery is explicit, and EURO remains truthful pre-draw. | ✓ VERIFIED | The registry suite passes lifecycle/recovery and pre-draw regressions. Current EURO has `pre_draw`, explicit status, zero fixtures/groups/standings/results, and the pre-draw note; no fabricated structures are present. |
| 8 | Production loaders connect accepted snapshot tables and identity provenance to the registry contract. | ✓ VERIFIED | An independent current-state load returned `loader=OK editions=2 accepted_snapshots=2`. Loader tests cover missing accepted directories, table/manifest tampering, stale canonical hashes, forged identity foreign keys, and result/fixture lineage; the registry suite passes 155 expectations. |

**Score:** 7/8 truths verified. Truth 1 remains uncertain only because live external-service evidence is unavailable; the phase is nevertheless `gaps_found` because the later Plan 13-12 production-wiring contract is observably broken.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/competition/source_contracts.R` | Structured-resource, provenance, raw-byte, fallback, and hash contracts | ✓ VERIFIED | Substantive implementation; sourced by acquisition and loader paths and exercised by the 175-expectation source suite. |
| `R/competition/team_identity.R` | Stable identity resolver, normalized fixture/result schemas, historical identity contracts | ✓ VERIFIED | Normalizers are called by accepted publication; default identity loading validates adjacent `source_bundles.csv`; registry and source suites pass. |
| `R/competition/edition_registry.R` | Edition lifecycle, release, accepted-snapshot, hash, and provenance validation | ✓ VERIFIED | Production loader reads and validates both accepted edition trees and the trusted release pin. |
| `R/competition/publication_hashes.R` and `R/competition/publication_manifests.R` | Staged canonical and derived hash-graph refresh | ✓ VERIFIED | Hash suite: 107 expectations; manifest suite: 68 expectations; both pass without warnings/skips. |
| `R/competition/publication_transaction.R` | Bounded fourteen-target lock, snapshot, promotion, and rollback envelope | ⚠️ PARTIAL | Implementation is substantive and imported by the acquisition script; its production call path is missing, which is the remaining blocker. |
| `scripts/acquire_uefa_snapshot.R` | Bounded capture, accepted publication, fallback, refresh blocking, and normalized transaction integration | ⚠️ PARTIAL | Direct one-edition accepted publication and refresh blocking work. The public entrypoint does not invoke the dual-edition normalized transaction. |
| `data/competition/accepted/{uefa_nations_league_2026_27,uefa_euro_2028_qualifying}/` | Manifest plus five accepted resource tables per edition | ✓ VERIFIED | Current loader validates all twelve files; Nations League fixtures/results are normalized, and EURO pre-draw tables are schema-valid empty tables. |
| `data/competition/registries/{competition_editions,source_bundles,source_artifacts,team_identity}.csv` | Durable edition, bundle, artifact, and identity provenance | ✓ VERIFIED | Both editions and all ten artifacts load with matching hashes and foreign keys. |
| `data/competition/registries/martj42_identity_map.csv`, `martj42_edition_lookup.csv`, and `data/processed/martj42_historical_normalized.csv` | Complete historical identity/edition projection and normalized artifact | ✓ VERIFIED | Current files contain 337 identity rows and 49,520 historical/lookup rows; the registry suite covers the targets seam and future/score-only safety. |
| `tests/testthat/test_phase13_*.R` | Focused source, registry, hash, manifest, transaction, integration, and refresh regressions | ✓ VERIFIED | All seven focused suites pass with 751 total expectations and no failures, warnings, or skips. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Structured fixture/live payload | Source artifact and bundle registries | Capture candidate validation and manifest construction | ✓ WIRED | Five required resource classes, URL/retrieval/raw hash/parser/fallback metadata, and bundle links are built and validated. |
| Candidate bundle | Accepted edition directory | `phase13_acquire_publish_accepted()` | ✓ WIRED | Raw bytes, candidate manifest, normalized tables, and the complete six-file accepted directory are staged and validated before promotion. |
| Accepted source fixtures | Stable team identity | `phase13_normalize_fixture_rows()` | ✓ WIRED | The production accepted path calls the resolver; current fixtures carry stable IDs and preserved UEFA source values. |
| Accepted source results + normalized fixtures | Normalized results | `phase13_normalize_accepted_result_rows()` | ✓ WIRED | Exact `source_fixture_id` join preserves identity, status, scores, edition, result artifact, and fixture artifact lineage. |
| Accepted table content | Artifact canonical hash | Plan 13-11 hash helpers | ✓ WIRED | Ten-resource hash and manifest suites pass; production loader recomputes and rejects drift. |
| Edition/identity registries | Accepted snapshots | Production loaders | ✓ WIRED | Current loader succeeds for both editions and default identity loading checks source-bundle foreign keys. |
| Failed candidate | Blocked edition, sidecar, and history | Refresh failure path | ✓ WIRED | Focused refresh tests and retained invalid-replacement evidence show matching batch IDs, blocked state, retained output, rollback, and explicit recovery. |
| Source-shaped dual-edition handoffs | Normalized fourteen-target transaction | `phase13_publish_normalized_editions()` from public acquisition | ✗ NOT WIRED | The function has no production call site. The current-root invocation fails with `Phase 13 normalized publication source handoff schema mismatch: uefa_nations_league_2026_27/fixtures`; the integration test first rewrites its temporary accepted tables to source-shaped handoffs. |
| Successful normalized transaction | Post-normalization loader | Transaction callback then `load_competition_edition_registries()` | ⚠️ PARTIAL | Direct temporary-root helper tests pass, but the production acquisition entrypoint cannot reach this chain. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Accepted Nations League `fixtures.csv`/`results.csv` | Normalized fixture/result rows | Fixture replay or bounded capture → accepted-table normalizers | Yes; current rows contain stable IDs, source names, edition, and lineage | ✓ FLOWING |
| Accepted EURO resource tables | Empty normalized structures | Explicit `pre_draw` adapter/status | Yes, intentionally empty and schema-valid | ✓ FLOWING |
| `source_artifacts.csv`/`source_bundles.csv` and manifests | Raw/canonical/derived provenance | Ignored local JSON bytes and staged hash helpers | Yes; current loader verifies the graph | ✓ FLOWING |
| Historical normalized artifact | Stable historical IDs/editions | `elo_matches` → `phase13_load_martj42_historical_results()` target seam | Yes; 49,520 rows | ✓ FLOWING |
| Dual-edition normalized publication | Atomic fourteen-target output | `phase13_publish_normalized_editions()` helper tests | Yes in temporary source-shaped test handoffs | ⚠️ DISCONNECTED FROM PUBLIC ACQUISITION |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Source contracts, bounded capture, accepted publication, fallback, and raw-byte boundaries | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | 175 expectations; 0 failures/warnings/skips | ✓ PASS |
| Identity, normalized records, edition registry, loader, and historical contracts | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | 155 expectations; 0 failures/warnings/skips | ✓ PASS |
| Canonical table/content hashes | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_hashes.R")'` | 107 expectations; 0 failures/warnings/skips | ✓ PASS |
| Accepted manifests and derived hash graph | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_manifests.R")'` | 68 expectations; 0 failures/warnings/skips | ✓ PASS |
| Publication lock, snapshots, fourteen-target rollback | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_transaction.R")'` | 117 expectations; 0 failures/warnings/skips | ✓ PASS |
| Temporary dual-edition normalized publication integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_integration.R")'` | 89 expectations; 0 failures/warnings/skips | ✓ PASS, but helper-level only |
| Failed refresh, blocked state, sidecar rollback, and recovery | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R")'` | 40 expectations; 0 failures/warnings/skips | ✓ PASS |
| Both current edition fixture dry-runs | `Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id <edition> --dry-run` | Nations League and EURO candidates both valid | ✓ PASS |
| Current production registry load | `load_competition_edition_registries("data/competition/registries")` | `loader=OK editions=2 accepted_snapshots=2` | ✓ PASS |
| Current accepted tree through normalized transaction helper | `phase13_publish_normalized_editions(output_root="data/competition/accepted", registry_root="data/competition/registries", ...)` | Fails before promotion: source-handoff schema mismatch on normalized fixtures | ✗ FAIL |

The repository-wide `testthat::test_dir("tests/testthat")` suite was not rerun in this verification. The current `13-VALIDATION.md`/13-06 validation record separately documents its known unrelated Phase 10 statistical-challenger drift: the full run exits nonzero on pre-existing `source_artifact_sha256` feature-contract rows 42–47, while all Phase 13 suites pass. This is not counted as a Phase 13 gap and was not altered.

## Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probes were found. Probe execution was skipped.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DATA-01 | 13-01, 13-02, 13-07, 13-09, 13-10, 13-12 | Capture official UEFA fixtures, groups, standings, results, and status snapshots | ? NEEDS HUMAN | Both fixture-backed five-class candidate dry-runs pass; current live official structured endpoint evidence is unavailable. |
| DATA-02 | 13-01, 13-02, 13-05, 13-07, 13-09, 13-10, 13-11, 13-12 | Preserve URL, retrieval time, raw-byte hash, parser identity, fallback, and canonical/derived provenance | ✓ SATISFIED | Current loader and focused source/hash/manifest suites validate the ten-artifact graph and ignored raw-byte store. |
| DATA-03 | 13-01, 13-03, 13-04, 13-05, 13-08, 13-11, 13-12 | Normalize stable team/edition IDs while preserving source names and historical identity | ✓ SATISFIED with atomic-publication gap | Direct accepted publication, current data, loaders, historical target seam, and focused tests pass; the separate Plan 13-12 dual-edition transaction is not reached by the public acquisition path. |
| DATA-04 | 13-01, 13-02, 13-06, 13-07, 13-09, 13-10, 13-11, 13-12 | Support visible, reviewed, edition-wide fallback without mixed provenance | ✓ SATISFIED | Fallback metadata/checksum and mixed-provenance rejection pass; failed refresh preserves accepted output and source registries. |
| COMP-01 | 13-01, 13-03, 13-05, 13-06 | Register lifecycle, source bundle, release, output target, blocked state, and recovery | ✓ SATISFIED | Both current registry rows load; focused registry/refresh tests prove blocked sidecar/history linkage and explicit recovery. |

No Phase 13 requirement IDs are orphaned. Later roadmap phases 14–17 have no specific success criterion covering the missing Plan 13-12 acquisition wiring, so no gap is deferred.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `scripts/acquire_uefa_snapshot.R` | 2003–2089, 2733–2799 | Normalized fourteen-target transaction is defined and fully tested, but the public refresh/acquisition path never calls it | 🛑 BLOCKER | Production can publish a one-edition normalized output without the declared dual-edition atomic publication boundary. |
| Phase 13 implementation/tests/data | — | `TBD`, `FIXME`, or `XXX` debt markers; placeholder/empty implementation patterns | ℹ️ NONE FOUND | Anti-pattern scan returned no matches. EURO empty tables are intentional `pre_draw` data, not stubs. |

## Human Verification Required

These items remain human/operational checks; they do not replace the failed production-wiring gap.

### 1. Official live structured replay

**Test:** Run the acquisition entrypoint with current official HTTPS JSON URLs for fixtures, groups, standings, results, and optional status, in an isolated output/registry/raw root; then verify normalized publication and the production loader.

**Expected:** All five resources are structured JSON, provenance/raw hashes/parser identity are recorded, both required edition contracts remain coherent, and loader success follows the final normalized publication path.

**Why human:** UEFA endpoint availability and response shape are external and were not evidenced by the committed fixture replay.

### 2. Reviewed fallback and failed-replacement operator review

**Test:** Independently review the isolated fallback and invalid-replacement evidence, including the operator approval, prior-output byte preservation, blocked sidecar/history linkage, and explicit recovery.

**Expected:** Fallback metadata is accepted only as a complete edition-wide reviewed bundle; invalid replacement remains blocked and recovery uses a distinct batch without mutating the immutable blocked record.

**Why human:** Review approval and operational evidence cannot be established by source inspection alone; `13-UAT.md` records these as passes but also notes that the human-check metadata is not in the supported automated format.

## Gaps Summary

The three gaps from the 2026-08-13 initial report are closed in the current codebase: direct accepted publication now emits normalized fixture/result records, refresh failure updates durable blocked state, and production loaders validate accepted snapshots and identity provenance. All seven focused Phase 13 suites pass (751 expectations), both current editions load successfully, and the committed data satisfies the five roadmap success criteria except for the external live-capture evidence.

The remaining blocker comes from the later Plan 13-12 contract. `phase13_publish_normalized_editions()` is a real lock/hash/rollback implementation, but the public acquisition path does not call it. Its direct current-root invocation fails on the already-normalized `fixtures.csv`, while the passing integration test first converts temporary tables back to source-shaped handoffs. The phase must not advance until this production orchestration seam is wired and covered end to end.

No implementation or unrelated files were changed by this verification; this report is the only intended update.

---

_Verified: 2026-08-15T14:31:35Z_
_Verifier: the agent (gsd-verifier)_
