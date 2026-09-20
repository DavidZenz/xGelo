---
phase: 18-club-and-ucl-source-contracts
reviewed: 2026-09-20T10:27:38Z
depth: standard
files_reviewed: 36
files_reviewed_list:
  - .gitignore
  - R/club/history_contract.R
  - R/club/identity.R
  - R/club/identity_bootstrap.R
  - R/competition/football_data_org_adapter.R
  - R/competition/ucl_source_acceptance.R
  - R/competition/ucl_source_bundle.R
  - R/competition/ucl_source_refresh.R
  - data/club/history_audits/club-history-2026-01/corpus_manifest.csv
  - data/club/history_sources.csv
  - data/club/identity_reviews/current_ucl_tokens.csv
  - data/club/identity_reviews/historical_inventory_tokens.csv
  - data/club/identity_reviews/unresolved_club_tokens.csv
  - data/club/registries/club_aliases.csv
  - data/club/registries/club_source_ids.csv
  - data/club/registries/clubs.csv
  - data/competition/manual_source_reviews/ucl_2026_27.csv
  - data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/acceptance_manifest.csv
  - data/competition/registries/ucl_source_blocked_refresh.json
  - data/competition/registries/ucl_source_refreshes.csv
  - scripts/accept_ucl_provider.R
  - scripts/bootstrap_club_identity.R
  - scripts/build_club_history_corpus.R
  - scripts/refresh_ucl_source.R
  - tests/fixtures/phase18/football_data_org/empty_teams.json
  - tests/fixtures/phase18/football_data_org/incomplete_page.json
  - tests/fixtures/phase18/football_data_org/null_resource.json
  - tests/fixtures/phase18/football_data_org/unknown_match_enum.json
  - tests/fixtures/phase18/openfootball/score_cases.csv
  - tests/fixtures/phase18/provider_terms_review.csv
  - tests/testthat/test_phase18_club_history_contract.R
  - tests/testthat/test_phase18_club_identity.R
  - tests/testthat/test_phase18_football_data_adapter.R
  - tests/testthat/test_phase18_refresh_failure.R
  - tests/testthat/test_phase18_source_acceptance.R
  - tests/testthat/test_phase18_source_bundle.R
findings:
  critical: 15
  warning: 4
  info: 0
  total: 19
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-09-20T10:27:38Z
**Depth:** standard
**Files Reviewed:** 36
**Status:** issues_found

## Summary

The six focused test files pass, but the implementation is not safe to ship. The review found 15 blockers and 4 warnings in the acceptance authority, provenance hashes, candidate filesystem boundary, refresh transaction, provider-exit flow, and historical leakage gates. Two defects were independently reproduced: delimiter injection makes distinct rows hash identically, and an in-root symlink passes `phase18_ucl_assert_no_symlink()`. A historical result whose evidence predates kickoff was also reproduced as `counts_for_model=TRUE`.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Delimiter-ambiguous hashes are not tamper-evident

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:80-85`; `/Users/davidzenz/R/xGelo/R/club/identity.R:53-60`

**Issue:** Row hashes concatenate unescaped values with `|`. Distinct records such as `("x|y", "z")` and `("x", "y|z")` therefore produce the same SHA-256. The same ambiguous framing is reused by club registries, acceptance evidence, history artifacts, and bundle manifests, so their integrity claims can be bypassed without breaking a hash. This collision was reproduced against `phase18_row_sha256()`.

**Fix:** Replace delimiter concatenation with a versioned, unambiguous encoding, such as length-prefixed UTF-8 fields including field names and types, or canonical JSON/CBOR. Recompute and migrate every persisted Phase 18 hash; add collision regression tests containing delimiters and control characters.

### CR-02: Loading an owner review silently re-hashes tampered content and prefers an approved fixture set

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:481-489`

