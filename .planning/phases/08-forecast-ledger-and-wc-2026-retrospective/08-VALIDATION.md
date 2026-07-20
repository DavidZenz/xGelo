---
phase: 8
slug: forecast-ledger-and-wc-2026-retrospective
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-20
---

# Phase 8 - Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat |
| **Config file** | `tests/testthat.R` and existing `tests/testthat/` conventions |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "worldcup_(ledger|scoring|retrospective)")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | Quick under 30 seconds; full suite depends on existing integration tests |

## Sampling Rate

- **After every task:** Run the directly affected Phase 8 test file.
- **After every plan wave:** Run the Phase 8 quick command.
- **Before phase verification:** Run the full suite and the read-only end-to-end
  reconstruction/report command.
- **Max quick feedback latency:** 30 seconds.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 08-01-01 | 01 | 1 | LEDGER-01 | unit | `testthat::test_file("tests/testthat/test_worldcup_ledger.R")` | passed |
| 08-01-02 | 01 | 1 | LEDGER-01, LEDGER-02 | contract | `testthat::test_file("tests/testthat/test_worldcup_ledger.R")` | passed |
| 08-01-03 | 01 | 1 | LEDGER-02, LEDGER-03 | integration | `testthat::test_file("tests/testthat/test_worldcup_ledger.R")` | passed |
| 08-02-01 | 02 | 2 | EVAL-01 | unit | `testthat::test_file("tests/testthat/test_worldcup_scoring.R")` | passed |
| 08-02-02 | 02 | 2 | EVAL-01, EVAL-03 | unit | `testthat::test_file("tests/testthat/test_worldcup_scoring.R")` | passed |
| 08-02-03 | 02 | 2 | EVAL-02, EVAL-03 | integration | `testthat::test_file("tests/testthat/test_worldcup_scoring.R")` | passed |
| 08-03-01 | 03 | 3 | EVAL-03 | render fixture | `testthat::test_file("tests/testthat/test_worldcup_retrospective.R")` | passed |
| 08-03-02 | 03 | 3 | LEDGER-01..03, EVAL-01..03 | pipeline | `testthat::test_file("tests/testthat/test_worldcup_retrospective.R")` | passed |
| 08-03-03 | 03 | 3 | LEDGER-01..03, EVAL-01..03 | end-to-end | `Rscript --vanilla scripts/run_worldcup_2026_retrospective.R` | passed |

## Wave 0 Requirements

Existing testthat and R Markdown infrastructure covers the phase. Each plan adds
its own fixtures before implementation behavior is considered complete.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Main report is readable and caveats are visible beside headline scores | EVAL-03 | Visual hierarchy is not fully machine-verifiable | Open the rendered HTML and inspect the scorecard, coverage labels, tables, and five core figures |

## Validation Sign-Off

- [x] Every planned task has an automated check.
- [x] No three consecutive tasks lack automated verification.
- [x] No new test framework is required.
- [x] Watch-mode commands are excluded.
- [x] Phase 8 quick suite passes.
- [x] Full suite passes (753 checks).
- [x] End-to-end ledger and report reproduce from the recorded source ref.

**Approval:** Phase 8 validation complete on 2026-07-20.
