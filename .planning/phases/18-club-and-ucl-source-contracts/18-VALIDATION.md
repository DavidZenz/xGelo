---
phase: 18
slug: club-and-ucl-source-contracts
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-19
updated: 2026-09-20
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for lawful provider acceptance, fail-closed current-state bundles, club identity, and historical corpus evidence.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | `tests/testthat.R` and `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_adversarial_regression.R")'` |
| **Full phase command** | `Rscript --vanilla scripts/verify_phase18_contracts.R` (authoritative; passed 2026-09-20) |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Measured runtime** | Adversarial file: about 55 seconds; authoritative eight-file phase gate: about 4 minutes |

## Sampling Rate

- **After every task commit:** Run the focused `test_phase18_*.R` file named by the task.
- **After every plan wave:** Run all currently implemented focused Phase 18 files; after 18-13-02, run the authoritative full Phase 18 command.
- **Before `/gsd:verify-work`:** The full `tests/testthat` suite must be green.
- **Max feedback latency:** 3 minutes for automated phase checks.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 18-01 | 1 | UCLSRC-01 | T18-01 | Missing key cannot enable automation; credentials never persist | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ✅ exists | ✅ passed |
| 18-01-02 | 18-01 | 1 | UCLSRC-01 | T18-07 | Owner and edition-expectation matrices are exact, hash-bound, and disabled by default | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-01-03 | 18-01 | 1 | UCLSRC-01 | T18-08, T18-16 | Only bounded probe evidence can atomically create first acceptance; failures preserve incumbent | failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-02-01 | 18-02 | 1 | CLUBID-01 | T18-05 | Ambiguous, overlapping, or national identities fail closed | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ✅ exists | ✅ passed |
| 18-02-02 | 18-02 | 1 | CLUBID-01 | T18-09, T18-03 | Alias fallback and registry ordering remain exact and hash-stable | unit/metamorphic | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-02-03 | 18-02 | 1 | CLUBID-01 | T18-17 | Only explicit owner mappings populate registries; unresolved tokens remain blocked evidence | integration/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ✅ exists | ✅ passed |
| 18-03-01 | 18-03 | 2 | UCLSRC-02 | T18-01, T18-02, T18-04 | Fixed provider window traverses the adapter and CLI while fictional evidence remains automation-disabled | tracer integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R"); testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ✅ exists | ✅ passed |
| 18-03-02 | 18-03 | 2 | UCLSRC-02 | T18-16, T18-01 | Fixed probe emits reviewed identity evidence and atomically creates first acceptance only after all gates pass | CLI integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` | ✅ exists | ✅ passed |
| 18-05-01 | 18-05 | 2 | CLUBHIST-01 | T18-03, T18-06 | Pinned rows preserve score semantics and frozen next-day UTC evidence time | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ✅ exists | ✅ passed |
| 18-05-02 | 18-05 | 2 | CLUBHIST-01 | T18-13, T18-17 | Inventory thresholds and owner-reviewed historical identity are exact | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")' &amp;&amp; test -z "$(git ls-files data/club/local_raw)"` | ✅ exists | ✅ passed |
| 18-05-03 | 18-05 | 2 | CLUBHIST-01 | T18-06, T18-14 | Only a fully eligible corpus promotes; blocked audit remains durable | integration/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ✅ exists | ✅ passed |
| 18-06-01 | 18-06 | 3 | UCLSRC-03 | T18-03, T18-18 | One provider resource validates end-to-end through authority and the complete hash graph | tracer integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` | ✅ exists | ✅ passed |
| 18-06-02 | 18-06 | 3 | UCLSRC-03 | T18-03, T18-11, T18-18 | Complete bundles reject tampering and enforce mutually exclusive provider/manual/fixture authority | contract/CLI integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R"); testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ✅ exists | ✅ passed |
| 18-04-01 | 18-04 | 4 | UCLSRC-04 | T18-04, T18-18 | Technical failures and invalid candidates preserve the incumbent byte-for-byte | failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ✅ exists | ✅ passed |
| 18-04-02 | 18-04 | 4 | UCLSRC-04 | T18-07, T18-01 | Reviewed retain preserves permitted bytes; reviewed withdraw atomically installs an unavailable tombstone and preserves lawful manual/open state | integration/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ✅ exists | ✅ passed |
| 18-04-03 | 18-04 | 4 | UCLSRC-04 | T18-12 | Human review is preceded by the complete technical rollback and provider-exit branch matrix | checkpoint + failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ✅ exists | ✅ passed |
| 18-07-01 | 18-07 | 5 | UCLSRC-01, CLUBID-01 | T18-G07-01 | Canonical typed v2 encoding rejects collision, delimiter, type, missing, and multiplicity ambiguity | adversarial/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_canonical_hash.R")'` | ✅ exists | ✅ passed |
| 18-07-02 | 18-07 | 5 | UCLSRC-01, CLUBID-01 | T18-G07-02 | Sequence, row, and table v2 semantics are complete while existing consumers remain unchanged and green | adversarial/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_canonical_hash.R"); for (f in sort(list.files("tests/testthat", pattern = "^test_phase18_.*[.]R$", full.names = TRUE))) if (basename(f) != "test_phase18_canonical_hash.R") testthat::test_file(f)'` | ✅ exists | ✅ passed |
| 18-14-01 | 18-14 | 6 | UCLSRC-01..04, CLUBID-01, CLUBHIST-01 | T18-G14-01, T18-G14-03 | All four production CLIs load the common module first without durable mutation | bootstrap/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R"); testthat::test_file("tests/testthat/test_phase18_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ✅ exists | ✅ passed |
| 18-14-02 | 18-14 | 6 | UCLSRC-01..04, CLUBID-01, CLUBHIST-01 | T18-G14-01, T18-G14-02 | All six direct loaders, dynamic source vectors, and child-process commands load the common module first | bootstrap/full sampling | `Rscript --vanilla -e 'for (f in sort(list.files("tests/testthat", pattern = "^test_phase18_.*[.]R$", full.names = TRUE))) testthat::test_file(f)' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-08-01 | 18-08 | 7 | UCLSRC-01 | T18-G08-01 | Acceptance hashes migrate to v2 and owner, edition, capability, and schema authority is recomputed from durable evidence | adversarial/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ✅ exists | ✅ passed |
| 18-08-02 | 18-08 | 7 | UCLSRC-01 | T18-G08-02 | Immutable acceptance generations and one pointer prevent mixed concurrent reads | subprocess/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ✅ exists | ✅ passed |
| 18-08-03 | 18-08 | 7 | UCLSRC-01 | T18-G08-03, T18-G08-04 | Edition paths are contained and every CLI mode has truthful exits | CLI/subprocess | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-09-01 | 18-09 | 7 | UCLSRC-02, CLUBID-01 | T18-G09-01, T18-G09-02 | Identity evidence migrates to v2 and one fresh resource window resolves only active clubs | tracer/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` | ✅ exists | ✅ passed |
| 18-09-02 | 18-09 | 7 | UCLSRC-02, CLUBID-01 | T18-G09-03, T18-G09-04 | Freshness and acquisition failure matrices are exhaustive and fail closed | adversarial/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-10-01 | 18-10 | 8 | UCLSRC-03 | T18-G10-01, T18-G10-02 | Candidate authority binds exact edition, bytes, inventory, and recomputed decision | tracer/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` | ✅ exists | ✅ passed |
| 18-10-02 | 18-10 | 8 | UCLSRC-03 | T18-G10-03 | Lexical symlinks and hidden/surplus inventory fail exact candidate validation | filesystem/adversarial | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-12-01 | 18-12 | 8 | CLUBHIST-01 | T18-G12-01 | Completion and cutoff precision/tie rules exclude pre-completion evidence | temporal/adversarial | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ✅ exists | ✅ passed |
| 18-12-02 | 18-12 | 8 | CLUBHIST-01 | T18-G12-02, T18-G12-03 | Every corpus gate is recomputed from bound source and identity snapshots | adversarial/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ✅ exists | ✅ passed |
| 18-12-03 | 18-12 | 8 | CLUBHIST-01 | T18-G12-04 | Audit and accepted corpus become visible through one immutable generation pointer | subprocess/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-11-01 | 18-11 | 9 | UCLSRC-04 | T18-G11-01 | Accepted and transaction generations commit through one validating pointer | subprocess/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ✅ exists | ✅ passed |
| 18-11-02 | 18-11 | 9 | UCLSRC-04 | T18-G11-02, T18-G11-03 | Lock losers are silent and prior ledgers validate before append | concurrency/adversarial | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ✅ exists | ✅ passed |
| 18-11-03 | 18-11 | 9 | UCLSRC-04 | T18-G11-04 | Provider exit binds exact incumbent authority and CLI exits remain truthful | CLI/adversarial | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")' &amp;&amp; git diff --check` | ✅ exists | ✅ passed |
| 18-13-01 | 18-13 | 10 | UCLSRC-01..04, CLUBID-01, CLUBHIST-01 | T18-G13-01 | All CR-01..CR-15 and WR-01..WR-04 exploit probes run against production interfaces | adversarial/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_adversarial_regression.R")'` | ✅ exists | ✅ passed |
| 18-13-02 | 18-13 | 10 | UCLSRC-01..04, CLUBID-01, CLUBHIST-01 | T18-G13-02, T18-G13-03, T18-G13-04 | One runner enforces probe, prohibition, full-suite, evidence, and validation-state completeness | adversarial/full phase | `Rscript --vanilla scripts/verify_phase18_contracts.R &amp;&amp; git diff --check` | ✅ exists | ✅ passed |