**Issue:** `phase18_read_terms_review()` overwrites `row_sha256` via `phase18_hash_terms_review()` instead of validating the hash loaded from disk. Any change to provider, application, terms, reviewer, or disposition is silently blessed on read. When a CSV contains multiple `review_set` values, the loader also selects `approved` automatically, so a mixed fixture/pending file can authorize live automation without an explicit production selection.

**Fix:** Separate creation from loading. A loader must require the exact durable schema and validate existing row hashes without modifying them. Reject multiple review sets in production; if fixture multiplexing is needed, require an explicit fixture-only selector that cannot be used by live modes.

### CR-03: Unreviewed default edition expectations are accepted as reviewed authority

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:171-220`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:396-412`

**Issue:** Expectation validation checks cardinalities and self-generated hashes but never verifies `schema_version`, a non-placeholder reviewer, or a valid review timestamp/status. `phase18_default_edition_expectations()` labels the reviewer `pending_owner_review`, yet this row passes validation and can participate in an accepted live manifest.

**Fix:** Add an explicit review state and require the exact schema version, approved state, non-placeholder reviewer identity, valid UTC timestamp, and fixed edition before returning `valid=TRUE`. Defaults must remain non-authoritative until a separately validated owner review promotes them.

### CR-04: Live acceptance can omit most capability rows and hard-codes unobserved capabilities as passed

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:229-248`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:288-306`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:627-676`

**Issue:** Machine validation only rejects duplicate capability names. Acceptance requires four resource names, not the exact 16-row decision matrix or the reviewed `INTEGRATE`/`OPT-OUT` mapping. Worse, twelve auxiliary rows—including integrated pagination, authentication, rate-limit, attribution, and provider-exit capabilities—are emitted as passed with `logical_call_count=0` and no observation. A four-row matrix is enough to enable automation.

**Fix:** Require the capability set and decisions to be exactly `phase18_capability_decisions()`. Each integrated capability must have specific observed evidence and a nonzero check appropriate to that capability; only true opt-outs may omit execution, and they should not claim generic freshness/identity/pagination success.

### CR-05: Schema fingerprint evidence is self-referential and never validated

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:364-393`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:517-540`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:180-200`

**Issue:** Manifest validation rebuilds the manifest using the hash already stored in that manifest. Although `schema_fingerprint.csv` is loaded and required by the provider authority, its row hashes and canonical aggregate are never recomputed or compared with `schema_fingerprint_sha256`. The fingerprint file can be changed while live authority still validates.

**Fix:** Pass the actual fingerprint table into manifest validation, enforce its exact four-row schema and row hashes, recompute its canonical hash, and require equality with the manifest. Bundle authority validation must repeat this check from durable evidence.

### CR-06: Source authority is not scoped to candidate bytes or edition

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:203-233`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:323-375`

**Issue:** Manual review records contain `aggregate_raw_sha256` and `edition_id`, but bundle construction never compares either value with the fetched raw resources or candidate edition. Provider acceptance evidence is likewise not checked to be for the same edition as `edition_expectations`. A valid review for unrelated bytes or another season can authorize a promotable candidate.

**Fix:** Define one canonical aggregate over the ordered four raw hashes and require it to equal the manual review value. Require authority provider/edition identifiers to exactly match the candidate and expectations for every authority type before any artifact rows are created.

### CR-07: The symlink guard resolves the link before checking it

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:83-102`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:639-647`

**Issue:** `phase18_ucl_assert_no_symlink()` calls `normalizePath()` before walking components. An in-root symlink resolves to its target, so the later walk never encounters the link. This was reproduced with a file symlink inside the candidate root, which the function accepted. It defeats the declared symlink-free boundary and creates a validation/copy time-of-check-to-time-of-use surface.

**Fix:** Walk the original lexical path component by component with `Sys.readlink()`/`lstat` before resolving it, reject every symlink, then resolve and check containment. For sensitive reads/copies, use no-follow file opens or copy from an immutable descriptor/snapshot.

