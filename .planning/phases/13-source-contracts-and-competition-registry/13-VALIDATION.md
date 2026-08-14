---
phase: 13
slug: source-contracts-and-competition-registry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-13
---

# Phase 13 - Validation Strategy

> Per-phase validation contract for the source snapshot and competition registry contracts.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - source-style tests in `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | under 60 seconds for focused tests; full-suite duration follows the existing repository suite |

## Sampling Rate

- **After every task commit:** Run the two focused Phase 13 test files.
- **After every plan wave:** Run the full `tests/testthat/` suite.
- **Before `/gsd:verify-work`:** Full suite must be green, plus deterministic replay of one official candidate bundle and one reviewed fallback bundle.
- **Max feedback latency:** 60 seconds for focused contract tests.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-02 / T-13-03 / T-13-04 | The tracer proves a compact structured fixture becomes an accepted bundle, normalized team row, and edition registry row with linked provenance. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - W0 | pending |
| 13-01-02 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-03 / T-13-04 / T-13-05 | Edge and prohibition tests cover missing resources, null provenance, ordering, encoding, ambiguous identity, mixed fallback, fabricated pre-draw structures, and raw-store tracking. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - W0 | pending |
| 13-02-01 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-01 / T-13-02 / T-13-04 / T-13-05 | Full resource/provenance validation and canonical hashes reject incomplete, unsafe, or mixed bundles before acceptance. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - created in Plan 13-01 | pending |
| 13-02-02 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-01 / T-13-02 / T-13-04 / T-13-05 | Bounded structured capture, local raw retention, reviewed fallback acceptance, blocked metadata, and last-accepted preservation are replayable without network access. | integration | `Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id uefa_nations_league_2026_27 --output-root data/competition/accepted --registry-root data/competition/registries --dry-run` | yes - created in Plan 13-01 | pending |
| 13-03-01 | 03 | 3 | DATA-03 | T-13-10 / T-13-11 | Stable team identity and warning-bearing normalized-name fallback preserve display names, aliases, IDs, and order-stable hashes. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-03-02 | 03 | 3 | COMP-01 | T-13-12 / T-13-13 / T-13-14 | Both edition rows enforce lifecycle, blocked overlay, pinned release, source/output slots, explicit EURO pre-draw, and no fabricated structures. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R"); source("R/competition/edition_registry.R"); regs <- load_competition_edition_registries("data/competition/registries"); validate_competition_edition_registries(regs)'` | yes - created in Plan 13-01 | pending |
| 13-04-01 | 04 | 4 | DATA-01, DATA-02, DATA-03 | T-13-04-01 / T-13-04-02 / T-13-04-04 | Acquisition publication routes accepted fixtures through stable identity normalization, preserves UEFA source values and provenance, and keeps EURO pre-draw fixtures schema-complete and empty. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file extended in Plan 13-04 | pending |
| 13-04-02 | 04 | 4 | DATA-03 | T-13-04-05 / T-13-04-06 | Accepted results join exactly to normalized fixture identity, preserve source status/goals/names and both artifact links, and preprocess_martj42()-shaped history requires explicit edition mapping without leakage. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing files extended in Plan 13-04 | pending |
| 13-04-03 | 04 | 4 | DATA-02, DATA-03 | T-13-04-01 / T-13-04-03 / T-13-04-04 / T-13-04-05 | Accepted fixture and result artifacts have exact normalized schemas, stable row hashes, source IDs, display names, edition/source-artifact links, and no tracked raw bytes. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file extended in Plan 13-04 | pending |
| 13-05-01 | 05 | 5 | DATA-01, DATA-02, DATA-03, COMP-01 | T-13-05-01 / T-13-05-02 | Production edition loading validates accepted directories, all five resources, manifest/registry identifiers, canonical whole-table/content hashes, raw hashes, and EURO pre-draw emptiness. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing file extended in Plan 13-05 | pending |
| 13-05-02 | 05 | 5 | DATA-03 | T-13-05-03 | The default identity loader requires adjacent source-bundle provenance and rejects forged foreign keys even when row hashes are recomputed. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing file extended in Plan 13-05 | pending |
| 13-06-01 | 06 | 6 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-02 / T-13-06-03 | A failed refresh stages and validates competition_editions.csv, preserves the complete accepted edition tree and source registries, and writes blocked_refresh.json with matching failure metadata. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R")'` | no - created in Plan 13-06-01 | pending |
| 13-06-02 | 06 | 6 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-04 | A blocked edition cannot auto-clear; explicit operator recovery and validation are required before a subsequent accepted refresh updates registry linkage. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-06-01 | pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - bundle/artifact schema, required resources, hashes, structured fixture replay, and fallback-mixing rejection.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - identity mapping, lifecycle transitions, blocked recovery, pre-draw EURO row, and pinned release invariants.
- [ ] `tests/fixtures/phase13/uefa_nations_league_sample.json` - compact structured Nations League sample used by the bounded capture contract.
- [ ] `tests/fixtures/phase13/euro2028_predraw_sample.json` - schema-complete EURO pre-draw resource metadata.
- [ ] `tests/fixtures/phase13/reviewed_fallback_bundle.json` - complete reviewed fallback bundle fixture.
- [ ] `tests/fixtures/phase13/team_identity_aliases.csv` - Plan 13-03 identity fallback, encoding, and ambiguity cases. Keep exact raw captures local-only; commit only these compact fixtures needed for deterministic tests.

