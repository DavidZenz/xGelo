---
phase: 18-club-and-ucl-source-contracts
reviewed: 2026-09-20T15:25:42Z
fixed: 2026-09-20T16:55:00Z
depth: deep
files_reviewed: 55
files_reviewed_list:
  - .gitignore
  - R/common/phase18_canonical_hash.R
  - R/club/history_contract.R
  - R/club/identity.R
  - R/club/identity_bootstrap.R
  - R/competition/edition_registry.R
  - R/competition/football_data_org_adapter.R
  - R/competition/source_contracts.R
  - R/competition/ucl_source_acceptance.R
  - R/competition/ucl_source_bundle.R
  - R/competition/ucl_source_refresh.R
  - scripts/accept_ucl_provider.R
  - scripts/bootstrap_club_identity.R
  - scripts/build_club_history_corpus.R
  - scripts/refresh_ucl_source.R
  - scripts/verify_phase18_contracts.R
  - tests/testthat/test_phase18_adversarial_regression.R
  - tests/testthat/test_phase18_canonical_hash.R
  - tests/testthat/test_phase18_club_history_contract.R
  - tests/testthat/test_phase18_club_identity.R
  - tests/testthat/test_phase18_football_data_adapter.R
  - tests/testthat/test_phase18_refresh_failure.R
  - tests/testthat/test_phase18_source_acceptance.R
  - tests/testthat/test_phase18_source_bundle.R
  - tests/fixtures/phase18/football_data_org/empty_teams.json
  - tests/fixtures/phase18/football_data_org/incomplete_page.json
  - tests/fixtures/phase18/football_data_org/null_resource.json
  - tests/fixtures/phase18/football_data_org/unknown_match_enum.json
  - tests/fixtures/phase18/openfootball/score_cases.csv
  - tests/fixtures/phase18/provider_terms_review.csv
  - data/club/history_current.json
  - data/club/history_sources.csv
  - data/club/identity_reviews/current_ucl_tokens.csv
  - data/club/identity_reviews/historical_inventory_tokens.csv
  - data/club/identity_reviews/unresolved_club_tokens.csv
  - data/club/registries/club_aliases.csv
  - data/club/registries/club_source_ids.csv
  - data/club/registries/clubs.csv
  - data/competition/manual_source_reviews/ucl_2026_27.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/current.json
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/ACCEPTANCE.md
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/acceptance_manifest.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/coverage_matrix.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/edition_expectations.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/provider_terms_review.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd/schema_fingerprint.csv
  - data/competition/registries/ucl_source_blocked_refresh.json
  - data/competition/registries/ucl_source_current.json
  - data/competition/registries/ucl_source_refreshes.csv
  - data/competition/ucl_source_generations/transactions/ucl-refresh-20260920-disabled-missing-credential-v2/state.json
  - data/competition/ucl_source_generations/transactions/ucl-refresh-20260920-disabled-missing-credential-v2/ucl_source_blocked_refresh.json
  - data/competition/ucl_source_generations/transactions/ucl-refresh-20260920-disabled-missing-credential-v2/ucl_source_refreshes.csv
  - data/club/history_generations/club-history-2026-01-bfeaf7666c8b2bc657d3/generation_manifest.csv
  - data/club/history_generations/club-history-2026-01-bfeaf7666c8b2bc657d3/audit/corpus_manifest.csv
  - data/club/history_generations/club-history-2026-01-bfeaf7666c8b2bc657d3/audit/matches.csv
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
resolved_findings:
  critical: 6
  warning: 4
  total: 10
status: clean
---

# Phase 18: Code Review Report

**Reviewed:** 2026-09-20T15:25:42Z
**Depth:** deep
**Files Reviewed:** 55
**Status:** clean

## Summary

All six blockers and four warnings from this final cross-module review are resolved. The authoritative runner now succeeds with `PHASE18_GATE_OK` across 8 files, 142 tests, and 840 assertions. Production evidence remains deliberately fail-closed: provider authority is `missing_credential`, UCL refresh is `no_incumbent`, and club history is `blocked` with no accepted generation.

