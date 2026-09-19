---
phase: 13-source-contracts-and-competition-registry
verified: 2026-08-16T12:00:56Z
status: passed
score: 7/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/8
  gaps_closed:

    - "A successful public acquisition now builds both trusted source-shaped handoffs and reaches the bounded fourteen-target normalized publication transaction."
  gaps_remaining: []
  regressions: []
human_verification:

  - test: "Run phase13_acquire_main() or the CLI with current official UEFA HTTPS structured URLs for fixtures, groups, standings, results, and status in isolated roots."
    expected: "Both edition contracts capture structured resources, retain URL/retrieval/raw-byte/parser/fallback provenance, complete normalized publication, and pass the production loader."
    why_human: "UEFA endpoint availability and response shape are external; committed fixture replay cannot prove a live official capture."

  - test: "Independently review the isolated reviewed-fallback and invalid-replacement evidence, including operator approval, byte preservation, blocked sidecar/history linkage, and explicit recovery."
    expected: "Fallback is complete and edition-wide; invalid replacement remains blocked; recovery uses a distinct batch without mutating immutable blocked evidence."
    why_human: "Operator approval and operational evidence require human review even though the deterministic contract tests pass."
---

# Phase 13: Source Contracts and Competition Registry Verification Report

**Phase Goal:** Analysts can capture authoritative UEFA competition snapshots and register both competition editions under one auditable contract.

**Verified:** 2026-08-16T12:00:56Z

**Status:** human_needed

**Re-verification:** Yes — the previously failed public normalized-publication wiring gap was re-checked after Plan 13-13.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | An analyst can capture official five-class UEFA snapshots for both editions. | ? UNCERTAIN | Fixture-backed dry-runs and the source-contract suite pass, and the public path is bounded for HTTPS capture; live official UEFA response availability remains an external human check. |
| 2 | Accepted snapshots expose URL, retrieval time, raw-byte hash, Git parser identity, fallback status, and stable hashes while raw bytes remain ignored. | ✓ VERIFIED | Current graph has 10 source artifacts and 2 bundles; the independent loader/public-success checks validate provenance and refreshed hashes, and `git ls-files data/competition/local_raw` returns no tracked files. |
| 3 | Reviewed manual fallback is complete, visible, edition-wide, and cannot mix with official artifacts. | ✓ VERIFIED | Focused source and refresh suites pass; validators require all five resource classes and reject mixed provenance. The remaining operator approval review is listed under Human Verification. |
| 4 | Normalized records retain UEFA names while resolving to stable team and edition IDs in the accepted production path. | ✓ VERIFIED | The public integration suite passes source-shaped handoff assertions, normalized identity/display-name assertions, and loader checks; `scripts/acquire_uefa_snapshot.R:1908-1935,2315-2323` performs the source-to-normalized transition. |
| 5 | Both edition registry rows contain lifecycle, source bundle, approved model release, and output target. | ✓ VERIFIED | Current registry inspection reports 2 editions, 2 bundles, and 10 artifacts; rows are `scheduled` and `pre_draw`, both pin `phase12-wc2026-incumbent-retained-v1`, and both have output targets. |
| 6 | Failed refreshes fail closed, retain the active output, and mark the edition blocked. | ✓ VERIFIED | Focused refresh tests pass; the public integration suite’s offline main test verifies blocked `competition_editions.csv`, `blocked_refresh.json`, append-only history, retained accepted output, and loader success. |
| 7 | Lifecycle transitions are forward-only, blocked recovery is explicit, and EURO remains truthful pre-draw. | ✓ VERIFIED | Registry/refresh suites pass; public success produces EURO `pre_draw`, with empty fixtures/groups/standings/results and explicit status. The adapter rejects non-empty pre-draw raw structure payloads at `scripts/acquire_uefa_snapshot.R:2024-2029`. |
| 8 | Production loaders connect accepted snapshot tables and identity provenance to the registry contract. | ✓ VERIFIED | Independent default public acquisition and integration checks produce all 14 targets and load both editions; hash/manifest/registry suites pass tamper and lineage checks. |

