# Phase 8: Forecast Ledger and WC 2026 Retrospective - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions are captured in `08-CONTEXT.md`; this log preserves the
> alternatives considered.

**Date:** 2026-07-20
**Phase:** 08-forecast-ledger-and-wc-2026-retrospective
**Areas discussed:** Forecast validity, missing and late forecasts, primary
scoreboard, report structure

---

## Forecast Validity

| Decision | Options considered | Selected |
|----------|--------------------|----------|
| Evidence required for strict scoring | Dual proof; Git proof only; timestamp proof only | Dual proof |
| Permitted lead time | Any pre-kickoff time; at least 60 minutes; fixed 24 hours | Any pre-kickoff time |
| Incomplete artifact closure | Tiered evidence; reject entirely; metadata sufficient | Tiered evidence |
| Revision history | Every committed snapshot; first and latest; latest only | Every committed snapshot |

**User's choice:** Require generation time, source cutoffs, and source commit to
precede kickoff. Retain the full history, score `latest_valid` primarily, and
compare `first_valid` secondarily.

**Notes:** The user explicitly wants forecasts produced as early as possible.
Only fully reproducible records are strict; credible but incomplete pre-kickoff
records are documented separately.

---

## Missing and Late Forecasts

| Decision | Options considered | Selected |
|----------|--------------------|----------|
| Exploratory eligibility | Incomplete pre-kickoff only; all usable records; none | Incomplete pre-kickoff only |
| Missing fixtures | Separate quality and coverage; uniform penalty; silent exclusion | Separate quality and coverage |
| Multiple failures | Primary reason plus all flags; one reason; free text | Primary reason plus all flags |
| Exploratory prominence | Parallel sensitivity; appendix only; combined estimate | Parallel sensitivity |

**User's choice:** Score only credibly pre-kickoff but incompletely verified
records exploratorily. Never impute missing forecasts or blend exploratory and
strict samples.

**Notes:** Post-kickoff generations remain audit-only. Every aggregate must show
its eligible fixture count against all official fixtures.

---

## Primary Scoreboard

| Decision | Options considered | Selected |
|----------|--------------------|----------|
| Headline 1X2 metric | RPS; multiclass Brier; no single headline | RPS |
| Tournament aggregation | Equal fixture weight; stage weighted; team balanced | Equal fixture weight |
| Goal forecast emphasis | Full distributions; expected-goal error; exact-score accuracy | Full distributions |
| Uncertainty | Bootstrap intervals; Bayesian intervals; point estimates | Bootstrap intervals |

**User's choice:** Lead with regulation-time RPS, equal weighting, full
distribution scoring, and bootstrap 95 percent intervals.

**Notes:** Brier score and log loss remain prominent. Accuracy, expected-goal
error, exact-score hit rate, and team-balanced summaries are diagnostics rather
than promotion criteria.

---

## Report Structure

| Decision | Options considered | Selected |
|----------|--------------------|----------|
| Canonical artifact | HTML report plus data; dashboard first; notebook first | HTML report plus data |
| Opening structure | Scorecard first; audit first; tournament chronology | Scorecard first |
| Match-level evidence | Complete table; strict only; selected examples | Complete table |
| Visual density | Focused core plus appendix; minimal; exhaustive main report | Focused core plus appendix |

**User's choice:** Publish a reproducible report and immutable data bundle, lead
with a coverage-aware scorecard, expose every fixture, and keep dense diagnostic
cuts in appendices.

**Notes:** The five main visual families are coverage flow, cumulative RPS,
outcome calibration, first-to-latest changes, and goal-distribution diagnostics.

## The Agent's Discretion

- Exact ledger column order and helper organization.
- Rejection-reason precedence within the fixed primary-reason-plus-flags policy.
- Bootstrap implementation and report rendering details compatible with the
  existing R stack.
- Chart styling and appendix organization.

## Deferred Ideas

None.
