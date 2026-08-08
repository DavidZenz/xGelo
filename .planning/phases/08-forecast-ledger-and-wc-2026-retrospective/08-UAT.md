---
status: complete
phase: 08-forecast-ledger-and-wc-2026-retrospective
source: [08-01-SUMMARY.md, 08-02-SUMMARY.md, 08-03-SUMMARY.md]
started: 2026-08-08T08:05:00Z
updated: 2026-08-08T08:13:16Z
---

## Current Test

[testing complete]

## Tests

### 1. Inspect the sealed forecast ledger
expected: Open the coverage and ledger outputs; confirm 104 fixtures, separate strict and exploratory coverage, explicit missing coverage, and no retrospective probability presented as a pre-match forecast.
result: pass

### 2. Check timing and rejection provenance
expected: Valid ledger records show kickoff, generation, source-data, feature, and result cutoffs plus source commit, model version, and provenance; invalid records carry machine-readable rejection reasons.
result: pass

### 3. Review the proper-score scorecard
expected: `aggregate_scores.csv` and `match_scores.csv` report documented 1X2 Brier, log loss, RPS, goal-distribution, totals, BTTS, and exact-score metrics; the strict latest-valid headline is RPS 0.166891 over 83 fixtures.
result: pass

### 4. Review knockout and stage-reach evaluation
expected: `advancement_scores.csv` and `stage_reach_scores.csv` keep advancement and stage reach separate and score 122 knockout advancement rows plus 576 team-stage rows against actual outcomes, with strict and exploratory samples separated.
result: pass

### 5. Read the retrospective report
expected: Open `worldcup_2026_retrospective.html`; the scorecard-first report shows caveats beside headline scores, coverage labels, calibration and uncertainty, and five figures for coverage, cumulative RPS, outcome calibration, revisions, and goal diagnostics.
result: pass

### 6. Re-run the cached retrospective
expected: Run `Rscript --vanilla scripts/run_worldcup_2026_retrospective.R` from the project root; it completes from committed history and cache only and preserves the recorded source SHA and checksum-backed manifest.
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

<!-- YAML format for plan-phase --gaps consumption -->
[none yet]