### CR-08: “Atomic” acceptance and refresh publication exposes mixed state and has crash-loss windows

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_acceptance.R:798-825`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:305-322`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:503-526`

**Issue:** Both transactions promote files one by one into a reader-visible root. Readers do not honor the writer lock, so they can observe mixed old/new acceptance evidence or an incomplete accepted bundle. The history/sidecar writers additionally unlink the incumbent before rename, leaving a data-loss window on crash. R-level rollback tests do not cover process termination or concurrent readers.

**Fix:** Publish a complete validated generation under a sibling staging directory and commit it with one directory rename or one atomic generation-pointer replacement. Never unlink the incumbent before the replacement is durable; add subprocess-kill and concurrent-reader tests.

### CR-09: A lock collision mutates the same history without holding the lock

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:464-476`

**Issue:** When another refresh owns the lock, the losing process calls `phase18_ucl_refresh_publish_event()` anyway. It races the active transaction for `ucl_source_refreshes.csv` and the blocked sidecar, allowing lost append rows, last-writer-wins sidecars, or a sidecar/history mismatch.

**Fix:** Do not mutate shared refresh evidence when the lock cannot be acquired. Either return a non-durable concurrent result, or enqueue/record it only after acquiring the same lock once the active transaction has completed.

### CR-10: Tampered append-only history is appended and published without validation

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:232-240`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:325-345`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:448-498`

**Issue:** Refresh reads existing history but does not call the available state validator before deriving a batch ID, promoting a candidate, or appending. A schema-compatible history row with a bad hash is retained, a new accepted row is appended, and the operation can report success while the supposedly append-only ledger is invalid.

**Fix:** Before candidate validation or mutation, load history plus the current sidecar and run strict schema/hash/uniqueness/state validation. Abort without promotion on any mismatch, then validate the newly written ledger again before committing the accepted generation.

### CR-11: Provider-exit review is not authorized against the incumbent it can delete

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:611-631`; `/Users/davidzenz/R/xGelo/R/competition/ucl_source_refresh.R:680-727`

**Issue:** Exit validation checks only self-generated review hashes and hash formatting. `phase18_apply_provider_exit()` selects a target from the review edition but never validates that the incumbent is provider-authorized or that its provider ID, decision ID, and decision hash equal the review. An unrelated self-hashed review can retain or destructively withdraw any tree at that edition path.

**Fix:** Load and fully validate the incumbent bundle first. Require provider authority and exact provider, edition, decision ID, and decision hash equality; reject manual/fixture/unreadable incumbents. Bind the reviewed retain/withdraw inventory to that incumbent manifest before swapping directories.

### CR-12: Historical result evidence can predate kickoff and still enter training

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/club/history_contract.R:228-275`

**Issue:** Temporal eligibility requires only `evidence < cutoff`; it never requires result evidence to become available after the match. A completed 18:00 match with a 10:00 evidence timestamp was reproduced as `counts_for_model=TRUE`, creating direct outcome leakage into model training.

**Fix:** Require evidence availability to be at or after a conservative completion instant (or next-day UTC for date-only rows) and before the training cutoff. Treat impossible pre-kickoff/pre-completion timestamps as a typed exclusion and add boundary tests.

### CR-13: Adapter freshness reports success after checking only competition metadata

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:288-301`; `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:328-395`; `/Users/davidzenz/R/xGelo/R/competition/football_data_org_adapter.R:450-455`

**Issue:** Only `competition$lastUpdated` is freshness-validated. Team and match timestamps are copied without parsing or age checks, standings have no checked freshness signal, and the returned coverage nevertheless hard-codes `freshness_passed=TRUE`. Stale or malformed current resources can therefore authorize acceptance and dashboard publication.

**Fix:** Validate every required resource's source timestamp and every relevant row timestamp against `now_utc`, reject malformed/future/stale values, and compute `freshness_passed` as the conjunction of those checks rather than a constant.

