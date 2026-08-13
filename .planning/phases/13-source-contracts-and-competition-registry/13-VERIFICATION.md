---
phase: 13-source-contracts-and-competition-registry
verified: 2026-08-13T21:31:32Z
status: gaps_found
score: 4/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Accepted fixture records resolve source teams to stable xGelo team IDs while retaining UEFA display names and edition IDs."
    status: failed
    reason: "The normalizer exists and its focused unit test passes, but acquisition publishes only source-shaped fixtures.csv; no production capture path calls phase13_normalize_fixture_rows and no normalized accepted table is committed."
    artifacts:
      - path: "scripts/acquire_uefa_snapshot.R"
        issue: "phase13_acquire_write_resource_table() writes phase13_source_resource_table() output and never invokes the identity resolver."
      - path: "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"
        issue: "The committed schema has UEFA source team IDs and display names but no home_team_id or away_team_id."
    missing:
      - "Wire accepted fixture publication through the stable identity resolver."
      - "Publish and validate a normalized fixture artifact, or provide an equivalent production loader that materializes it before downstream consumption."
  - truth: "A failed refresh marks the edition blocked while retaining the last accepted output."
    status: failed
    reason: "The capture script preserves the accepted manifest and writes blocked_refresh.json, but it does not update competition_editions.csv or any edition registry row to blocked."
    artifacts:
      - path: "scripts/acquire_uefa_snapshot.R"
        issue: "The error path calls phase13_acquire_write_blocked_metadata() only; the success path updates source registries only."
      - path: "data/competition/registries/competition_editions.csv"
        issue: "The Nations League row remains blocked=FALSE after a failed candidate simulation."
    missing:
      - "Persist the blocked overlay, failure reason/timestamp, and last accepted output in the edition registry through the refresh failure path."
      - "Validate the updated edition registry before exposing the blocked state."
  - truth: "Production loaders enforce the accepted-snapshot and team-identity provenance links."
    status: partial
    reason: "The edition loader validates source bundle CSVs and the Phase 12 release pin, but it never reads accepted/<edition_id> resource tables; the team identity loader validates source_bundle_id only when callers explicitly pass source_bundles."
    artifacts:
      - path: "R/competition/edition_registry.R"
        issue: "load_competition_edition_registries() loads competition_editions.csv, source_bundles.csv, and source_artifacts.csv only."
      - path: "R/competition/team_identity.R"
        issue: "load_phase13_team_identity_registry() calls validation without the source bundle registry."
    missing:
      - "Add a production accepted-snapshot loader/validator and wire identity provenance validation into the normal load path."
---

# Phase 13: Source Contracts and Competition Registry Verification Report

**Phase Goal:** Analysts can capture authoritative UEFA competition snapshots and register both competition editions under one auditable contract.

**Verified:** 2026-08-13T21:31:32Z

**Status:** gaps_found