**Score:** 7/8 truths verified; 1 truth is present and code-wired but requires live external capture evidence.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/competition/source_contracts.R` | Five-class structured-resource, provenance, fallback, and hash contracts | ✓ VERIFIED | Substantive and exercised by the focused source suite. |
| `R/competition/team_identity.R` | Stable identity resolver and normalized schemas | ✓ VERIFIED | Used by public normalized staging; stable IDs and preserved source display values are asserted. |
| `R/competition/edition_registry.R` | Edition lifecycle, release, source-bundle, output, blocked, and loader contracts | ✓ VERIFIED | Current two-edition registry loads and validates. |
| `R/competition/publication_hashes.R` and `R/competition/publication_manifests.R` | Canonical and derived hash-graph refresh | ✓ VERIFIED | Focused hash and manifest suites pass. |
| `R/competition/publication_transaction.R` | Locked fourteen-target snapshot, promotion, and rollback envelope | ✓ VERIFIED | `phase13_normalized_publication_targets()` defines 14 targets; promotion snapshots/backs up/restores every target (`:83-96`, `:264-295`, `:346-405`). |
| `scripts/acquire_uefa_snapshot.R` | Capture, raw handoffs, public dual-edition transaction, blocked handling | ✓ VERIFIED | Public refresh builds transient handoffs from candidate/raw JSON and invokes the injected/default publisher callback (`:1945-2129`, `:2979-3109`). |
| `tests/testthat/test_phase13_publication_integration.R` | Public success, source boundary, hash/loader, rollback, and main blocked regressions | ✓ VERIFIED | Focused integration suite passes. |
| `data/competition/accepted/` and `data/competition/registries/` | Durable accepted graph and registries for both editions | ✓ VERIFIED | Current inspection: 12 accepted files, 2 editions, 10 artifacts, 2 bundles; no tracked `local_raw` files. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Candidate structured resources | Nations League source-shaped handoff | `phase13_acquire_publication_candidate_handoff()` | ✓ WIRED | Builds typed five-class tables from validated in-memory candidate resources, preserving artifact lineage. |
| Registry-linked raw JSON | Companion edition source-shaped handoff | `phase13_acquire_source_handoff_from_raw_store()` | ✓ WIRED | Resolves trusted relative paths, verifies exact bytes and SHA-256, parses JSON, and builds typed tables; no accepted normalized CSV read is used. |
| Two source-shaped handoffs | Transient handoff root | `phase13_acquire_build_source_handoff_set()` | ✓ WIRED | Writes both edition manifests/tables and merged source registries, then validates exactly 10 artifacts/2 bundles. |
| Public refresh | Normalized transaction | `publish_normalized_fn` defaulting to `phase13_publish_normalized_editions()` | ✓ WIRED | Independent default `phase13_acquire_publish_refresh()` run passed; integration callback counted exactly one transaction invocation. |
| Source handoffs | Stable normalized accepted tables | `phase13_acquire_publication_stage_normalized_edition()` | ✓ WIRED | Both editions run fixture/result normalizers; groups/standings/status remain staged with source provenance. |
| Staged tables | Canonical/derived hash graph | Plan 13-11 refresh helpers | ✓ WIRED | Hash and manifest suites pass; graph validation runs before promotion. |
| Complete graph | Durable publication | `phase13_with_publication_lock()` → `phase13_promote_publication_targets()` | ✓ WIRED | Exactly 14 targets are promoted under lock; all 14 injected failure points restore bytes and hashes. |
| Transaction failure | Main blocked-refresh handler | `phase13_acquire_main()` error handler | ✓ WIRED | Offline main regression creates blocked edition metadata/sidecar/history and leaves accepted output and refresh-batch marker unchanged. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| Nations League handoff | `candidate_handoff$tables` | Validated fixture candidate resources | Yes | ✓ FLOWING |
| EURO handoff | `companion_handoff$tables` | Five registry-linked raw JSON files; pre-draw structural arrays must be empty | Yes, intentionally empty for four classes | ✓ FLOWING |
| Normalized fixtures/results | `normalized_fixtures`, `normalized_results` | Both source-shaped handoffs plus identity registry | Yes; stable IDs, source names, edition IDs, and lineage | ✓ FLOWING |
| Hash/manifest graph | Canonical and derived hashes | Staged normalized CSV bytes and source registries | Yes; loader-valid refreshed graph | ✓ FLOWING |
| Durable publication | 14 target files | Locked staging/promotion transaction | Yes; all targets present after default main run | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Public success from raw/source-shaped handoffs | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_integration.R")'` | Passed; source boundary, success, loader/hash, pre-draw, rollback, and main-blocked cases all passed | ✓ PASS |
| Default `phase13_acquire_publish_refresh()` success | Isolated `Rscript --vanilla -e` sandbox check | `DEFAULT_PUBLIC_OK targets=14 editions=2` | ✓ PASS |
| Default `phase13_acquire_main()` success | Isolated `Rscript --vanilla -e` sandbox check | `MAIN_DEFAULT_OK targets=14` | ✓ PASS |
| Source contracts and capture | `test_phase13_source_contracts.R` | Passed with no failures, warnings, or skips | ✓ PASS |
| Identity, registry, loader, and pre-draw contracts | `test_phase13_competition_registry.R` | Passed with no failures, warnings, or skips | ✓ PASS |
| Canonical hashes and manifests | `test_phase13_publication_hashes.R`; `test_phase13_publication_manifests.R` | Both passed with no failures, warnings, or skips | ✓ PASS |
| Fourteen-target transaction rollback | `test_phase13_publication_transaction.R` | Passed with no failures, warnings, or skips | ✓ PASS |
| Blocked refresh and explicit recovery | `test_phase13_refresh_failure.R` | Passed with no failures, warnings, or skips | ✓ PASS |

