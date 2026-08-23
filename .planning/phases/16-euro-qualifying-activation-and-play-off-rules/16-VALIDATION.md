---
phase: 16
slug: euro-qualifying-activation-and-play-off-rules
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-23
---

# Phase 16 - Validation Strategy

> Per-phase validation contract for EURO 2028 qualifying activation, rules, and simulation outputs.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - source-style tests in `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | approximately 120 seconds focused; full suite is workload-dependent |

## Sampling Rate

- **After every task commit:** Run the focused Phase 16 test file.
- **After every plan wave:** Run the focused Phase 16 test plus the relevant Phase 13-15 contract regressions.
- **Before `/gsd-verify-work`:** Run the full `tests/testthat` suite and record unrelated pre-existing failures separately.
- **Max feedback latency:** 120 seconds for the focused suite.

## Per-Task Verification Map

The final task map is eight tasks across four sequential waves; each row is covered by a focused automated check and the plan task's acceptance criteria.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | COMP-03, SIM-04 | T-16-01, T-16-02 | Accepted complete bundles activate; pre-draw is explicit and empty; stable fixture IDs and confirmed kickoff gate forecast eligibility. | contract/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-01-02 | 01 | 1 | COMP-03, SIM-04 | T-16-03, T-16-04 | Invalid source/rules revisions remain isolated; last accepted state and candidate warning are preserved; blocked collections are empty. | contract/revision | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-02-01 | 02 | 2 | COMP-04 | T-16-06, T-16-07 | One accepted group traces through official ranking, host allocation, place conservation, and topology metadata. | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-02-02 | 02 | 2 | COMP-04 | T-16-08, T-16-09, T-16-10 | Article 15/23 evidence, best-runner-up ordering, all three topology branches, and unsupported-rule suppression are reproducible. | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-03-01 | 03 | 3 | SIM-02 | T-16-11, T-16-13, T-16-14 | One accepted topology runs through seeded calibrated simulation; invalid handoff, missing kickoff, and pre-draw state suppress probabilities. | unit/integration/replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-03-02 | 03 | 3 | SIM-02 | T-16-12, T-16-15 | Two-host, one-host, and no-host topologies plus Nations League fallback and one/two-leg resolution replay deterministically. | unit/integration/replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)'` | no - Wave 0 | pending |
| 16-04-01 | 04 | 4 | SIM-02, SIM-04 | T-16-16, T-16-21 | Active synthetic inputs build and validate the exact nine-file bundle through the CLI and thin wrapper with hashes and lineage. | integration/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)' && Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --dry-run` | no - Wave 0 | pending |
| 16-04-02 | 04 | 4 | COMP-03, SIM-02, SIM-04 | T-16-17, T-16-18, T-16-19, T-16-20 | Pre-draw, unavailable, and revision-blocked bundles suppress projections; accepted output survives failed replacement; replay mismatch is explicit. | integration/replay/publication | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE)' && Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --replay-check` | no - Wave 0 | pending |

*Status: pending - the final plan task map is authoritative after planning.*

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase16_euro_qualifying.R` - focused contract, rules, topology, suppression, and replay tests.
- [ ] Synthetic mixed-size qualifying groups covering Article 15 ties and Article 23 exclusions.
- [ ] Synthetic host-slot and allocation-ledger fixtures covering zero, one, and two reserved places used.
- [ ] Synthetic Phase 15 eligibility handoff covering valid, incomplete, duplicate, wrong-stage, and unresolved rows.
- [ ] Synthetic source bundles covering missing kickoff, incomplete groups/fixtures, invalid hashes, and rejected post-draw replacement.
- [ ] Deterministic fixtures for all three official play-off topologies, including single-leg and two-leg resolution.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Review the first official UEFA post-draw bundle and any additional play-off draw conditions when published. | COMP-03, COMP-04 | The official post-draw source does not exist yet and future UEFA operational constraints may be published after implementation. | Confirm the accepted source URLs, raw/content hashes, fixture kickoff completeness, rules revision, and any additional draw conditions before promoting the first live bundle. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or explicit Wave 0 dependencies.
- [ ] Sampling continuity has no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test and fixture references.
- [ ] No watch-mode flags are used.
- [ ] Feedback latency remains below 120 seconds for the focused suite.
- [ ] `nyquist_compliant: true` is set after the final task map and Wave 0 validation.

**Approval:** pending planning and execution
