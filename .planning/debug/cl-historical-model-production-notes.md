# CL production model implementation notes

2026-10-27 — production-model worker

## Entry points and approval boundary

- `R/club/production_runner.R`: `phase19_run_club_production_pipeline()` is the closed, fixed-source production API used by the CLI and the club targets namespace.
- `scripts/run_phase19_club_evaluation.R` now executes that API in production mode. Missing accepted history, current identity/source authority, policy, fold review or recipe approval remains an explicit blocked result. No owner approvals have been manufactured.
- Recipe: `data/club/production_protocol/production_recipe_v2.json`; SHA-256 identity **c9817163a8b43f7cabbecb48201ce0ae0d35d65790060f7a7cc76574bf6a2482**. Accepted fold review rationale must contain `production_recipe_v2:<this hash>`.
- All 36 current UCL clubs must have accepted historical results in one connected component before any production release can be enabled. Partial forecasts are not allowed by the owner's latest decision.

## Statistical execution

- Retains the frozen `club_elo_nb` versus `club_venue_nb` independent negative-binomial candidates, 27 approved Elo parameter settings, complete 0–40 goal support and existing metric thresholds.
- Outer folds use exact reviewed fit/calibration/assessment memberships and held-out competition exclusions. Production calibration reserves max(240 rows, 20% of prior rows), moves to the first later whole kickoff batch with at least 600 actually available fit rows, then separates earlier temperature-fitting rows from later probability-view selection rows.
- Inner parameter tuning similarly advances its preferred 80% split until at least 300 strictly available fit rows and 60 later validation rows exist. Source availability is never backdated to create support.
- Temperature and raw/calibrated view selection use separate strictly prior windows. Assessment outcomes affect only paired scores. Frozen ratings do not update from assessment labels.
- Reproducibility uses separate fresh `callr` R processes for complete run-a and run-b fitting, tuning, calibration, selection and prediction. Run-b returns only per-fold execution hashes to bound memory. Final full-history refit/calibration lineage is independently repeated and verified again by the installer.
- Source validation derives paired fold summaries from accepted outcomes and generated probabilities, refits exact scoped NB coefficients/theta, regenerates calibration/view decisions and predictions, and reapplies the immutable gates.
- If Elo fails comparative superiority gates, venue incumbent retention is permitted only when every absolute coverage, data, distribution, temporal and integrity gate passes. Otherwise no selector is advanced.

## Release and refresh behavior

- Production v2 releases retain the existing fixed club root and `approved_release.csv` selector topology. Metadata and complete byte inventory are validated before model RDS deserialization. V1 fixture diagnostics remain separate and non-promotable.
- Released goal fits retain exact `rating_parameters`, parent hashes, role membership hashes and fit cutoffs. The live inference envelope can use the frozen model/calibrator/view while retaining original fit parents.
- Evidence stores the original typed current-club snapshot. Resolver validation independently verifies its immutable accepted source generation, bundle, authority and club table. It validates the fresh fixed current snapshot and compares unchanged edition, reviewed identity registry, all 36 canonical IDs and provider mapping. Routine fixture/standings refreshes therefore do not force model refitting; changed roster or identity mappings block reuse.
- Club targets now use accepted runtime fold loaders and one production execution target, with downstream actual prediction, score, evaluation, decision and release artifacts. A stable roster-identity target prevents routine live bundle updates from invalidating model execution. Existing valid v2 releases are resolved and reused.

## Checkpoints, cost and validation

- Checkpoints: `outputs/club_model/production/checkpoints/<accepted parent and code identity>/<run-a|run-b>/<fold hash>.rds`. Each completed fold binds parent identities, exact recipe, source-code fingerprint and complete execution hash. Resuming reuses only matching verified checkpoints.
- Reports: `outputs/club_model/production/{evaluation.rds,fold_metrics.csv,promotion_gates.csv,production_recipe_v2.json}`.
- No 1,681-cell grids are stored for every evaluation fixture. Complete finite-support NB grids are reconstructible from bound model/means/theta, while probabilities, means, tails, distribution identities and paired scores are persisted.
- Measured 27-setting tuning: 800 rows approximately 1.2 seconds; 16,000 rows and 400 clubs approximately 13.3 seconds. Expected 30–50-fold dual evaluation is roughly 10–25 minutes depending on actual fit support and accepted-source validation. A diagnostic fold with 800 fit rows occupies about 2.6 MB in memory. Run-b releases each full fold after obtaining its digest.
- Fixed rating decay so successive prediction boundaries advance from the last applied decay time, avoiding repeated compounding from the last result. Added one-step versus split-interval equivalence coverage.
- Explicit integer conversion protects character CSV goal columns (including 10–2 outcomes) from lexical comparisons.
- Focused passing suites: `test_phase19_production_runner.R` (56 checks including complete 1,200-match diagnostic, outcome perturbation invariance, finite-support NB equivalence, scalar/matrix Elo equivalence, stable roster binding and full36 retention gates); `test_phase19_production_targets.R` (25 checks); existing club goal-model, rating and fold protocol suites.
- Real `tar_make(names=c("club_release_state","club_selector_state"))` currently completes truthfully as `blocked / no_accepted_club_history`, without creating a selector. Genuine source/identity and exact fold owner approvals are still required before the real production run.

## Remaining integration work

Parent owns native first-observed source/identity review, accepted history publication, policy and exact fold approval, the real production run, final live dashboard verification and commits. Full-season-only pins may legitimately yield no nested temporal support; monthly first-observed snapshots are required where labels otherwise become available only after calibration/selection times. Do not weaken those cutoffs.

## First production execution, 2026-10-27

The owner accepted the historical package and exact 26-fold package before fitting. The first attempt stopped before assessment because the earliest count-supported tuning window had an aliased Elo/venue design: delayed archive publication left every training rating at base. The implementation now requires an estimable registered design when choosing the first supported prior tuning window; memberships, 27-parameter grid, model formulas, recipe, assessment labels and promotion thresholds remain fixed. A separate correction prevents a late source from quarantining unrelated timely results sharing a calendar date. New delayed-archive and rank-deficiency regressions pass; the runner suite now passes 53 assertions. The original owner review manifest is retained unchanged; execution evidence binds the corrected source-code fingerprint. The production run has restarted and completed its first cross-league folds.

The first installation attempt caught standalone-versus-bundle RDS equality comparing MASS family closure environment addresses. The corrected read-back comparison ignores only function environment addresses, while preserving exact object contents, byte inventory checks, fitted hashes and independent model/prediction validation. A production-shaped separate-file round-trip regression and dispersion-tamper check pass. The corrected runner suite passes 56 assertions; a fresh code-bound dual replay is running before installation. Elo had passed score and breadth gates but failed the frozen calibration comparison, so the declared venue incumbent is selected; its dashboard description explicitly discloses that it does not distinguish team strength.