**Re-verification:** No — initial verification.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | An analyst can capture official five-class UEFA snapshots for both editions. | ? UNCERTAIN | The bounded script requires five explicit HTTPS JSON URLs and deterministic fixture replay passes. No live official-URL capture was run, and EURO's committed pre-draw bundle intentionally contains empty resource tables. |
| 2 | Accepted snapshots expose URL, retrieval time, raw-byte hash, Git parser identity, fallback status, and stable hashes while raw bytes remain ignored. | ✓ VERIFIED | Source tests pass; committed artifact registries contain the required fields; an independent check verified all 10 local raw files against their recorded byte counts and SHA-256 values; `git ls-files data/competition/local_raw` is empty. |
| 3 | Reviewed manual fallback is complete, visible, edition-wide, and cannot mix with official artifacts. | ✓ VERIFIED | Focused source tests pass; fixture-backed CLI fallback acceptance produces `reviewed_fallback`, `reviewed`, approved artifact states, source/reason/operator/checksum metadata, and mixed-status rejection. |
| 4 | Normalized records retain UEFA names while resolving to stable team and edition IDs in the accepted production path. | ✗ FAILED | `phase13_normalize_fixture_rows()` resolves IDs and preserves names in unit tests, but the acquisition path writes source-shaped fixtures only. The committed fixture header has no `home_team_id` or `away_team_id`; the independent expected-schema check failed. |
| 5 | Both edition registry rows contain lifecycle, source bundle, approved model release, and output target. | ✓ VERIFIED | `load_competition_edition_registries()` and `validate_competition_edition_registries()` pass against committed CSVs; both required IDs are present and the Phase 12 release preflight resolves `phase12-wc2026-incumbent-retained-v1`. |
| 6 | Failed refreshes fail closed, retain the active output, and mark the edition blocked. | ✗ FAILED | The focused failure test proves the prior manifest is retained and `blocked_refresh.json` is written. An independent temporary-copy check showed `competition_editions.csv` is unchanged, so the edition-level blocked overlay is not wired. |
| 7 | Lifecycle transitions are forward-only, blocked recovery is explicit, and EURO remains truthful pre-draw. | ✓ VERIFIED | Registry tests pass for adjacent transitions, blocked recovery requiring operator action and validation, order-stable hashes, and EURO `pre_draw`; committed EURO tables are schema-valid empty tables with no fabricated structures. |
| 8 | Production loaders connect accepted snapshot tables and identity provenance to the registry contract. | ✗ FAILED | The edition loader succeeds even when pointed at a temporary registry copy with no accepted snapshot directories. The identity loader accepts a recomputed row with a forged `source_bundle_id` when `source_bundles` is not supplied. |

