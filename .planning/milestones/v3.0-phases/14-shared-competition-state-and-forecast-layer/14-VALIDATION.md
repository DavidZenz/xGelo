---
phase: 14
slug: shared-competition-state-and-forecast-layer
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-16
last_audited: 2026-08-17
---

# Phase 14 - Validation Strategy

> Per-task validation contract for the shared competition-state, calibration-release, point-in-time feature, and forecast backend.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - direct `testthat::test_dir` |
| **Quick run command** | `Rscript --vanilla -e 'files <- Sys.glob("tests/testthat/test_phase14_*.R"); invisible(lapply(files, function(f) testthat::test_file(f, stop_on_failure=TRUE)))'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Task-local latency target** | Each focused task command must finish within 60 seconds; the repository-wide Plan 14-20 phase gate is intentionally exempt and runs once at the end. |

## Sampling Rate

- **After every task commit:** Run the exact task-local command in the map below.
- **After every plan wave:** Run the focused Phase 14 file(s) and directly affected Phase 12/13 regressions named by that wave's final task.
- **At Task 14-05-01:** Replay the original complete calibration-revision graph in a fresh R process and reproduce the completed fail-closed disposition; this task has no release resume signal.
- **At Tasks 14-21-01/02:** Run the focused remediation suite after the tracer and again after writing the complete separate candidate graph; require one manifest-bound `outer_fold_fits.csv` row per outer tournament with exact nested lineage/support, deterministic optimizer seed/convergence, replay-sufficient fitted parameters, and `1e-12` outer-probability replay.
- **At Tasks 14-22-01/02:** In a fresh process, source the test-only reference helper rather than any Phase 14 producer code; independently rebuild the frozen raw panel, every nested selection, every selected strictly-prior outer fit, and all 630 probability triples before scoring. Run outer-label leakage, forged fitted parameters, forged training IDs, and self-consistently rehashed leaked-output attacks before the human checkpoint and again before the sole release resume signal.
- **At Task 14-20-02 / before `$gsd-verify-work`:** Run `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'`; the full repository suite must be green.
- **Max focused feedback latency:** 60 seconds. The final repository suite may exceed this because it is the explicit phase gate, not a task-development feedback loop.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 0 | STATE-02 | T-14-01-S / T-14-01-T | D-02 lifecycle/completion axes, score semantics, and correction-stable identity are frozen before implementation. | contract/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates fixture/test | ⬜ pending |
| 14-01-02 | 01 | 0 | STATE-01 | T-14-01-T | Four-part keyed standings and exact/rank-only/aggregate/absent reconciliation states are frozen. | contract/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates fixture/test | ⬜ pending |
| 14-01-03 | 01 | 0 | STATE-03, FORECAST-03 | T-14-01-T | Separate last-five/EWMA products and before/equal/after/date-only cutoffs are frozen. | contract/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_form.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_cutoffs.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates fixture/tests | ⬜ pending |
| 14-02-01 | 02 | 0 | FORECAST-01 | T-14-02-S / T-14-02-T / T-14-02-I | Descriptor parsing creates hash-valid temporary roots, distinguishes raw/fitted identities, and commits no binary fixture. | contract/security | `Rscript --vanilla -e 'source("tests/testthat/helper_phase14_release.R"); root &lt;- tempfile("phase14-release-"); dir.create(root); raw &lt;- phase14_materialize_release_fixture_root("tests/fixtures/phase14/raw_release", file.path(root,"raw")); fitted &lt;- phase14_materialize_release_fixture_root("tests/fixtures/phase14/calibrated_release", file.path(root,"fitted")); stopifnot(isTRUE(phase14_validate_release_fixture_root(raw$trusted_root)), isTRUE(phase14_validate_release_fixture_root(fitted$trusted_root)), !identical(raw$release_id,fitted$release_id), !identical(raw$calibrator_sha256,fitted$calibrator_sha256), !identical(raw$primary_probability_view,fitted$primary_probability_view), isTRUE(phase14_assert_no_binary_release_fixtures("tests/fixtures/phase14")))'` | ❌ W0 - task creates descriptors/helper | ⬜ pending |
| 14-02-02 | 02 | 0 | FORECAST-01 | T-14-02-S / T-14-02-T / T-14-02-I | One guarded release test surface covers selector, bundle, empirical gate, forgery, split-pin, and rollback cases. | contract/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates test | ⬜ pending |
| 14-03-01 | 03 | 0 | FORECAST-02 | T-14-03-S / T-14-03-T / T-14-03-D | G=40, dual simplices, uncertainty, suppression, model_data_cutoff, and D-20 lineage contracts are frozen. | contract/unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates fixture/test | ⬜ pending |
| 14-03-02 | 03 | 0 | STATE-04 | T-14-03-T / T-14-03-I | Active-required shared failure fan-out, inactive optional xG audit without fan-out, edition-local isolation, foreign-join rejection, and replay identity are frozen. | contract/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE)'` | ❌ W0 - task creates fixture/test | ⬜ pending |
| 14-04-01 | 04 | 1 | FORECAST-01 | T-14-04-T / T-14-04-S / T-14-04-I | Exact open_nb_incumbent/updating/open_core slice has 630 rows and unique fixtures, strict chronology, and no WC2026 labels. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase12_calibration.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-04-02 | 04 | 1 | FORECAST-01 | T-14-04-T / T-14-04-S / T-14-04-I | Unchanged vetoes produce one hash-bound empirical pass-or-block disposition without authority mutation. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); source("R/release/calibration_revision.R"); stopifnot(isTRUE(phase14_validate_calibration_revision("outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision")))'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-05-01 | 05 | 2 | FORECAST-01 | T-14-05-T / T-14-05-E / T-14-05-R / T-14-05-I | Fresh-process validation reproduces the exact original block and proves raw authority, sealed holdout, and no mutation; there is no release pass path. | checkpoint/integration | `Rscript --vanilla -e 'source("R/release/calibration_revision.R"); root &lt;- "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision"; stopifnot(isTRUE(phase14_validate_calibration_revision(root))); g &lt;- read.csv(file.path(root,"calibration_gate.csv"), stringsAsFactors=FALSE, check.names=FALSE); stopifnot(nrow(g)==1L, identical(as.character(g$disposition[[1L]]),"CALIBRATION_RELEASE_BLOCKED"), identical(as.character(g$reason_codes[[1L]]),"rps_veto|calibration_not_improved"), !isTRUE(g$calibration_promoted[[1L]]), identical(as.character(g$fit_status[[1L]]),"fitted"), identical(as.character(g$primary_probability_view[[1L]]),"raw_1x2"), isTRUE(g$chronology_valid[[1L]]), !isTRUE(g$holdout_labels_used[[1L]]), !isTRUE(g$authority_mutated[[1L]]))'` | ✅ immutable evidence exists | ✅ complete fail-closed |
| 14-21-01 | 21 | 3 | FORECAST-01 | T-14-21-S / T-14-21-T / T-14-21-I / T-14-21-R / T-14-21-D | Exact grids/transforms/seed schedule, strictly nested tournament chronology, exact inner training maps/support, deterministic convergence metadata, replay-sufficient fitted parameters, unchanged inner criteria, and raw fallback are test-first and fail closed. | tracer/unit/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_remediation.R", stop_on_failure=TRUE)'` | ❌ task creates module/test | ⬜ pending |
| 14-21-02 | 21 | 3 | FORECAST-01 | T-14-21-T / T-14-21-I / T-14-21-E / T-14-21-R | Exactly 12 manifest-bound outer fit rows record lineage/support/recipe/seed/convergence/parameters and replay all 630 probabilities at `1e-12` before unchanged Phase 12 vetoes, post-pass-only final fitting, holdout exclusion, and authority checks. | integration/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_remediation.R", stop_on_failure=TRUE); source("R/release/calibration_remediation.R"); root &lt;- "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"; stopifnot(isTRUE(phase14_validate_calibration_remediation(root, require_promoted=FALSE)))'` | ❌ task creates candidate graph including outer_fold_fits.csv | ⬜ pending |
| 14-22-01 | 22 | 4 | FORECAST-01 | T-14-22-S / T-14-22-T / T-14-22-I / T-14-22-E / T-14-22-R | A test-only helper that never sources/calls Phase 14 producer code independently rebuilds the predeclared contract/raw panel, every nested selection, all 12 selected strictly-prior fits, fitted parameters, fallback reasons, and all 630 probabilities before unchanged scoring; outer-label leakage, forged parameters/training IDs, and self-consistently rehashed leaked outputs all fail. | independent/security/adversarial | `Rscript --vanilla -e 'source("tests/testthat/helper_phase14_calibration_remediation_acceptance.R"); root &lt;- "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"; stopifnot(isTRUE(reference_validate_phase14_calibration_candidate(root, require_promoted=TRUE))); testthat::test_file("tests/testthat/test_phase14_calibration_remediation_acceptance.R", stop_on_failure=TRUE)'` | ❌ task creates helper/acceptance test | ⬜ pending |
| 14-22-02 | 22 | 4 | FORECAST-01 | T-14-22-T / T-14-22-I / T-14-22-E / T-14-22-R | Human acknowledgement is reachable only after a fresh independent semantic reconstruction, all 630 probability comparisons, the complete adversarial suite, and a zero-reason pass; it cannot override failure. | checkpoint/security | `Rscript --vanilla -e 'source("tests/testthat/helper_phase14_calibration_remediation_acceptance.R"); root &lt;- "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"; stopifnot(isTRUE(reference_validate_phase14_calibration_candidate(root, require_promoted=TRUE))); testthat::test_file("tests/testthat/test_phase14_calibration_remediation_acceptance.R", stop_on_failure=TRUE)'` | ❌ dependency - 14-22-01 | ⬜ pending |
| 14-06-01 | 06 | 5 | FORECAST-01 | T-14-06-T / T-14-06-E / T-14-06-S | Sole runtime resolver accepts selector_path, validates trusted manifest/objects, and returns exact identity/cutoffs. | unit/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase12_release.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-06-02 | 06 | 5 | FORECAST-01 | T-14-06-T / T-14-06-E / T-14-06-S | Calibrated bundle validation binds fitted gate, chronology, model_data_cutoff, object identities, and unchanged G=40. | unit/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase12_release.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-07-01 | 07 | 6 | FORECAST-01 | T-14-07-T / T-14-07-S / T-14-07-R | Exact thirteen-file candidate validates before object load and after identity load without durable mutation. | integration/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-07-02 | 07 | 6 | FORECAST-01 | T-14-07-T / T-14-07-S / T-14-07-R | Atomic no-overwrite installation is revalidated from the exact internal manifest while authority remains unmoved. | integration/security | `Rscript --vanilla -e 'source("R/release/release_contract.R"); x &lt;- preflight_phase12_approved_release(trusted_root="outputs/releases", release_manifest_path="outputs/releases/phase14-open-nb-incumbent-calibrated-v1/release_manifest.csv"); stopifnot(identical(x$release_id,"phase14-open-nb-incumbent-calibrated-v1")); testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-08-01 | 08 | 7 | FORECAST-01 | T-14-08-T / T-14-08-E / T-14-08-R | Selector schema/self-hash/path/hash validation rejects traversal, symlink, ambiguity, and stale authority. | unit/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-08-02 | 08 | 7 | FORECAST-01 | T-14-08-T / T-14-08-E / T-14-08-R | Non-authoritative selector candidate validates against the immutable release while durable authority stays unchanged. | integration/security | `Rscript --vanilla -e 'source("R/release/calibration_revision.R"); s &lt;- read.csv("outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2/approved_release_candidate.csv", stringsAsFactors=FALSE); stopifnot(isTRUE(phase14_validate_release_selector(s, trusted_root="outputs/releases")), nrow(s)==1L)'` | ❌ generated by 14-08 | ⬜ pending |
| 14-09-01 | 09 | 8 | FORECAST-01, STATE-04 | T-14-09-T / T-14-09-E / T-14-09-R | Selector and exactly two registry pins stage/promote/rollback as one byte-exact authority transaction. | integration/security | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_calibration_release.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_competition_registry.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-02 | ⬜ pending |
| 14-09-02 | 09 | 8 | FORECAST-01, STATE-04 | T-14-09-T / T-14-09-E / T-14-09-R | Fresh selector-path resolution proves one calibrated identity/cutoff and two equal revisioned pins. | integration/security | `Rscript --vanilla -e 'source("R/release/release_contract.R"); source("R/competition/source_contracts.R"); source("R/competition/team_identity.R"); source("R/competition/edition_registry.R"); x &lt;- phase14_resolve_approved_release(selector_path="outputs/releases/approved_release.csv", trusted_release_root="outputs/releases"); r &lt;- load_competition_edition_registries(project_root="."); stopifnot(nrow(r$registries)==2L, length(unique(r$registries$model_release_id))==1L, unique(r$registries$model_release_id)=="phase14-open-nb-incumbent-calibrated-v1", identical(x$release_identity$release_id,"phase14-open-nb-incumbent-calibrated-v1"), !is.na(as.Date(x$model_data_cutoff)))'` | ❌ generated by 14-09 | ⬜ pending |
| 14-10-01 | 10 | 9 | STATE-02 | T-14-10-S / T-14-10-T | Source/normalized v2 preserves D-02 axes, split scores, identity, and missing-source fail-closed semantics. | unit/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_source_contracts.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-10-02 | 10 | 9 | STATE-01 | T-14-10-T / T-14-10-I | Official standings v2 and schema-aware hashes retain nullable metrics and reject partial/foreign/forged links. | unit/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_publication_hashes.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-10-03 | 10 | 9 | STATE-01, STATE-02 | T-14-10-S / T-14-10-T / T-14-10-I | Source handoff emits truthful v2 tables while preserving raw provenance and prior replay paths. | integration/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_integration.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-11-01 | 11 | 10 | STATE-01, STATE-02 | T-14-11-T / T-14-11-R | Temporary fourteen-target graph validates completely with unchanged durable snapshots/provenance. | integration/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-11-02 | 11 | 10 | STATE-01, STATE-02 | T-14-11-T / T-14-11-D | Every promotion-index failure restores all fourteen bytes and leaves unrelated authority/history paths untouched. | integration/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_publication_transaction.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-12-01 | 12 | 11 | STATE-01, STATE-02 | T-14-12-T / T-14-12-R | Exact fourteen-target snapshot/stage/promote/fresh-validate transaction preserves raw provenance and truthful EURO empties. | integration/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_publication_transaction.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_publication_integration.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-13-01 | 13 | 12 | STATE-04 | T-14-13-S / T-14-13-T | Durable crosswalk is one-to-one, correction-stable, hash-bound, and collision-reviewed. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-13-02 | 13 | 12 | STATE-02 | T-14-13-S / T-14-13-T | Complete batch validates D-02 lifecycle/completion, scores, count flags, evidence, identity, and foreign links. | unit/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_match_state.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_competition_registry.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-14-01 | 14 | 13 | STATE-01 | T-14-14-T / T-14-14-S | Cutoff-safe universal metrics carry exact snapshot keys and never claim provisional order is official. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-14-02 | 14 | 13 | STATE-01 | T-14-14-T / T-14-14-S | Same-bundle official reconciliation blocks aggregate/partial mismatch and warns rank-only mismatch. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_standings.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-15-01 | 15 | 14 | STATE-03 | T-14-15-T / T-14-15-I | Edition-only and all-senior last-five views remain distinct, truthful, deduplicated, and non-imputed. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_form.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-15-02 | 15 | 14 | STATE-03, FORECAST-03 | T-14-15-T / T-14-15-I | Optional national-team xG accepts only shot-derived point-in-time evidence; current Austria/Germany values are unavailable/NA with audit fields, and club rolling form is rejected. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_form.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_cutoffs.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-01 | ⬜ pending |
| 14-16-01 | 16 | 15 | STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03 | T-14-16-S / T-14-16-T / T-14-16-I | Austria/Germany maps to the feature contract, Elo resolves strictly before kickoff, Elo-only reaches G=40 with xG unavailable, xG-active suppresses, club form is rejected, and only required active failures fan out. | tracer/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE)'` | ❌ W0 dependencies - 14-03 | ⬜ pending |
| 14-17-01 | 17 | 16 | FORECAST-01, FORECAST-02, FORECAST-03 | T-14-17-T / T-14-17-D | Full batch has no fixture loss, derives evidence sufficiency from immutable active predictors, audits inactive xG, and propagates cutoffs, G=40, dual views, uncertainty, and D-20 lineage. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_forecast_layer.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-03 | ⬜ pending |
| 14-17-02 | 17 | 16 | STATE-04, FORECAST-01, FORECAST-03 | T-14-17-T / T-14-17-I | Required active shared-input failure invalidates both; inactive optional xG absence is audited; edition-local failures remain isolated; the script starts with fixed seed `14017L`; repeated dry-runs/replays are byte/hash identical and mutate nothing. | integration/determinism | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE); source("R/competition/state_bundle.R"); stopifnot(is.function(phase14_build_competition_state_batch))'` | ❌ W0 dependency - 14-03 | ⬜ pending |
| 14-18-01 | 18 | 17 | STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03 | T-14-18-T / T-14-18-I | Exact NL bundle proves production Austria/Germany adapter/Elo cutoff, Elo-only G=40 with unavailable xG, xG-active suppression, lineage, hashes, and rollback. | integration/durable | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase14_forecast_layer.R", stop_on_failure=TRUE); source("R/competition/state_bundle.R"); stopifnot(isTRUE(phase14_validate_competition_state_bundle("outputs/competition/uefa_nations_league_2026_27")))'` | ❌ W0 dependencies - 14-03 | ⬜ pending |
| 14-19-01 | 19 | 18 | STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03 | T-14-19-S / T-14-19-I | Exact eleven-path EURO bundle proves pre_draw emptiness, no NL copy/fabrication, model_data_cutoff lineage, and rollback. | integration/durable | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE); source("R/competition/state_bundle.R"); stopifnot(isTRUE(phase14_validate_competition_state_bundle("outputs/competition/uefa_euro_2028_qualifying")))'` | ❌ W0 dependency - 14-03 | ⬜ pending |
| 14-20-01 | 20 | 19 | STATE-04, FORECAST-03 | T-14-20-T / T-14-20-I | Active-required shared failures fan out, inactive optional xG does not, edition-local isolation holds, and every-target rollback preserves accepted bundles and unrelated paths. | integration/regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE); testthat::test_file("tests/testthat/test_phase13_refresh_failure.R", stop_on_failure=TRUE)'` | ❌ W0 dependency - 14-03 | ⬜ pending |
| 14-20-02 | 20 | 19 | STATE-04, FORECAST-03 | T-14-20-T / T-14-20-I / T-14-20-D | Full repository gate proves deterministic replay, row/inventory equality, cutoff propagation, no durable mutation, and regressions. | full repository | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` | ❌ W0 dependencies - 14-01/02/03 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/fixtures/phase14/match_lifecycle_cases.csv` - D-01 through D-04 and D-19 lifecycle, completion, score, count-flag, and stable-identity cases.
- [ ] `tests/fixtures/phase14/standings_reconciliation_cases.csv` - D-05 through D-08 exact/rank-only/aggregate/partial/absent/foreign-bundle cases.
- [ ] `tests/fixtures/phase14/point_in_time_history.csv` - last-five/EWMA scope plus one-second/equality/date-only/missing-time boundaries.
- [ ] `tests/testthat/test_phase14_match_state.R` - STATE-02 canonical state, accepted schema, transaction, crosswalk, and batch tests.
- [ ] `tests/testthat/test_phase14_standings.R` - STATE-01 reducer, reconciliation, schema, hash, and rollback tests.
- [ ] `tests/testthat/test_phase14_form.R` - STATE-03 competition/all-senior display and model-form tests.
- [ ] `tests/testthat/test_phase14_cutoffs.R` - FORECAST-03 strict cutoff and replay-lineage tests.
- [ ] `tests/fixtures/phase14/raw_release/model_contract.json` - raw fallback descriptor.
- [ ] `tests/fixtures/phase14/raw_release/release_manifest.csv` - raw fallback manifest descriptor.
- [ ] `tests/fixtures/phase14/calibrated_release/model_contract.json` - fitted calibration descriptor.
- [ ] `tests/fixtures/phase14/calibrated_release/release_manifest.csv` - fitted calibration manifest descriptor.
- [ ] `tests/testthat/helper_phase14_release.R` - temporary trusted-root materialization, hash validation, and binary-fixture exclusion helpers.
- [ ] `tests/testthat/test_phase14_calibration_release.R` - FORECAST-01 calibration, immutable release, selector, and dual-pin tests.
- [ ] `tests/fixtures/phase14/forecast_fixture.csv` - G=40, suppression, uncertainty, cutoff, and lineage cases.
- [ ] `tests/fixtures/phase14/edition_isolation_cases.csv` - shared versus edition-local failures, foreign joins, and replay expectations.
- [ ] `tests/testthat/test_phase14_forecast_layer.R` - FORECAST-02 release/feature/G=40/uncertainty/status tests.
- [ ] `tests/testthat/test_phase14_state_bundle.R` - STATE-04 tracer, candidate, isolation, rollback, and replay tests.

