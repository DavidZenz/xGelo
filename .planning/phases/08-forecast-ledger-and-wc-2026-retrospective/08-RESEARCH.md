# Phase 8: Forecast Ledger and WC 2026 Retrospective - Research

**Researched:** 2026-07-20
**Status:** Complete

## Executive Summary

Phase 8 should reconstruct forecasts from committed dashboard artifacts rather
than trust the current archive as a historical table. The archive update helpers
replace each open fixture's row in place, but Git retains each committed version.
The compact CSV archives are suitable for enumerating the complete revision
history; the larger dashboard JSON should be read only for selected first/latest
snapshots that need full scoreline and stage-reach distributions.

The implementation can remain within the current R stack. `git log`, `git show`,
and `git rev-parse` provide commit and blob evidence; `jsonlite` parses dashboard
snapshots; `testthat` covers contracts; base R implements proper scores and the
bootstrap; and the existing R Markdown pattern renders the report. No new data
provider or model fitting belongs in this phase.

## Evidence Available in the Repository

### Forecast artifacts

- `outputs/dashboard/worldcup_prematch_forecasts.csv` stores group-match 1X2,
  expected goals, totals, BTTS, generated time, and declared cutoffs.
- `outputs/dashboard/worldcup_bracket_prematch_forecasts.csv` stores knockout
  regulation and advancement probabilities plus goal summaries.
- `outputs/dashboard/worldcup_dashboard_data.json` contains full per-match
  scoreline distributions, match forecasts, bracket paths, stage probabilities,
  and model metadata at each committed dashboard update.
- `outputs/dashboard/worldcup_stage_probabilities.csv` and
  `outputs/dashboard/worldcup_group_probabilities.csv` preserve stage-reach and
  group-position probabilities in Git history.
- The hybrid goal-model RDS files and the processed forecast feature table are
  tracked, so selected snapshots can record exact model and feature blob IDs.

### Kickoff and result evidence

- Cached ESPN scoreboards contain ISO UTC event timestamps and final scores. For
  example, the opener is recorded as `2026-06-11T19:00Z`.
- `data/raw/worldcup_2026_group_fixtures.csv` supplies stable group match IDs and
  venue metadata, while the dashboard bracket contract supplies M73-M104.
- Current archive timestamps are not sufficient by themselves. Several rows were
  first generated or updated after their fixtures. Classification must be derived
  from Git and canonical UTC kickoff data.

## Reconstruction Architecture

### 1. Canonical fixture registry

Build one 103-row registry keyed by `match_id` with stage, teams, official
scheduled kickoff UTC, final regulation score, advancement winner, and result
source. Parse cached ESPN event timestamps/results and reconcile them to xGelo
match IDs through normalized teams, date, and bracket identity. Fail on ambiguous
or duplicate mappings; do not guess.

### 2. Commit inventory

Enumerate commits reachable from a configurable source ref (default `HEAD`) that
touch either prematch archive. Record full commit SHA, committer and author ISO
times, path, blob SHA, and parent. Committer time is the authoritative publication
time; author time is retained as supporting evidence.

For every archive-bearing commit, parse the compact group and bracket CSVs and
retain every match/commit occurrence. Assign a stable `forecast_revision_id` from
the normalized forecast fields so unchanged rows across repeated commits remain
auditable without being mistaken for model updates.

### 3. Provenance closure

For each match/commit record, capture the dashboard JSON blob, applicable model
RDS blobs, processed feature-table blob, archive blob, generated time, declared
feature cutoff, and result cutoff. A selected snapshot is `verified` only when:

1. generation time is parseable and before kickoff UTC;
2. committer time is before kickoff UTC;
3. feature and result evidence is strictly pre-kickoff;
4. probabilities are finite, within `[0, 1]`, and sum correctly;
5. fixture identity matches the canonical registry; and
6. the forecast, model, feature, and selected full-distribution artifacts exist in
   the same commit and reproduce the published values within tolerance.

Date-only cutoffs are conservative: they prove pre-kickoff status only when the
date is earlier than the fixture's UTC date. Completed-result rows available in a
commit should be reconciled to canonical prior fixtures to obtain a stronger
timestamped result cutoff.

Records with credible pre-kickoff timing but incomplete artifact closure are
`documented` and exploratory-eligible. Post-kickoff generation, post-kickoff
commit, invalid probabilities, or identity conflicts are rejected and audit-only.

### 4. First/latest views

Keep the full occurrence ledger, then derive one `first_valid` and one
`latest_valid` row per match and evidence sample. Sort by committer time, generated
time, and full SHA for deterministic tie-breaking. The strict primary view uses
verified rows only; exploratory views use documented pre-kickoff rows only and
are never pooled with strict rows.

### 5. Full distributions

After the selected commit IDs are known, read dashboard JSON only for those
commits. Extract each selected match's full scoreline distribution and anchored
stage probabilities. Missing distribution artifacts produce metric-specific
missingness; do not synthesize distributions from expected goals.

## Scoring Contract

