# Phase 8: Forecast Ledger and WC 2026 Retrospective - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase reconstructs the forecasts that genuinely existed before each 2026
World Cup kickoff, records their provenance and revision history, scores the
completed tournament, and publishes a reproducible retrospective. It does not
tune the incumbent, implement challenger models, or use 2026 outcomes for model
selection; those activities begin in later phases.

</domain>

<decisions>
## Implementation Decisions

### Forecast Validity

- **D-01:** A strict forecast requires dual proof: its generation time, every
  source-data cutoff, and the Git commit containing it must precede the official
  scheduled kickoff in UTC. There is no post-kickoff grace period.
- **D-02:** Retain every committed forecast snapshot. Derive `first_valid` and
  `latest_valid` views rather than overwriting revisions.
- **D-03:** Forecasts should be available as early as feasible. Score
  `latest_valid` as the primary pre-match prediction and report `first_valid` as
  a secondary forecast-evolution comparison.
- **D-04:** Use tiered evidence. `verified` means the exact model and input
  artifacts are reproducible; `documented` means credible timestamps and
  metadata exist but artifact closure is incomplete. Only `verified` records
  enter the strict sample.

### Missing and Late Forecasts

- **D-05:** The exploratory sample may score only credibly pre-kickoff forecasts
  with incomplete verification, such as late commits or missing artifacts.
  Forecasts generated after kickoff are audit-only and never scored.
- **D-06:** Never impute a missing forecast. Report forecast quality only over
  eligible records and operational coverage as `scored fixtures / all official
  fixtures` beside every aggregate result.
- **D-07:** Rejected records receive one stable machine-readable primary reason
  plus all failed validation flags so compound provenance failures remain visible.
- **D-08:** Strict results are the headline. Exploratory results appear beside
  them as a sensitivity view with coverage and score deltas; the samples are
  never blended.

### Primary Scoreboard

- **D-09:** Regulation-time 1X2 Ranked Probability Score is the headline metric.
  Multiclass Brier score and log loss are prominent supporting proper scores;
  winner-pick accuracy is descriptive only.
- **D-10:** Weight every fixture equally in tournament aggregates. Report group
  and knockout stages separately, with team-balanced summaries as diagnostics.
- **D-11:** Evaluate the full joint scoreline and marginal home/away goal
  distributions with proper scores. Score totals and both-teams-to-score
  probabilities with Brier scores. Expected-goal error and exact-score hit rate
  are secondary diagnostics.
- **D-12:** Report bootstrap 95 percent intervals for aggregate proper scores and
  paired `first_valid` versus `latest_valid` differences. Flag sparse stage or
  outcome-class estimates and show uncertainty bands on calibration plots.

### Report Structure

- **D-13:** The canonical publication is a reproducible rendered HTML report
  backed by an immutable CSV/RDS ledger and metric tables. The dashboard is not
  the source of truth for this retrospective.
- **D-14:** Open with a compact scorecard containing strict coverage, headline
  RPS, uncertainty, and key caveats. Follow with provenance, detailed scores,
  calibration, and match-level evidence.
- **D-15:** Expose every official fixture in the report with validity status,
  first/latest probabilities, result, lead time, rejection reason, score
  contributions, and source commit identifier.
- **D-16:** Keep five visual families in the main report: forecast coverage flow,
  cumulative RPS, outcome calibration, first-to-latest forecast changes, and goal
  distribution diagnostics. Put dense stage/class diagnostics in appendices.

### The Agent's Discretion

The planner may choose the exact ledger column order and storage helpers, the
stable rejection-reason precedence, the bootstrap implementation, the rendering
tool already compatible with the repository, and chart styling. Those choices
must preserve the decisions above and remain reproducible in the existing R and
`targets` workflow.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone Contract

- `.planning/ROADMAP.md` - Phase 8 goal, requirements, dependencies, and success
  criteria.
- `.planning/REQUIREMENTS.md` - LEDGER-01..03 and EVAL-01..03 acceptance scope.
- `.planning/PROJECT.md` - Open-data constraints, sealed-2026 decision, and v2.0
  evaluation principles.
- `.planning/research/SUMMARY.md` - Literature synthesis and recommended v2.0
  evaluation architecture.

### Existing Forecast Contracts

- `R/visualization/worldcup_dashboard.R` - Current match and bracket pre-match
  archive creation, update, and attachment behavior.
- `scripts/update_worldcup_dashboard.R` - Existing dashboard snapshot metadata,
  checksums, and update flow.
- `R/forecast/monte_carlo.R` - Full scoreline distribution and derived 1X2,
  totals, BTTS, and expected-goal outputs available for scoring.
- `R/forecast/output.R` - Existing fixture-level forecast schema, model version,
  and generation timestamp behavior.
- `tests/testthat/test_worldcup_dashboard.R` - Current archive and dashboard
  export invariants that the ledger must account for.
- `tests/testthat/test_pipeline.R` - Existing probability and scoreline coherence
  tests.

### Historical Data Evidence

- `outputs/dashboard/worldcup_prematch_forecasts.csv` - Current group-stage
  pre-match archive, to be audited rather than assumed valid.
- `outputs/dashboard/worldcup_bracket_prematch_forecasts.csv` - Current knockout
  pre-match archive, to be audited rather than assumed valid.
- `data/raw/espn/` - Cached tournament result payloads used to establish observed
  outcomes and fixture completion evidence.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `make_dashboard_prematch_forecast_rows()` and
  `update_dashboard_bracket_prematch_forecast_archive()` provide the current
  archive schemas and match identifiers, but their output must pass the new
  provenance rules rather than being accepted wholesale.
- `simulate_fixture()` already exposes a complete scoreline distribution plus
  1X2, totals, BTTS, expected-goal, and exact-score summaries needed by EVAL-01.
- Dashboard update metadata already carries `generated_at`, `snapshot_path`, and
  `snapshot_checksum`, which can seed the richer ledger provenance contract.

### Established Patterns

- The repository uses file-based CSV/RDS contracts, project-relative paths,
  explicit `run_*()` entry points, deterministic seeds, and `targets`
  orchestration.
- Public R functions use snake_case, validate required columns early, return
  structured data, and place durable tests under `tests/testthat/`.
- Validation functions fail fast for invalid required inputs while artifact
  audits return structured diagnostics for recoverable record-level failures.

### Integration Points

- Add ledger reconstruction and scoring in dedicated evaluation modules rather
  than coupling them to dashboard rendering.
- Register immutable ledger, metric-table, plot, and report artifacts in the
  root `_targets.R` pipeline.
- Treat Git history, current dashboard archives, cached result payloads, and
  model/feature manifests as evidence inputs to reconstruction.
- Keep dashboard consumption downstream of approved retrospective artifacts.

</code_context>

<specifics>
## Specific Ideas

- Preserve the whole forecast lifecycle: the earliest available prediction is
  valuable evidence, while the latest verified prediction remains the primary
  statement of model quality.
- Missing forecast coverage is itself a result and must sit beside performance,
  not disappear into filtering or synthetic probabilities.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within the Phase 8 boundary.

</deferred>

---

*Phase: 08-forecast-ledger-and-wc-2026-retrospective*
*Context gathered: 2026-07-20*