`wave_0_complete` remains `false` until all seventeen entries exist and their Wave 0 task commands pass. Production assertions may skip only while their one named API is absent; owning implementation tasks must source the API and satisfy the unchanged assertions.

## Manual-Only Verifications

All Phase 14 behaviors have automated verification. Task 14-05-01 is recorded as a completed fail-closed checkpoint with no release signal. Task 14-22-02 is the only blocking human release-resume checkpoint; it is presented only after the independent Task 14-22-01 command passes, and the human cannot override a failed or blocked result.

## Internal Map Validation

- [x] 41 unique final task IDs found across 22 plans.
- [x] 41 per-task rows present above; every row has an exact automated command.
- [x] All seven phase requirements are represented: STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03.
- [x] All 21 CONTEXT.md decisions are cited by the plan set; the decision-coverage gate reports 21/21.
- [x] All Wave 0 test/fixture/helper dependencies are listed explicitly.
- [x] Plan 14-21 declares the dedicated `outer_fold_fits.csv` evidence artifact and Plan 14-22 declares a separate independent reference helper; both are covered by exact task-local commands.
- [x] Independent acceptance is semantic rather than hash-circular: nested selections, fitted parameters, training IDs, and all 630 probabilities are reconstructed before unchanged scoring, with self-consistently rehashed leakage attacks required to fail.
- [x] Config is correctly recorded as `none - direct testthat::test_dir`.
- [x] No watch-mode command is used.
- [x] Final repository suite is an explicit Task 14-20-02 automated phase gate.
- [x] `nyquist_compliant: true` is justified by the complete task-to-command map.
- [ ] `wave_0_complete: true` awaits execution, file creation, and passing Wave 0 commands.