*Status: ✅ passed means the authoritative credential-free phase runner executed the task's evidence successfully.*

## Wave 0 Requirements

- [x] `tests/testthat/test_phase18_source_acceptance.R` — exists; gap tasks 18-14/08 establish canonical-first loading, migrated authority, generation, and subprocess proof.
- [x] `tests/testthat/test_phase18_football_data_adapter.R` — exists; gap tasks 18-14/09 establish canonical-first loading, freshness, and failure classification.
- [x] `tests/testthat/test_phase18_source_bundle.R` — exists; gap tasks 18-14/10 establish canonical-first parent/child loading, exact inventory, lexical path, and authority recomputation.
- [x] `tests/testthat/test_phase18_refresh_failure.R` — exists; gap tasks 18-14/11 establish canonical-first loading, generation/pointer, locking, and provider-exit proof.
- [x] `tests/testthat/test_phase18_club_identity.R` — exists; gap tasks 18-14/09 establish canonical-first loading, v2 migration, and active-status resolution.
- [x] `tests/testthat/test_phase18_club_history_contract.R` — exists; gap tasks 18-14/12 establish canonical-first loading, temporal, recomputation, and publication proof.
- [x] `tests/fixtures/phase18/football_data_org/` — exists; synthetic provider-shaped success and failure fixtures only.
- [x] `tests/fixtures/phase18/openfootball/` — exists; synthetic date-only, extra-time, shootout, duplicate, and rename fixtures.
- [x] `tests/fixtures/phase18/provider_terms_review.csv` — exists; synthetic review states, never a production legal verdict.
- [x] Production `edition_expectations.csv` — exists; reviewed exact club/schedule/stage/standings expectations and aggregate hash.
- [x] `tests/testthat/test_phase18_canonical_hash.R` — canonical v2 collision and type-domain proof passes.
- [x] `tests/testthat/test_phase18_adversarial_regression.R` — exact CR/WR inventory passes with 60 assertions.
- [x] `scripts/verify_phase18_contracts.R` — authoritative phase gate exits zero.