## Gap-Closure Regression Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - Plan 13-04 acquisition regression for normalized accepted fixtures/results, preserved UEFA source values, normalized EURO pre_draw identity-bearing empty schemas, and result-row hashes.
- [ ] `tests/fixtures/phase13/martj42_history_sample.csv` and `tests/fixtures/phase13/martj42_history_edition_map.csv` - Plan 13-04 compact preprocess_martj42()-shaped history rows plus explicit edition lookup for source-name, score/date preservation and fail-closed identity/edition regressions.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - Plan 13-05 production-loader regressions for missing accepted directories, stale row hashes, stale canonical whole-table/content hashes after row-hash recomputation, manifest links, and default identity provenance.
- [ ] `tests/testthat/test_phase13_refresh_failure.R` - Plan 13-06 temporary-copy CLI regression for the blocked registry overlay, blocked_refresh.json, explicit recovery, and a complete accepted-edition tree snapshot covering fixtures, groups, standings, results, status, and manifests.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm the live official UEFA structured service paths and response shapes remain available at capture time. | DATA-01 | UEFA service paths are public but undocumented and may change independently of the parser contract. | After the automated Wave 6 gate, run the bounded capture/discovery command with one operator-supplied HTTPS structured URL for each of fixtures, groups, standings, results, and status; inspect the accepted manifest, normalized fixtures/results, and source-shaped groups/standings/status, and retain resulting raw bytes locally. A failure must leave the prior accepted bundle active. |
| Confirm reviewed fallback and failed-refresh recovery in an isolated operational copy. | DATA-04, COMP-01 | Review approval, operator action, and current source evidence cannot be established by fixture-only automation. | As the final human backstop after Plans 13-04 through 13-06, run one reviewed fallback and one invalid replacement against temporary registry/output roots. Confirm source/retrieval/reason/operator/checksum metadata, blocked competition_editions.csv state, blocked_refresh.json, unchanged accepted fixtures/groups/standings/results/status/manifest files, and explicit operator-action recovery before a later accepted refresh. |

## Final Human Backstop

The final human backstop is required after the Wave 6 automated checks and before Phase 13 verification sign-off. It covers both live five-class official capture and the reviewed-fallback/blocked-refresh workflow; deterministic fixture replay is supporting evidence only and does not substitute for these operational checks.

## Validation Sign-Off

- [ ] All tasks have an automated verify command or a Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test and fixture references.
- [ ] No watch-mode flags.
- [ ] `nyquist_compliant: true` set in frontmatter after execution and verification.
- [ ] Approval: pending