## Multi-Source Coverage Audit

| Source | ID | Required item | Plan coverage | Status |
|--------|----|---------------|---------------|--------|
| GOAL | - | One edition-aware state, form, and pre-match forecast engine reused by both competitions without future leakage. | 14-13 through 14-20, led by tracer 14-16 | COVERED |
| REQ | STATE-01 | Universal standings plus official rank/reconciliation. | 14-01, 14-10 through 14-12, 14-14, 14-18/19 | COVERED |
| REQ | STATE-02 | Distinct lifecycle/completion and regulation/final/shootout semantics. | 14-01, 14-10 through 14-13, 14-18/19 | COVERED |
| REQ | STATE-03 | Separate competition/all-international form and explicit windows/cutoffs. | 14-01, 14-15 through 14-19 | COVERED |
| REQ | STATE-04 | Isolated edition state with shared identity, Elo/xG, and history. | 14-03, 14-09, 14-13, 14-16 through 14-20 | COVERED |
| REQ | FORECAST-01 | Approved calibrated release with model identity, model_data_cutoff, and feature cutoff. | 14-02, 14-04/05, 14-21/22, 14-06 through 14-09, 14-16 through 14-20 | COVERED |
| REQ | FORECAST-02 | Calibrated 1X2, expected goals, modal score, bounded distribution, and uncertainty. | 14-03, 14-16 through 14-19 | COVERED |
| REQ | FORECAST-03 | Point-in-time feature safety with no future state/outcomes. | 14-01, 14-03, 14-15 through 14-20 | COVERED |
| RESEARCH | R-01 | Empirical calibration is pass-or-block; thresholds and final-label boundary remain unchanged. | 14-04/05 and 14-21/22 | COVERED |
| RESEARCH | R-02 | Multiple immutable releases resolve only through an explicit hash-backed selector. | 14-06 through 14-09 | COVERED |
| RESEARCH | R-03 | Accepted fixture/result/standings schema evolves before reducers and regenerates the complete Phase 13 graph. | 14-10 through 14-12 | COVERED |
| RESEARCH | R-04 | Stable canonical match identity uses a durable crosswalk excluding mutable scores/status/order. | 14-01, 14-13 | COVERED |
| RESEARCH | R-05 | Same-day/equal evidence fails strict cutoff; date-only evidence needs an earlier date. | 14-01, 14-15 through 14-17 | COVERED |
| RESEARCH | R-06 | Approved G=40 distribution stays unchanged while fitted calibration changes only consumer 1X2. | 14-03, 14-06/07, 14-16 through 14-18 | COVERED |
| RESEARCH | R-07 | Immutable release active predictors control evidence sufficiency: current Elo-only forecasting audits unavailable national-team xG, while an xG-active release requires accepted shot-derived point-in-time xG and otherwise suppresses. | 14-15 through 14-18, 14-20 | COVERED |
| RESEARCH | R-08 | Full grids remain local/compact publication is top-10 plus audit metadata; model loads/predicts once per batch. | 14-03, 14-16 through 14-20 | COVERED |
| RESEARCH | R-09 | Failures of active-required shared inputs fan out to both editions; inactive optional xG absence is audited; edition-local failures stay diagnostic/local. | 14-03, 14-16/17, 14-20 | COVERED |
| RESEARCH | R-10 | No new package, live API client, database, server API, or dashboard/public batch behavior. | All plans; explicit prohibitions and artifact inventories | COVERED |
| CONTEXT | D-01 | Canonical and source match statuses remain separate. | 14-01, 14-10, 14-13 | COVERED |
| CONTEXT | D-02 | Lifecycle and completion method are orthogonal axes. | 14-01, 14-10, 14-13 | COVERED |
| CONTEXT | D-03 | Regulation/final/shootout scores and winner remain separate. | 14-01, 14-10, 14-13 | COVERED |
| CONTEXT | D-04 | Standings/form eligibility flags remain separate. | 14-01, 14-10, 14-13 | COVERED |
| CONTEXT | D-05 | Computed metrics and official rank/points coexist with reconciliation status. | 14-01, 14-10, 14-14 | COVERED |
| CONTEXT | D-06 | Universal metrics plus later ruleset-adapter boundary. | 14-01, 14-14 | COVERED |
| CONTEXT | D-07 | Four-part standings snapshot key and same-bundle cutoff. | 14-01, 14-14 | COVERED |
| CONTEXT | D-08 | Aggregate mismatch blocks, rank-only warns, absent official is provisional. | 14-01, 14-14, 14-18 | COVERED |
| CONTEXT | D-09 | Last-five display and 12-match EWMA are distinct. | 14-01, 14-15 | COVERED |
| CONTEXT | D-10 | Competition form is selected-edition only with honest sample count. | 14-01, 14-15 | COVERED |
| CONTEXT | D-11 | All-senior form includes friendlies and excludes unplayed/pure awards. | 14-01, 14-15 | COVERED |
| CONTEXT | D-12 | Strict exclusive kickoff cutoff and auditable evidence lineage. | 14-01, 14-15 through 14-17 | COVERED |
| CONTEXT | D-13 | Every fixture is available or retained with a suppression reason. | 14-03, 14-16/17 | COVERED |
| CONTEXT | D-14 | Contract-controlled calibrated consumer 1X2 retains raw audit values. | 14-03, 14-21/22, 14-06, 14-16/17 | COVERED |
| CONTEXT | D-15 | Narrow calibrated release revision and atomic dual registry repin. | 14-04/05, 14-21/22, 14-06 through 14-09 | COVERED |
| CONTEXT | D-16 | Preserve complete 0:40 distribution and derive deterministic top-10/modal score. | 14-03, 14-16 through 14-18 | COVERED |
| CONTEXT | D-17 | Quantitative uncertainty and explicit unavailable metadata. | 14-03, 14-16 through 14-18 | COVERED |
| CONTEXT | D-18 | Shared-input allowlist and edition-scoped derived state. | 14-03, 14-16 through 14-20 | COVERED |
| CONTEXT | D-19 | Stable canonical match ID and deduplicated dual lineage. | 14-01, 14-13 | COVERED |
| CONTEXT | D-20 | Complete forecast identity/cutoff/hash/method/generation lineage. | 14-03, 14-16 through 14-20 | COVERED |
| CONTEXT | D-21 | Shared failure invalidates both; edition-local failure remains local; no copied state. | 14-03, 14-16/17, 14-20 | COVERED |
| REVISION | CR-01 | Preserve Plan 14-04 artifacts/block, Phase 12 thresholds/selectors/authority, registry pins, suppression semantics, and the sealed WC2026 boundary. | 14-05, 14-21, 14-22 | COVERED |
| REVISION | CR-02 | Freeze raw identity, warm-up/shrunk temperature, regularized class-specific vector scaling, exact grids, and explicit raw fallback. | 14-21 | COVERED |
| REVISION | CR-03 | Select inside each outer tournament using nested strictly earlier tournaments, persist exact lineage/support/seed/convergence/replay-sufficient fit parameters, and independently rebuild every nested selection, selected outer fit, and all 630 probabilities before unchanged authoritative vetoes. | 14-21 producer evidence plus 14-22 independent reference reconstruction | COVERED |
| REVISION | CR-04 | Treat exploratory numbers as non-authoritative, fit only after outer pass, and forbid WC2026 labels throughout. | 14-21, independently checked by 14-22 | COVERED |
| REVISION | CR-05 | Persist a separate immutable remediation hash graph including per-outer fit evidence and emit a release resume signal only after independent semantic reconstruction rejects outer-label leakage, fitted-parameter/training-ID forgery, and self-consistently rehashed leaked outputs. | 14-21/22; downstream starts at 14-06 only through 14-22 | COVERED |

Deferred Nations League outcome rules, EURO qualification/play-off topology, simulations, dashboards, hourly refresh, and atomic public publication are excluded by decision and are not source-audit gaps.

## Validation Sign-Off

- [x] All tasks have `<automated>` verification and mapped Wave 0 dependencies.
- [x] Sampling continuity has no task without an automated check.
- [x] Task-local commands are focused; the one long repository-wide command is reserved for the final phase gate.
- [x] Security enforcement is ASVS L1 with high-severity blockers represented in every plan's threat model.
- [x] T-14-21-T and T-14-22-T explicitly cover forged nested lineage, fitted parameters, probabilities, and producer/self-hash circularity; T-14-17-T covers fixed-seed deterministic replay.
- [x] `nyquist_compliant: true` set after internal map validation.
- [ ] Wave 0 tests/fixtures created and green.
- [ ] Full repository suite green.

**Approval:** pending execution