The authoritative command passed with 15 critical probes, four warning probes, 15 edge probes, 50 mapped prohibitions (20 original and 30 gap), eight fresh-process test files, 131 tests, and 785 assertions. Production provider automation and club-history training remain fail-closed.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner accepts rights, normalized display, retention, attribution, application scope, and provider-exit terms | UCLSRC-01 | These are owner/legal-business judgments, not code assertions | Review the current terms URL/hash, complete every terms-review field, record reviewer/time, and reject or select manual-only when any field is unresolved. |
| Live 2026/27 UCL endpoint coverage and observed freshness pass | UCLSRC-01, UCLSRC-02 | No provider key is available in the default environment and fixture replay cannot prove live coverage | Supply `FOOTBALL_DATA_API_TOKEN` out of band, run the opt-in acceptance command, inspect endpoint/stage/cardinality/freshness evidence, scan outputs for the exact token, and sign the decision artifact. |
| Current and historical token mappings identify the intended clubs and validity intervals | CLUBID-01, CLUBHIST-01 | Canonical entity identity is owner/domain judgment and cannot be inferred safely | Review both token ledgers, author explicit mappings and half-open intervals, run bootstrap apply/verify, and leave every unresolved row blocked. |

The valid no-key result is `not_run_missing_credential` with `automation_enabled = FALSE`; this is not a failed test and must never be promoted as live acceptance.

## Threat References

- **T18-01:** API token disclosure through Git, logs, serialized requests, fixtures, or target metadata.
- **T18-02:** Arbitrary host/redirect use bypasses the fixed provider boundary.
- **T18-03:** Raw or normalized source data is altered without invalidating lineage.
- **T18-04:** Null, empty, stale, incomplete, or schema-drifted data replaces last-known-good state.
- **T18-05:** Provider, alias, or national-team identity collides with the club namespace.
- **T18-06:** Mutable, duplicated, temporally unsafe, or score-ambiguous history becomes model-eligible.
- **T18-16:** First live acceptance bypasses normal automation gating or expands beyond the bounded four-resource probe.
- **T18-17:** Identity bootstrap guesses, drops, or auto-merges unresolved current/historical club tokens.
- **T18-18:** Provider, manual, and fixture authority fields are mixed or trusted without source-mode-specific validation.

## Validation Sign-Off

- [x] All tasks have automated verification or an explicit human owner/key/source dependency.
- [x] Sampling continuity: no three consecutive tasks lack an automated check.
- [x] Wave 0 covers every missing test and fixture path.
- [x] Default tests require neither network access nor provider credentials.
- [x] No watch-mode flags are used.
- [x] Automated phase feedback remains below 5 minutes.
- [x] All 35 original-plus-gap task rows are present and their file-existence markers match disk.
- [x] The exact 50-prohibition bijection and all CR/WR/edge inventories pass in the authoritative runner.
- [x] `wave_0_complete: true`, `nyquist_compliant: true`, `status: complete`, and approval were set after the authoritative runner exited zero.

**Approval:** automated Phase 18 contract gate passed — 2026-09-20
