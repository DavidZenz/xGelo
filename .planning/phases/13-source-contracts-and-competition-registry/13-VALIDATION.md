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
| 13-03-01 | 03 | 2 | DATA-03 | T-13-10 / T-13-11 | Stable team identity and warning-bearing normalized-name fallback preserve display names, aliases, IDs, and order-stable hashes. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-03-02 | 03 | 2 | COMP-01 | T-13-12 / T-13-13 / T-13-14 | Both edition rows enforce lifecycle, blocked overlay, pinned release, source/output slots, explicit EURO pre-draw, and no fabricated structures. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R"); source("R/competition/edition_registry.R"); regs <- load_competition_edition_registries("data/competition/registries"); validate_competition_edition_registries(regs)'` | yes - created in Plan 13-01 | pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - bundle/artifact schema, required resources, hashes, structured fixture replay, and fallback-mixing rejection.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - identity mapping, lifecycle transitions, blocked recovery, pre-draw EURO row, and pinned release invariants.
- [ ] `tests/fixtures/phase13/` - compact structured Nations League sample, EURO pre-draw metadata sample, and reviewed fallback sample. Keep exact raw captures local-only; commit only compact fixtures needed for deterministic tests.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm the live official UEFA structured service paths and response shapes remain available at capture time. | DATA-01 | UEFA service paths are public but undocumented and may change independently of the parser contract. | Run the bounded capture/discovery command against the configured official URLs, inspect that fixtures, groups, standings, results, and status resources are all present, and retain the resulting raw bytes locally with the emitted manifest. A failure must leave the prior accepted bundle active. |

## Validation Sign-Off

- [ ] All tasks have an automated verify command or a Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test and fixture references.
- [ ] No watch-mode flags.
- [ ] `nyquist_compliant: true` set in frontmatter after execution and verification.
- [ ] Approval: pending