## Verification Performed

- `Rscript --vanilla scripts/verify_phase18_contracts.R` — **PASS**: 8 test files, 142 tests, 840 assertions, 15 original critical probes, 4 original warning probes, 15 edge probes, 50 prohibitions, production fail-closed.
- `git diff --check` — **PASS**.
- Production readers — **PASS**: provider automation disabled (`missing_credential`), UCL has no incumbent, history remains training-ineligible.
- Direct adversarial reproductions — **PASS**: typed/cardinality schema drift, blank/foreign authority, unchanged adapter-to-bundle integration, malformed provider-exit metadata, post-commit faults, registry publication boundaries, retryable exceptions, and delimiter-collision tuples are all covered by focused regressions.

## Final Finding Disposition

| Finding | Disposition | Closing evidence |
|---|---|---|
| CR-NEW-01 | CLOSED | Typed full-tree JSON fingerprints bind scalar/container types, array cardinality, and every element. |
| CR-NEW-02 | CLOSED | Trusted provider/application scope and nonblank reviewer authority are enforced and rebound in manifests. |
| CR-NEW-03 | CLOSED | Adapter output is the canonical eight-column fingerprint table and enters bundle validation unchanged. |
| CR-NEW-04 | CLOSED | Club registries publish as immutable generations selected by one self-hashed atomic pointer. |
| CR-NEW-05 | CLOSED | Pointer replacement is the linearization point; post-commit hooks are nonfatal notifications. |
| CR-NEW-06 | CLOSED | Exit reviews enforce exact schema, strict metadata/booleans/time, and incumbent terms authority. |
| WR-NEW-01 | CLOSED | Human authority validation rejects placeholder, invalid, and future manual reviews. |
| WR-NEW-02 | CLOSED | Legacy definitions are explicitly named and a static test enforces one runtime definition per symbol. |
| WR-NEW-03 | CLOSED | Trusted transient transport errors retain retry markers, accounting, and bounded backoff. |
| WR-NEW-04 | CLOSED | Club overlap groups use canonical collision-safe tuple hashes. |

## Prior Finding Disposition

| Prior finding | Disposition | Closing evidence |
|---|---|---|
| CR-01 delimiter-ambiguous hashes | CLOSED | Canonical-v2 length framing and collision regression tests. |
| CR-02 review loader re-hashed/selects fixtures | CLOSED | Durable hashes are validated and multi-set durable reviews are rejected. |
| CR-03 default expectations authoritative | CLOSED | Exact v2 approved review metadata is required. |
| CR-04 incomplete/hard-coded matrix | CLOSED | Exact 16-capability matrix and observed-evidence checks. |
| CR-05 fingerprint table not revalidated | CLOSED | Table rows and aggregate are recomputed from durable evidence. |
| CR-06 authority not edition/raw scoped | CLOSED | Edition and canonical raw aggregate are bound for every authority mode. |
| CR-07 normalized-before-symlink check | CLOSED | Original lexical components are checked before resolution. |
| CR-08 split acceptance/refresh publication | CLOSED | Immutable generations plus one hash-bound current pointer. |
| CR-09 lock loser mutates evidence | CLOSED | Lock collision returns non-durable with no shared mutation. |
| CR-10 tampered history extended | CLOSED | Current pointer, transaction, ledger, sidecar, and accepted reference are prevalidated. |
| CR-11 exit review unrelated to incumbent | CLOSED | Provider/edition/decision/bundle/inventory are bound to the validated incumbent. |
| CR-12 pre-completion history leakage | CLOSED | Conservative completion floor and strict cutoff are recomputed. |
| CR-13 one-resource freshness | CLOSED | Per-resource freshness evidence is required and aggregated. |
| CR-14 stored history claims trusted | CLOSED | Full corpus audits are independently recomputed and compared. |
| CR-15 edition path traversal | CLOSED | CLI accepts only the fixed edition and verifies trusted-root containment. |
| WR-01 inactive/invalid club state | CLOSED | Closed status enum, club intervals, and active-at-event resolution. |
| WR-02 hidden/surplus inventory | CLOSED | Recursive `all.files=TRUE` exact inventories. |
| WR-03 successful CLI exits as failure | CLOSED | Tagged result union and mode-specific subprocess exit tests. |
| WR-04 split history publication | CLOSED | Audit and accepted state share one immutable generation/pointer transaction. |

