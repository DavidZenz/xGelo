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
| 13-01-01 | 01 | 1 | DATA-01, DATA-02 | T-13-01 / T-13-02 | Required resource classes, schema, provenance, and raw-byte hashes are validated before acceptance. | unit | focused source-contract command | no - W0 | pending |
| 13-01-02 | 01 | 1 | DATA-04 | T-13-03 / T-13-04 | Manual fallback audit fields and explicit review state are required; mixed official/fallback bundles are rejected. | unit | focused source-contract command | no - W0 | pending |
| 13-02-01 | 02 | 2 | DATA-03 | T-13-05 | Stable team identity, source display name, aliases, edition ID, and visible normalized-name fallback warnings round-trip. | unit | focused registry command | no - W0 | pending |
| 13-02-02 | 02 | 2 | COMP-01 | T-13-06 | Registry lifecycle, blocked overlay, pinned model release, source bundle, and explicit EURO pre-draw output target are enforced. | unit/integration | focused registry command | no - W0 | pending |
| 13-03-01 | 03 | 2 | DATA-01, DATA-02 | T-13-01 / T-13-02 | One captured structured UEFA fixture/standings sample replays into the accepted bundle without rendered-page parsing. | integration | focused source-contract command | no - W0 | pending |

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