The unrelated full repository benchmark suite was not run.

## Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probes were found. Probe execution was skipped.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DATA-01 | 13-01, 13-02, 13-07, 13-09, 13-10, 13-12, 13-13 | Capture official UEFA fixtures, groups, standings, results, and status snapshots | ? NEEDS HUMAN | Five-class fixture replay and public raw-handoff path pass; live official UEFA HTTPS capture remains external. |
| DATA-02 | 13-01, 13-02, 13-05, 13-07, 13-09, 13-10, 13-11, 13-12, 13-13 | Preserve URL, retrieval time, raw-byte hash, parser identity, fallback, and canonical/derived provenance | ✓ SATISFIED | Current 10-artifact graph, raw/hash checks, focused suites, and ignored raw-store check pass. |
| DATA-03 | 13-01, 13-03, 13-04, 13-05, 13-08, 13-11, 13-12, 13-13 | Normalize stable team/edition IDs while preserving source names and historical identity | ✓ SATISFIED | Default public route normalizes both handoffs; loader and identity stability checks pass. |
| DATA-04 | 13-01, 13-02, 13-06, 13-07, 13-09, 13-10, 13-11, 13-12, 13-13 | Support visible, reviewed, edition-wide fallback without mixed provenance | ✓ SATISFIED | Source/refresh tests pass; failure path retains output and writes blocked evidence. Operator review remains human. |
| COMP-01 | 13-01, 13-03, 13-05, 13-06, 13-13 | Register lifecycle, source bundle, release, output target, blocked state, and recovery | ✓ SATISFIED | Current two registry rows load and focused lifecycle/refresh/transaction checks pass. |

No Phase 13 requirement IDs are orphaned. No remaining technical gap is deferred to a later phase.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| Phase 13 implementation and focused test files | — | Unreferenced `TBD`, `FIXME`, `XXX`, placeholder, console-only, or empty implementation markers | ℹ️ NONE FOUND | Scan returned no matches. EURO empty structures are intentional truthful `pre_draw` output. |
| `scripts/acquire_uefa_snapshot.R` | 1945-2129 | Reverse adaptation from normalized accepted CSVs | ℹ️ NONE FOUND | Raw handoff reads registry-linked JSON; accepted-root validation is a source-shape guard and rejects normalized tables. |

## Human Verification Required

### 1. Official live structured replay

**Test:** Run the acquisition entrypoint with current official UEFA HTTPS JSON URLs for fixtures, groups, standings, results, and status in isolated output/registry/raw roots.

**Expected:** Both edition contracts remain coherent, exact raw/provenance metadata is recorded, normalized publication and loader validation succeed.

**Why human:** Endpoint availability and live response shape are external.

### 2. Reviewed fallback and failed-replacement operator review

**Test:** Review the isolated reviewed-fallback and invalid-replacement evidence, including approval, prior-output byte preservation, blocked sidecar/history linkage, and explicit recovery.

**Expected:** Fallback is complete and edition-wide; invalid replacement stays blocked; recovery uses a distinct batch without mutating immutable blocked evidence.

**Why human:** Operator approval and operational evidence cannot be established solely by code/tests.

## Gaps Summary

The previously failed gap is closed. The public refresh now creates the current-edition handoff from validated source resources, rehydrates the companion edition from trusted raw JSON and source registries, validates both source-shaped handoffs, and invokes the existing normalized publication transaction once. Independent default `phase13_acquire_publish_refresh()` and `phase13_acquire_main()` runs produced the complete 14-target graph and loaded both editions. Focused rollback tests cover every promotion index, and the main error path preserves accepted output while recording blocked-refresh state. No implementation gap remains; the only outstanding items are the two human/operational checks above.

---

_Verified: 2026-08-16T12:00:56Z_
_Verifier: the agent (gsd-verifier)_