## Historical Narrative Findings (resolved)

## Critical Issues

### CR-NEW-01: Schema fingerprints do not fingerprint schema types or cardinality

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:274-285`

**Issue:** `phase18_fd_fingerprint()` records only dotted JSON paths, descends through only the first array element, and records neither scalar/container types nor array cardinality. Distinct payloads such as `id="1", x=1L` and `id=1L, x="1"` produce the same digest; fields present only in later array elements are also invisible. This does not satisfy the Plan 18-06 JSON-path/type/cardinality contract and lets provider schema drift retain accepted authority.

**Fix:** Canonically traverse every object and array, recording path, node type, scalar type, and deterministic array cardinality/element-shape information. Hash that typed representation with canonical-v2 and add regressions for scalar type changes, empty/nonempty arrays, count changes, and fields appearing after element one.

### CR-NEW-02: Owner terms approval accepts an empty reviewer and unrelated provider/application scope

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:1167-1204`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:1502-1557`

**Issue:** The validator rejects several named placeholders but not the empty string, and it checks only that `provider_id` and `application_id` are internally constant. A self-hashed review with `reviewer=""` is accepted, as is a review scoped to `other_provider/other_app`; the manifest then adopts that foreign provider ID while still enabling the fixed football-data.org automation path. This bypasses the human and provider scope authority required by UCLSRC-01.

**Fix:** Require every authority field to be nonempty, reject normalized blank/placeholder reviewers, and validate exact trusted `provider_id` and `application_id` values supplied outside the review artifact. Recheck those fixed values in manifest and bundle authority validation.

### CR-NEW-03: The real adapter output cannot be consumed by the bundle builder

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:559-563`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:541-549`; `/Users/davidzenz/R/xGelo/tests/testthat/test_phase18_source_bundle.R:129-133`

**Issue:** `phase18_fd_project_resources()` returns a three-column fingerprint table (`resource`, `fingerprint_sha256`, `raw_sha256`), but `phase18_build_ucl_source_bundle()` passes it to `phase18_validate_schema_fingerprint()`, which requires the exact eight-column acceptance schema. Therefore the default `provider_live` flow in `scripts/accept_ucl_provider.R:329-343` always stops at bundle construction. Bundle tests conceal the mismatch by substituting the acceptance fixture's fingerprint table instead of the adapter output.

**Fix:** Make the adapter emit the canonical acceptance fingerprint table, or add one explicit conversion that supplies endpoint, observed flag/time, schema/hash versions, and row hashes while keeping raw hashes in a separate artifact. Add a true adapter -> bundle -> candidate integration test using `phase18_fd_project_resources()` output unchanged.

### CR-NEW-04: The three club identity registries are not published atomically

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/club/identity_bootstrap.R:448-483`

**Issue:** `phase18_write_club_registries_atomic()` replaces `clubs.csv`, `club_source_ids.csv`, and `club_aliases.csv` sequentially in the reader-visible directory. Its rollback runs only for caught R errors; concurrent readers and a killed process can observe or permanently retain a mixed registry generation. CLUBID-01 and Plan 18-02 require these tables to update as one identity authority.

**Fix:** Write and validate all three files under an immutable generation directory, then atomically replace one self-hashed current pointer (or one complete directory). Readers must capture and validate one generation reference. Add subprocess-kill tests at each file boundary and concurrent-reader tests proving only complete old/new registry sets are visible.

### CR-NEW-05: Refresh can report failure after its accepted pointer has already committed

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:408-430`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:570-577`