### Match outcomes

- Regulation-time 1X2 RPS is the headline, using outcome order home/draw/away and
  normalization by `K - 1`.
- Multiclass Brier score is the sum of squared class-probability errors.
- Log loss uses a documented epsilon only for numerical finiteness.
- Accuracy and modal-outcome confusion are descriptive.

### Goals and derived markets

- Joint scoreline log score evaluates the probability assigned to the observed
  regulation score.
- Marginal home-goal and away-goal distributions use discrete RPS/CRPS over the
  stored support.
- Over/under 2.5 and BTTS use binary Brier score and log loss.
- Expected-goal MAE/RMSE and exact-score hit rate remain diagnostics.
- Each target reports its own coverage because old archives may have 1X2 without
  a recoverable full scoreline distribution.

### Knockout and tournament events

- Score match-level advancement probabilities against the actual advancing team
  with binary Brier and log loss.
- Score stage-reach probabilities at anchored snapshots, not every hourly update
  as if observations were independent. Use the earliest valid tournament
  snapshot for pre-tournament stage reach and the latest valid snapshot before a
  stage begins for updated stage reach.

### Aggregation and uncertainty

- Equal-weight fixtures in the headline; stage and team-balanced cuts are
  diagnostics.
- Produce strict and exploratory aggregates separately with `n_scored`,
  `n_official`, and coverage.
- Use deterministic fixture bootstrap resampling for 95 percent intervals. Paired
  first/latest deltas resample only fixtures containing both views.
- Calibration is one-vs-rest by outcome class with deterministic quantile bins,
  at least five observations per bin, and bootstrap bands. Sparse cuts are
  labelled rather than smoothed into false precision.

## Output Contract

Use `outputs/evaluation/wc2026/` for immutable generated artifacts:

- `forecast_ledger.csv` and `forecast_ledger.rds`
- `fixture_results.csv`
- `selected_forecasts.csv` and `selected_distributions.rds`
- `rejection_summary.csv` and `bundle_manifest.csv`
- `match_scores.csv`, `aggregate_scores.csv`, `calibration_bins.csv`
- `advancement_scores.csv` and `stage_reach_scores.csv`
- `figures/*.png` and `worldcup_2026_retrospective.html`

The manifest should record row counts, schema versions, source ref/HEAD SHA, file
checksums, generation time, and code commit. The report reads only these generated
contracts; it must not rerun model fitting or query live services.

## Recommended Module Boundaries

- `R/evaluation/worldcup_ledger.R`: Git inventory, fixture reconciliation,
  provenance checks, evidence tiers, and first/latest selection.
- `R/evaluation/proper_scores.R`: pure scoring and calibration helpers.
- `R/evaluation/worldcup_retrospective.R`: tournament scoring, aggregation,
  bootstrap, artifact writing, and report data assembly.
- `R/visualization/worldcup_retrospective.R`: deterministic plots.
- `scripts/reconstruct_worldcup_2026_ledger.R`: explicit read-only Git entry point.
- `notebooks/worldcup_2026_retrospective.Rmd`: canonical report.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Current CSV appears historical but stores only the latest row per match | Reconstruct each committed archive version from Git |
| Re-reading dashboard JSON for every hourly commit is slow | Inventory with compact CSVs; extract JSON only for selected commits |
| Git timestamps or declared timestamps disagree | Retain both; strict requires every authoritative cutoff to pass |
| Same-day date-only cutoffs are ambiguous | Treat as unverified unless stronger committed evidence exists |
| Completed-match dashboard rows become degenerate actual distributions | Select only snapshots whose generation and commit predate kickoff |
| Full goal distributions are missing for an otherwise valid forecast | Report target-specific coverage; never reconstruct from means |
| Repeated stage snapshots create pseudo-replication | Score predeclared anchored snapshots only |
| Small strict sample gives unstable calibration | Minimum bin sizes, bootstrap bands, and explicit sparse warnings |
| Codebase maps predate later dashboard work | Use maps for conventions only and inspect current forecast files directly |

## Validation Architecture

Use `testthat` at three layers:

1. Pure unit fixtures for time parsing, probability checks, reason-code
   precedence, revision selection, RPS/Brier/log-loss formulas, scoreline
   marginals, and bootstrap determinism.
2. Contract fixtures representing Git archive rows, dashboard JSON, and ESPN
   events, including post-kickoff, ambiguous cutoff, missing artifact, and invalid
   probability cases.
3. A read-only repository integration test that reconstructs a bounded commit
   range and proves deterministic hashes, then an end-to-end artifact test for all
   103 official fixtures and the rendered report.

Quick tests should use synthetic data and finish in seconds. Full reconstruction
is a separate explicit test/run because Git history traversal and report rendering
are slower.

## Planning Recommendation

Use three sequential plans:

1. reconstruct and validate the immutable forecast ledger;
2. implement proper scoring, stage events, calibration, and uncertainty; and
3. integrate outputs into `targets`, render the report, and run end-to-end tests.

