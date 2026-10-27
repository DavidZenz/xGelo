# Finish Champions League historical training and prediction pipeline

Date: 2026-10-27

## Goal

The CL dashboard displays genuine forecasts for supported upcoming matches using
an independently evaluated, source-backed club model and accepted live inputs.

## Execution plan

1. Acquire real OpenFootball season data from pinned upstream commits; retain
   source bytes and license evidence, parse regulation/ET/penalty semantics, and
   prepare complete club identity and historical-source review evidence.
2. Complete the historical ingestion boundary so genuine upstream formats, rather
   than a nonexistent upstream normalized CSV, feed the existing canonical audit.
3. Complete production fold execution: prior-only training/calibration, paired
   baselines, frozen evaluation gates, reproducibility, and validated release
   staging/installation. Preserve explicit failure if a candidate fails gates.
4. Connect accepted live fixtures to model prediction and the dashboard. Resolve
   regulation/home/neutral/cutoff semantics without inventing missing venue facts,
   enrichments, future evidence or historical pre-kickoff predictions.
5. Run focused regressions, the real corpus/model pipeline and dashboard browser
   checks. Commit only task changes and record metrics, coverage and limitations.

## Parallel ownership

- Parent: real source acquisition, review package, canonical history acceptance,
  production evaluation orchestration, integration and final verification.
- Historical parser worker: native OpenFootball parser and parser-focused tests.
- Live forecast worker: approved-release prediction/current-fixture boundary and
  dashboard forecast presentation, with focused tests.
- Evaluation explorer: read-only analysis of existing evaluation/release interfaces
  and the exact gaps required for a production runner.

## Constraints

- Use the frozen club-only negative-binomial/Elo candidates and promotion policy.
- Owner review must bind concrete source, identity, policy and fold evidence;
  never fabricate an owner decision or silently bypass validation gates.
- Keep provider credentials and raw football-data.org responses out of outputs.
- Existing national dashboards, model selectors and unrelated user edits remain
  outside this repair's publication scope.
- Forecast availability must remain explicit when history, identities, model
  support or pre-kickoff evidence is missing.
- David explicitly requires all 36 current clubs to have connected historical
  coverage before any predictions are enabled; partial roster forecasts cannot
  be used as a release fallback.

## Findings incorporated before model fitting

- Native upstream files use current and localized historical football.txt
  grammars; they are not normalized exchange CSVs.
- Full-season commits often postdate their matches. Retain each final supported
  fixture/result once from its first recorded Git snapshot. Exact reviewed line
  memberships partition multiple pinned snapshots without duplicating games or
  pretending the final season file existed at earlier cutoffs.
- Native name changes are joined only by explicit pending aliases or consistent
  same-fixture evidence; the owner still approves all canonical mappings.
- Reserve disjoint prior fit, temperature, view-selection and outer assessment
  rows. Source availability constrains every boundary; unsupported folds remain
  absent instead of acquiring invented evidence times.
- Independent process reruns refit and retune the model. Installation derives
  evaluation summaries from verified predictions and refits scoped NB models.
- Model authority binds the frozen evaluation source plus stable reviewed roster;
  routine live fixture refreshes have separate inference source lineage.

## Verified outcome, 2026-10-27

All five execution steps are complete. The accepted corpus has 16,277 matches and connected coverage for all 36 current clubs. Exact owner-approved folds were executed twice in separate processes; all absolute gates passed. The venue NB incumbent was retained because Elo failed its calibration gate. The immutable release and standard targets resolve ready. The standalone render and browser show 90 genuine upcoming match forecasts, zero unavailable fixtures, and intact accepted live facts. Focused regression checks, actual source/model execution, full audited inference and browser proof are complete.