**Issue:** Normal refresh commits the current pointer at line 419 and then executes the fallible `after_pointer_commit` hook. A hook error is classified as `promotion_failure` and returned as `status="blocked", recorded=FALSE`, although the accepted generation is already current. Provider withdrawal has the same ordering: it commits at line 574, then lets `after_provider_exit_swap` fail outward. The durable state and reported/CLI result can therefore contradict each other, encouraging unsafe retries and violating Plan 18-11's explicit rule that modes never error after a completed mutation.

**Fix:** Treat pointer replacement as the transaction linearization point. Run fallible validation/hooks before it, or make post-commit hooks non-authoritative and catch their failures. After commit, reread the pointer and always return a committed result (with a separate non-fatal notification warning if needed). Add both post-commit fault-injection cases.

### CR-NEW-06: Provider-exit approval accepts malformed or absent compliance evidence

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:441-465`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:511-575`

**Issue:** Exit-review validation checks schema version, decision/disposition, and self-hashes only. It accepts blank reviewer, reason, and terms hash; an invalid review timestamp; arbitrary boolean text; and surplus columns. The later apply path checks exact incumbent identifiers/inventory but never validates those approval fields for withdrawal. Copying the incumbent bindings into a self-hashed malformed row is therefore enough to authorize destructive provider exit without auditable owner/terms authority.

**Fix:** Require the exact ordered schema, nonempty non-placeholder reviewer/reason, strict UTC review time, valid current terms SHA-256, and strict booleans for both dispositions. Bind the terms artifact/version to the incumbent provider decision and add malformed-metadata retain/withdraw tests before any staging.

## Warnings

### WR-NEW-01: Manual source review accepts invalid review timestamps and fixture placeholder reviewers

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:311-350`

**Issue:** Manual authority validates hashes, edition, and raw bytes, but treats `reviewed_at_utc` as an arbitrary nonempty scalar and accepts `fixture-reviewer` as production review identity. Malformed or unmistakably fixture audit metadata can be promoted as `manual_reviewed` authority.

**Fix:** Parse strict UTC, reject future/invalid times and the shared placeholder vocabulary, and add a production-safe reviewer/review-state validator used by all human authority types.

### WR-NEW-02: Acceptance keeps hundreds of lines of shadowed legacy runtime definitions

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:275-1097`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:1098-1759`

**Issue:** Public functions including `phase18_build_acceptance_manifest`, `phase18_build_live_probe_evidence`, `phase18_run_live_acceptance_probe`, and multiple validators are defined more than once; later definitions silently replace earlier ones. Phase 18 already needed a gap fix for shadowing, and future edits/tests can target a dead definition while runtime uses another.

**Fix:** Delete the legacy executable definitions or move them into an explicitly versioned migration module with different names. Add a static check that each exported Phase 18 function has exactly one runtime definition.

### WR-NEW-03: Retryable transport exceptions lose their retry marker

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:25-45`; `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:177-201`

**Issue:** `phase18_fd_with_closed_errors()` replaces transport exceptions with a sanitized condition but does not preserve a `retryable` attribute. The fetch loop consequently aborts on the first thrown timeout/connection failure and retries only returned retryable HTTP responses. This is fail-closed, but it defeats the declared bounded retry policy for common transient transport failures.

**Fix:** Classify known transient transport conditions with a trusted retryable flag (without leaking raw messages), preserve attempt accounting, back off, and add a performer that throws twice before succeeding.

### WR-NEW-04: Club overlap grouping reintroduces delimiter collisions outside the canonical hash layer

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/club/identity.R:143-159`

**Issue:** Multi-column identity groups are built with `paste(..., sep="\x1f")`. Since source strings are not forbidden from containing that control byte, distinct `(source_system, source_club_id)` or alias tuples can collapse into one group and spuriously fail overlap validation. Canonical-v2 fixed stored hash framing but not this in-memory equality key.

**Fix:** Group using a collision-free tuple representation, such as canonical-v2 sequence hashes with field names/types or data-frame equality, and add a control-character collision regression.

---

_Reviewed: 2026-09-20T15:25:42Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
