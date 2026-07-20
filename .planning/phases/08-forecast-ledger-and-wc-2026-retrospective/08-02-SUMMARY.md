---
phase: 08-forecast-ledger-and-wc-2026-retrospective
plan: "02"
status: complete
completed: 2026-07-20
requirements: [EVAL-01, EVAL-02, EVAL-03]
---

# Plan 08-02 Summary

Implemented validated proper scores and deterministic World Cup retrospective
scoring for regulation outcomes, binary goal markets, knockout advancement, and
anchored tournament stage reach.

## Results

- Strict latest-valid headline: RPS 0.166891 over 83/104 fixtures, with a 95%
  fixture-bootstrap interval of 0.150382 to 0.184135.
- Supporting strict latest-valid scores: Brier 0.489264, log loss 0.849976, and
  descriptive accuracy 69.9%.
- Paired latest-minus-first RPS: -0.001790 with a 95% interval of -0.004862 to
  0.001206; the revision effect is not distinguishable from zero here.
- Scored 122 selected knockout advancement forecasts and 576 team-stage rows
  from 12 deterministic pre-stage anchors.
- Added explicit zero-coverage aggregates for the unavailable complete joint
  scoreline distribution.
- Passed 33 scoring expectations.

## Findings

- Archived over-2.5 and BTTS market probabilities are scoreable, but archived
  top-five scorelines are not a complete joint distribution.
- No retained team-stage snapshot predates the tournament opener. Pre-stage
  anchors are available and valid; a pre-tournament stage benchmark is not.
- Calibration bins are deterministic and flag cuts below five observations.

## Verification

`Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_scoring.R")'`
passed with 33 expectations.
