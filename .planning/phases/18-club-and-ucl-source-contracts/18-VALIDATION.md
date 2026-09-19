---
phase: 18
slug: club-and-ucl-source-contracts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-19
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for lawful provider acceptance, fail-closed current-state bundles, club identity, and historical corpus evidence.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | `tests/testthat.R` and `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` |
| **Full phase command** | `Rscript --vanilla -e 'files <- list.files("tests/testthat", pattern = "^test_phase18_.*[.]R$", full.names = TRUE); for (f in files) testthat::test_file(f)'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | Quick: under 30 seconds; phase suite: under 3 minutes |

## Sampling Rate

- **After every task commit:** Run the focused `test_phase18_*.R` file named by the task.
- **After every plan wave:** Run the full Phase 18 command.
- **Before `/gsd:verify-work`:** The full `tests/testthat` suite must be green.
- **Max feedback latency:** 3 minutes for automated phase checks.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 18-01 | 1 | UCLSRC-01 | T18-01 | Missing key cannot enable automation; credentials never persist | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ❌ RED-first | ⬜ pending |
| 18-01-02 | 18-01 | 1 | UCLSRC-01 | T18-07 | Owner and edition-expectation matrices are exact, hash-bound, and disabled by default | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")' &amp;&amp; git diff --check` | ❌ RED-first | ⬜ pending |
| 18-01-03 | 18-01 | 1 | UCLSRC-01 | T18-08, T18-16 | Only bounded probe evidence can atomically create first acceptance; failures preserve incumbent | failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")' &amp;&amp; git diff --check` | ❌ RED-first | ⬜ pending |
| 18-02-01 | 18-02 | 1 | CLUBID-01 | T18-05 | Ambiguous, overlapping, or national identities fail closed | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ❌ RED-first | ⬜ pending |
| 18-02-02 | 18-02 | 1 | CLUBID-01 | T18-09, T18-03 | Alias fallback and registry ordering remain exact and hash-stable | unit/metamorphic | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")' &amp;&amp; git diff --check` | ❌ RED-first | ⬜ pending |
| 18-02-03 | 18-02 | 1 | CLUBID-01 | T18-17 | Only explicit owner mappings populate registries; unresolved tokens remain blocked evidence | integration/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ❌ RED-first | ⬜ pending |
| 18-03-01 | 18-03 | 2 | UCLSRC-02 | T18-01, T18-02, T18-04 | Fixed provider window traverses the adapter and CLI while fictional evidence remains automation-disabled | tracer integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R"); testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ❌ RED-first | ⬜ pending |
| 18-03-02 | 18-03 | 2 | UCLSRC-02 | T18-16, T18-01 | Fixed probe emits reviewed identity evidence and atomically creates first acceptance only after all gates pass | CLI integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` | ❌ RED-first | ⬜ pending |
| 18-05-01 | 18-05 | 2 | CLUBHIST-01 | T18-03, T18-06 | Pinned rows preserve score semantics and frozen next-day UTC evidence time | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ❌ RED-first | ⬜ pending |
| 18-05-02 | 18-05 | 2 | CLUBHIST-01 | T18-13, T18-17 | Inventory thresholds and owner-reviewed historical identity are exact | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")' &amp;&amp; test -z "$(git ls-files data/club/local_raw)"` | ❌ RED-first | ⬜ pending |
| 18-05-03 | 18-05 | 2 | CLUBHIST-01 | T18-06, T18-14 | Only a fully eligible corpus promotes; blocked audit remains durable | integration/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ❌ RED-first | ⬜ pending |
| 18-06-01 | 18-06 | 3 | UCLSRC-03 | T18-03, T18-18 | One provider resource validates end-to-end through authority and the complete hash graph | tracer integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` | ❌ RED-first | ⬜ pending |
| 18-06-02 | 18-06 | 3 | UCLSRC-03 | T18-03, T18-11, T18-18 | Complete bundles reject tampering and enforce mutually exclusive provider/manual/fixture authority | contract/CLI integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R"); testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R"); testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ❌ RED-first | ⬜ pending |
| 18-04-01 | 18-04 | 4 | UCLSRC-04 | T18-04, T18-18 | Technical failures and invalid candidates preserve the incumbent byte-for-byte | failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ❌ RED-first | ⬜ pending |
| 18-04-02 | 18-04 | 4 | UCLSRC-04 | T18-07, T18-01 | Reviewed retain preserves permitted bytes; reviewed withdraw atomically installs an unavailable tombstone and preserves lawful manual/open state | integration/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ❌ RED-first | ⬜ pending |
| 18-04-03 | 18-04 | 4 | UCLSRC-04 | T18-12 | Human review is preceded by the complete technical rollback and provider-exit branch matrix | checkpoint + failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ❌ RED-first | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase18_source_acceptance.R` — created RED-first by 18-01-01; decision states, missing-key path, owner/machine conjunction, concurrency, interruption, and secret hygiene.
- [ ] `tests/testthat/test_phase18_football_data_adapter.R` — created RED-first by 18-03-01; provider projection, lifecycle, enums, cardinality, pagination, null/empty behavior, and schema drift.
- [ ] `tests/testthat/test_phase18_source_bundle.R` — created RED-first by 18-06-01; provenance, stable order, collision, authority-union, and complete hash-chain validation.
- [ ] `tests/testthat/test_phase18_refresh_failure.R` — created RED-first by 18-04-01; technical last-known-good preservation, no-incumbent behavior, interruption/concurrency, and reviewed retain/withdraw provider-exit branches.
- [ ] `tests/testthat/test_phase18_club_identity.R` — created RED-first by 18-02-01; source IDs, half-open validity intervals, empty/single/null state, alias ordering, ambiguity, and cross-domain rejection.
- [ ] `tests/testthat/test_phase18_club_history_contract.R` — created RED-first by 18-05-01; source pins, licensing, exact threshold boundaries, duplicates, score semantics, and point-in-time eligibility.
- [ ] `tests/fixtures/phase18/football_data_org/` — created by 18-03-01; synthetic provider-shaped success and failure fixtures only.
- [ ] `tests/fixtures/phase18/openfootball/` — created by 18-05-01; synthetic date-only, extra-time, shootout, duplicate, and rename fixtures.
- [ ] `tests/fixtures/phase18/provider_terms_review.csv` — created by 18-01-01; synthetic review states, never a production legal verdict.
- [ ] Production `edition_expectations.csv` — created by 18-01-02; reviewed exact club/schedule/stage/standings expectations and aggregate hash.

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

- [ ] All tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks lack an automated check.
- [ ] Wave 0 covers every missing test and fixture path.
- [ ] Default tests require neither network access nor provider credentials.
- [ ] No watch-mode flags are used.
- [ ] Automated feedback latency remains below 3 minutes.
- [ ] `nyquist_compliant: true` is set after validation coverage is implemented and audited.

**Approval:** pending
