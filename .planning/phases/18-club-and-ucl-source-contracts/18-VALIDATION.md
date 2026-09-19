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
| TBD | TBD | 0 | UCLSRC-01 | T18-01 | Missing key cannot enable automation; credentials never persist | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | UCLSRC-02 | T18-01, T18-02 | Fixed provider host and redacted process-local token | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | UCLSRC-03 | T18-03 | Tampering invalidates row, table, and manifest hashes | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | UCLSRC-04 | T18-04 | Invalid candidates preserve the incumbent byte-for-byte | failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | CLUBID-01 | T18-05 | Ambiguous, overlapping, or national identities fail closed | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | CLUBHIST-01 | T18-03, T18-06 | Only pinned, licensed, deduplicated, point-in-time-safe rows become training-eligible | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase18_source_acceptance.R` — decision states, missing-key path, owner/machine conjunction, and secret hygiene.
- [ ] `tests/testthat/test_phase18_football_data_adapter.R` — provider projection, lifecycle, enums, cardinality, null/empty behavior, and schema drift.
- [ ] `tests/testthat/test_phase18_source_bundle.R` — provenance and complete hash-chain validation.
- [ ] `tests/testthat/test_phase18_refresh_failure.R` — last-known-good preservation and blocked-reason matrix.
- [ ] `tests/testthat/test_phase18_club_identity.R` — source IDs, validity intervals, alias review, ambiguity, and cross-domain rejection.
- [ ] `tests/testthat/test_phase18_club_history_contract.R` — source pins, licensing, coverage, duplicates, score semantics, and point-in-time eligibility.
- [ ] `tests/fixtures/phase18/football_data_org/` — synthetic provider-shaped success and failure fixtures only.
- [ ] `tests/fixtures/phase18/openfootball/` — synthetic date-only, extra-time, shootout, duplicate, and rename fixtures.
- [ ] `tests/fixtures/phase18/provider_terms_review.csv` — synthetic review states; never a production legal verdict.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner accepts rights, normalized display, retention, attribution, application scope, and provider-exit terms | UCLSRC-01 | These are owner/legal-business judgments, not code assertions | Review the current terms URL/hash, complete every terms-review field, record reviewer/time, and reject or select manual-only when any field is unresolved. |
| Live 2026/27 UCL endpoint coverage and observed freshness pass | UCLSRC-01, UCLSRC-02 | No provider key is available in the default environment and fixture replay cannot prove live coverage | Supply `FOOTBALL_DATA_API_TOKEN` out of band, run the opt-in acceptance command, inspect endpoint/stage/cardinality/freshness evidence, scan outputs for the exact token, and sign the decision artifact. |

The valid no-key result is `not_run_missing_credential` with `automation_enabled = FALSE`; this is not a failed test and must never be promoted as live acceptance.

## Threat References

- **T18-01:** API token disclosure through Git, logs, serialized requests, fixtures, or target metadata.
- **T18-02:** Arbitrary host/redirect use bypasses the fixed provider boundary.
- **T18-03:** Raw or normalized source data is altered without invalidating lineage.
- **T18-04:** Null, empty, stale, incomplete, or schema-drifted data replaces last-known-good state.
- **T18-05:** Provider, alias, or national-team identity collides with the club namespace.
- **T18-06:** Mutable, duplicated, temporally unsafe, or score-ambiguous history becomes model-eligible.

## Validation Sign-Off

- [ ] All tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks lack an automated check.
- [ ] Wave 0 covers every missing test and fixture path.
- [ ] Default tests require neither network access nor provider credentials.
- [ ] No watch-mode flags are used.
- [ ] Automated feedback latency remains below 3 minutes.
- [ ] `nyquist_compliant: true` is set after validation coverage is implemented and audited.

**Approval:** pending