**Score:** 4/8 merged contract truths verified. One truth is uncertain pending live source validation; three truths are failed due production wiring gaps.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/competition/source_contracts.R` | Structured resource, provenance, hash, fallback, and bundle validators | ✓ VERIFIED | 806 lines; exercised by 63 passing source-contract assertions and by the acquisition script. |
| `scripts/acquire_uefa_snapshot.R` | Bounded fixture/live capture and fail-closed publication | ⚠️ PARTIAL | 414 lines; fixture replay, raw retention, accepted promotion, and fallback checks work, but identity normalization and edition-registry blocked updates are not wired. |
| `R/competition/team_identity.R` | Stable IDs, visible fallback, normalized fixture output, and registry validation | ⚠️ PARTIAL | 345 lines; direct-ID/fallback/ambiguity behavior passes, but the production capture path does not consume the normalized output and the default loader omits source-bundle FK validation. |
| `R/competition/edition_registry.R` | Lifecycle, blocked overlay, source-bundle and Phase 12 release validation | ✓ VERIFIED | 499 lines; committed registry load and focused lifecycle/release tests pass. The capture script does not call its blocked-overlay mutation on failure. |
| `data/competition/registries/source_bundles.csv` and `source_artifacts.csv` | Compact accepted provenance registries | ✓ VERIFIED | Both committed registries load and validate; all five resource classes appear per accepted bundle. |
| `data/competition/registries/team_identity.csv` | Stable identity registry with aliases, warning metadata, provenance, and row hashes | ⚠️ PARTIAL | File validates and contains stable NL mappings; its source-bundle link is not checked by the default production loader. |
| `data/competition/registries/competition_editions.csv` | Both durable edition rows and explicit pre-draw EURO state | ✓ VERIFIED | Both rows validate with non-null source/model/output slots; EURO is `pre_draw` with draw date `2026-12-06`. |
| `data/competition/accepted/{uefa_nations_league_2026_27,uefa_euro_2028_qualifying}/` | Compact accepted snapshot tables and manifest | ⚠️ HOLLOW | All five tables and manifests exist and row hashes pass, but fixtures are source-shaped and no production loader validates or materializes stable team IDs. |
| `tests/testthat/test_phase13_source_contracts.R` and `test_phase13_competition_registry.R` | Focused contract and edge tests | ✓ VERIFIED | 63 and 51 assertions pass respectively, with no failures, warnings, or skips. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Structured fixture/live payload | Source artifact and bundle registries | `phase13_capture_structured_bundle()` and acquisition script | ✓ WIRED | Five resource classes, provenance, hashes, fallback status, and bundle manifests are produced and validated. |
| Candidate bundle | Accepted edition directory | `phase13_acquire_publish_accepted()` | ✓ WIRED | Candidate output is staged and promoted only after bundle validation; prior output is retained on promotion failure. |
| Failed candidate | Edition blocked overlay | `phase13_acquire_main()` error path | ✗ NOT WIRED | Error handling writes only `blocked_refresh.json`; it does not update `competition_editions.csv`. |
| Accepted source fixture | Stable team identity | `phase13_normalize_fixture_rows()` | ⚠️ PARTIAL | Function-to-function behavior is tested, but no acquisition/publish call or accepted normalized artifact connects the two. |
| Edition registry | Accepted source bundle and approved Phase 12 release | `load_competition_edition_registries()` | ✓ WIRED | Foreign-key and trusted release preflight pass against committed registries. |
| Team identity registry | Accepted source bundle registry | Optional `source_bundles` argument | ⚠️ PARTIAL | Validator supports the link, but `load_phase13_team_identity_registry()` does not supply the source bundle registry. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `scripts/acquire_uefa_snapshot.R` | `candidate$resources` | Fixture replay or explicit HTTPS JSON capture | Yes for fixture replay; live path not exercised | ⚠️ LIVE UNVERIFIED |
| `source_artifacts.csv` / `source_bundles.csv` | Raw/provenance metadata | Exact raw bytes and bundle validation | Yes; 10/10 committed raw files match recorded hashes | ✓ FLOWING |
| Accepted `fixtures.csv` | Fixture rows | `phase13_source_resource_table()` | Yes, but source-shaped only | ⚠️ DISCONNECTED FROM IDENTITY |
| `team_identity.csv` | Stable team mappings | Committed identity registry and resolver | Yes | ⚠️ PARTIAL — no default source-bundle FK check |
| `competition_editions.csv` | Edition lifecycle/release slots | Committed registry plus trusted Phase 12 release root | Yes | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Source contracts and fallback/schema edges | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | 63 assertions, 0 failures/warnings/skips | ✓ PASS |
| Identity, lifecycle, pre-draw, and release-pin edges | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | 51 assertions, 0 failures/warnings/skips | ✓ PASS |
| Fixture-backed bounded capture | `Rscript --vanilla scripts/acquire_uefa_snapshot.R ... --dry-run` | Candidate `nl-2026-27-official-sample-v1` valid | ✓ PASS |
| Production edition registry loading | `source("R/competition/edition_registry.R"); load_competition_edition_registries(...)` | Both editions loaded and validated | ✓ PASS |
| Committed raw-byte integrity | Independent R check over `source_artifacts.csv` and ignored raw files | 10/10 byte counts and SHA-256 values match | ✓ PASS |
| Accepted-table row integrity | Independent R check over both accepted edition directories | All five tables per edition have matching row hashes and edition IDs | ✓ PASS |
| Accepted fixture stable-ID contract | Independent R check requiring `home_team_id` and `away_team_id` in committed fixtures | Check failed: both columns absent | ✗ FAIL |
| Failed-refresh edition state | Temporary-copy failure run | Accepted manifest preserved and blocked sidecar written, but `competition_editions.csv` unchanged | ✗ FAIL |

## Probe Execution

No phase-declared or conventional `scripts/*/tests/probe-*.sh` probes were found. Probe execution skipped.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| DATA-01 | 13-01, 13-02 | Capture official UEFA fixtures, groups, standings, results, and status snapshots | ? NEEDS HUMAN | Fixture-backed five-class capture and structured-only rejection pass; live official endpoint capture remains untested. |
| DATA-02 | 13-01, 13-02 | Record URL, retrieval time, raw-byte hash, parser identity, and fallback status | ✓ SATISFIED | Committed artifact/bundle metadata validates; independent raw-byte check passes 10/10. Git SHA is the locked parser identity. |
| DATA-03 | 13-01, 13-03 | Normalize records to stable team/edition IDs while preserving source names | ✗ BLOCKED | Resolver and unit tests pass, but accepted production fixtures are not normalized or consumed by a loader. |
| DATA-04 | 13-01, 13-02 | Support visible audited manual fallback snapshots | ✓ SATISFIED | Reviewed fallback metadata, approved artifact states, checksum, and mixed-provenance rejection pass focused tests and fixture replay. |
| COMP-01 | 13-01, 13-03 | Register lifecycle, ruleset, source bundle, model release, and output bundle | ✓ SATISFIED with refresh-risk | Both rows and trusted release pins validate; the refresh failure path still does not persist the blocked overlay. |

No Phase 13 requirement IDs are orphaned: all five roadmap IDs are claimed by the plans. Later roadmap phases do not clearly cover the missing Phase 13 identity-publication and edition-registry failure-path wiring, so no gaps are deferred.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `scripts/acquire_uefa_snapshot.R` | 279-300 | Accepted publication emits source-shaped tables only; identity normalizer is unused | 🛑 BLOCKER | Stable team IDs are not present in the accepted production records. |
| `scripts/acquire_uefa_snapshot.R` | 396-406 | Failure path writes a sidecar but does not update edition registry state | 🛑 BLOCKER | D-16's edition-level blocked overlay is not durable. |
| `R/competition/edition_registry.R` | 451-490 | Registry loader does not inspect accepted snapshot directories | ⚠️ WARNING | Tampered/missing accepted CSVs can remain outside the production validation path. |
| `R/competition/team_identity.R` | 265-270 | Default identity loader omits `source_bundles` provenance input | ⚠️ WARNING | A recomputed row hash can preserve a forged source-bundle reference through the default loader. |
| `data/competition/accepted/uefa_euro_2028_qualifying/*.csv` | — | Intentional zero-row pre-draw resource tables | ℹ️ INFO | Schema-valid and consistent with the no-fabrication pre-draw contract; not classified as stubs. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in Phase 13 implementation, tests, or committed data artifacts.

## Human Verification Required

### 1. Live official structured capture

**Test:** Supply one real official HTTPS structured URL for each of fixtures, groups, standings, results, and status to `scripts/acquire_uefa_snapshot.R` for the Nations League edition; inspect the captured manifest and accepted output.

**Expected:** Each response is structured JSON, all five classes validate together, URLs/retrieval time/raw hashes/Git parser SHA/fallback status are visible, and no rendered HTML/PDF is accepted. Repeat for EURO only when official post-draw resources exist; before then, confirm the explicit pre-draw path remains empty and truthful.

**Why human:** This depends on current UEFA endpoint availability and response shape; the automated checks use committed compact fixtures and do not exercise the external service.

### 2. Reviewed fallback operator workflow

**Test:** Run the capture entrypoint with a real reviewed fallback bundle and inspect the published metadata and failure/recovery behavior.

**Expected:** The fallback is an edition-wide reviewed bundle with visible source, date, reason, operator note, checksum, and approved review state; an invalid replacement leaves the previously accepted output active and exposes the blocked state to the operator.

**Why human:** The manual review decision and operational source evidence cannot be established from repository contents alone.

## Gaps Summary

The phase has strong source-contract and registry primitives: the focused suites pass, compact registries and accepted snapshots are committed, exact local raw bytes are ignored and hash-verified, fallback mixing is rejected, and both edition rows are release-pinned and validated. The goal is not achieved because the production capture path stops at source-shaped fixtures instead of publishing stable team IDs, and refresh failures stop at a sidecar instead of updating the durable edition blocked overlay. The production loaders also do not validate accepted snapshot directories or identity-to-source-bundle foreign keys by default.

## Next Action

Address the three structured gaps before advancing to Phase 14: wire identity normalization into accepted publication, persist/validate the edition blocked overlay on capture failure, and make production loaders validate accepted snapshot and identity provenance links. Then rerun the focused tests, add regression coverage for these links, and complete the live official-source human check.

---

_Verified: 2026-08-13T21:31:32Z_  
_Verifier: the agent (gsd-verifier)_