### CR-14: “Independent” history validation trusts eligibility audit claims instead of recomputing them

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/R/club/history_contract.R:575-659`

**Issue:** Corpus validation verifies hashes, then trusts identity fraction and duplicate/score/temporal audit booleans. It does not recompute those gates from `matches`, nor validate the registry/review artifacts named by the manifest. A self-consistent bundle can claim clean audits while its completed match rows contain blank identities, duplicate semantics, unresolved scores, or non-prior evidence, and can be accepted for training.

**Fix:** Recompute every eligibility gate directly from normalized matches and source rows during validation. Include or resolve the exact registry/review artifacts and verify their hashes. Compare every recomputed audit row and manifest field with stored values before returning accepted.

### CR-15: Unvalidated edition IDs allow path traversal in the acceptance CLI

**Classification:** BLOCKER

**File:** `/Users/davidzenz/R/xGelo/scripts/accept_ucl_provider.R:35-77`; `/Users/davidzenz/R/xGelo/scripts/accept_ucl_provider.R:102-112`

**Issue:** The CLI fixes the provider ID but accepts any nonempty edition ID and interpolates it directly beneath the evidence root. Values containing `..` or path separators escape the intended provider directory when the no-key path creates and writes its six artifacts.

**Fix:** Require the exact supported edition (`ucl_2026_27`) or a strict safe-ID allowlist, resolve the final target, and verify containment under a trusted evidence root before any read or write.

## Warnings

### WR-01: Club validity/status is not validated consistently

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/club/identity.R:166-214`; `/Users/davidzenz/R/xGelo/R/club/identity.R:298-300`

**Issue:** Club rows require a nonempty `valid_from_utc` and `club_status`, but their timestamps are not parsed, their interval is not checked, status values are unrestricted, and resolution ignores `club_status`. An inactive/unsupported status can resolve as long as its interval happens to parse later.

**Fix:** Apply the same UTC and positive half-open interval checks to clubs, enforce a closed status enum, and require an active status during resolution (or document and test that validity alone is authoritative and remove the misleading status field).

### WR-02: “Exact” inventories ignore hidden files and authority-evidence surplus

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/competition/ucl_source_bundle.R:609-638`; `/Users/davidzenz/R/xGelo/R/club/history_contract.R:575-584`

**Issue:** Candidate and history inventory checks use `all.files=FALSE` (or the default), so dotfiles are invisible. The candidate also never enforces an exact per-authority `authority_evidence` inventory. Undeclared hidden or surplus evidence can travel with a supposedly exact bundle, including accidental credentials.

**Fix:** Enumerate with `all.files=TRUE, no..=TRUE` at every level and compare exact recursive path sets, including authority evidence. Reject any undeclared file or directory.

### WR-03: Successful candidate CLI modes exit as failures after mutation

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/scripts/accept_ucl_provider.R:338-350`

**Issue:** The executable footer always dereferences `result$manifest`, but `provider_live`, `manual_reviewed`, and `fixture_contract` return candidate metadata without a manifest. Direct CLI use can write a valid candidate and then exit with an error, encouraging unsafe retries and provenance collisions.

**Fix:** Render mode-specific success output, or return one common result schema with explicit status/decision fields. Add subprocess tests for every supported CLI mode and assert both exit status and durable state.

### WR-04: History audit and accepted corpus are committed as separate transactions

**Classification:** WARNING

**File:** `/Users/davidzenz/R/xGelo/R/club/history_contract.R:662-688`

**Issue:** The audit root is replaced before the accepted root is staged and promoted. If accepted publication fails, the audit advertises a new eligible corpus while the accepted root still contains the incumbent, leaving two public roots inconsistent.

**Fix:** Stage both outputs before mutation and commit them through a shared generation manifest/pointer, or write an explicit transaction state that readers require before treating the audit as current.

---

_Reviewed: 2026-09-20T10:27:38Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
