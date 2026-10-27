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

## Installed production evidence

Release: `club-v2-7aff9c991e39f1b1459a9418`; manifest SHA-256: `07a59005d7bc459f93111cd0554132ebf9b1ca81b8561a91eada00bb9695f664`. Controller status is `ready`, selected model `club_venue_nb`, primary view `raw_1x2`, final cutoff `2026-10-27T00:00:00Z`, and 16,277 final training matches. Evaluation SHA-256: `a7f3400501b33d0d9246c04b66e456321eca425db4f4aaeb26236404b1b40716`. Both independent 26-fold executions matched, every absolute gate passed, and standalone-versus-bundle model read-back passed.

The fresh standard targets run completed 14 targets and skipped 8 in 7m53s. Both `club_release_state` and `club_selector_state` returned `ready`; the approved release was reused. Elo equal-fold RPS was 0.21465109 versus venue 0.23079974, but its fixed-bin calibration delta 0.02881068 exceeded the predeclared 0.01 limit, so Elo was not promoted. No thresholds or assessment memberships changed after scoring.

The standalone renderer is running its full audited rating replay and independent verification. This cold inference path is considerably slower than the numeric fitting engine; dashboard/browser verification remains pending until that actual command completes.

The initial cold live render exposed repeated canonical hashing of unchanged 343-club tables inside the audited rating engine. A scoped inference runtime now memoizes only that pure table checksum using a SHA-256 fingerprint of the complete R object (values, types and attributes). Core model code and its release fingerprint are unchanged, globals are not patched, and both numerical replay executions plus every source/coverage/cutoff validator remain active. Exact replay-object equivalence and changed-row/state tamper rejection pass. The live-forecast suite now passes 42 assertions, dashboard suite 21. Repeated table checks measured 0.01s for 100 cached calls versus 1.273s for 10 original calls. The original render was interrupted before any output installation, and the standard command restarted with this verified optimization.

## Final live verification

The restarted standalone render exited successfully with `source=accepted forecast=available clubs=36 fixtures=90 results=54`. Payload checks found 90 forecasts, zero unavailable fixtures, all 36 unique clubs, positive goal expectations, reconciled 1X2 percentages, intact completed results, the exact selected release ID, and explicit venue-baseline disclosure. Tournament progression sections remain unavailable. The information cutoff was `2026-10-27T15:28:00Z`; the validated payload was installed 634 seconds later. Browser reload confirmed available status and actual probabilities (44.0% home, 24.5% draw, 31.5% away for the venue baseline). Screenshot proof is saved in the task visualization folder. All CL task runtime checks are complete.
