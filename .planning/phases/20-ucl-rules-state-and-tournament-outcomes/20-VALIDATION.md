---
phase: 20
slug: ucl-rules-state-and-tournament-outcomes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-21
---

# Phase 20 — Validation Strategy

> This is the execution contract. `wave_0_complete` and `nyquist_compliant` remain false until the recorded commands have actually passed; planning does not claim runtime evidence.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none — repository tests live under `tests/testthat/` |
| **Quick run command** | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` |
| **Adversarial run command** | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` |
| **Aggregate command** | `rtk Rscript --vanilla scripts/verify_phase20_contracts.R` |
| **Full suite command** | `rtk Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary", stop_on_failure=TRUE)'` |
| **Diff hygiene** | `rtk git diff --check` |
| **Estimated runtime** | focused target below 120 seconds; full suite measured during execution |

## Typed Result and Zero-Failure Contract

The fixed CLI and aggregate verifier return a machine-readable `phase20_result_contract` with these fields: `status`, `exit_code`, `mechanics_complete`, `production_eligible`, `human_needed`, `human_needed_reason`, `original_parent_reason`, `production_blocked_reason`, `normalization_error`, `unresolved`, `failures`, `warnings`, `skips`, `unexpected_failures`, `mapped_threat_ids`, `selector_changed`, and `incumbent_changed`.

Allowed successful result classes are:

| Status | Conditions | Exit |
|---|---|---:|
| `mechanics_complete` | Focused mechanics and artifact checks pass; no unresolved production dependency is in scope. | 0 |
| `production_human_needed` | Mechanics pass; `human_needed_reason` is exactly one of `phase18_authority_missing`, `phase19_cr01_cr05_repair_pending`, or `phase19_selector_not_accepted`; `original_parent_reason` is retained; `production_eligible=false`; selector/incumbent unchanged. | 0 |
| `production_blocked` | Fixed authority validation returns a typed blocked reason from the accepted Phase 18/19 parent graph, or `production_blocked_reason=unrecognized_parent_reason` with `normalization_error=true`; no candidate write, selector change, or incumbent change. | 0 |
| `unresolved_draw_procedure` | Rules evidence is valid for Articles 17–22/Annex B, but the edition-specific draw procedure record has `accepted=false`, `complete=false`, and `unresolved_reason=missing_edition_draw_procedure`; exact draw-conditioned paths are suppressed. | 0 |

`unexpected_failure` is the only failure class for the expected blocker path. Any non-empty `failures`, `warnings`, `skips`, `unexpected_failures`, `selector_changed=true`, `incumbent_changed=true`, unmapped critical/high threat ID, or `production_eligible=true` for fixture/blocked evidence exits non-zero. The verifier must emit the successful blocked/human-needed result above with zero failures, warnings, and skips; a known human-needed blocker is evidence, not a test failure.

### Phase 19 parent-reason normalization

The production consumer normalizes parent diagnostics through one closed mapping before constructing `phase20_result_contract`. It always retains the unmodified parent value in `original_parent_reason`; `human_needed_reason` is never populated with a Phase 19 implementation reason.

| Original parent reason | Normalized status | Normalized field/value | Required disposition |
|---|---|---|---|
| `no_accepted_current_ucl` | `production_human_needed` | `human_needed_reason=phase18_authority_missing` | No forecast/output/selector mutation; preserve the original reason. |
| `no_accepted_club_history` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | No forecast/output/selector mutation; preserve the original reason. |
| `protocol_policy_not_approved` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | No forecast/output/selector mutation; preserve the original reason. |
| `fold_inventory_not_approved` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | No forecast/output/selector mutation; preserve the original reason. |
| `phase19_cr01_roster_mismatch` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | CR-01 probe must reject the forged roster. |
| `phase19_cr02_rating_replay_unverified` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | CR-02 probe must reject tampered replay evidence. |
| `phase19_cr03_fold_identity_unverified` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | CR-03 probe must reject the forged fold. |
| `phase19_cr04_probability_lineage_unverified` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | CR-04 probe must reject the forged probability/calibrator lineage. |
| `phase19_cr05_unbacked_installer` | `production_human_needed` | `human_needed_reason=phase19_cr01_cr05_repair_pending` | CR-05 probe must reject the unbacked installer. |
| `phase19_selector_not_accepted` | `production_human_needed` | `human_needed_reason=phase19_selector_not_accepted` | No selector-authorized release may be consumed. |
| `NA`, empty, or any unlisted value | `production_blocked` | `production_blocked_reason=unrecognized_parent_reason`, `normalization_error=true` | Preserve the original value, emit a diagnostic/error, and never classify it as `human_needed`. |

The five CR probes must exercise both their exact failure reasons and the current `no_accepted_club_history` production state. The aggregate verifier asserts that only the three normalized `human_needed_reason` values above are allowed; every other parent reason is `production_blocked` or an explicit error.

## Official Evidence Schema

The pinned rules sidecar is exactly eight rows/objects: seven regulation documents plus one separate edition-specific draw-procedure evidence row. Every row has exactly these fields: `document_id`, `article_or_annex`, `edition_id`, `canonical_domain`, `canonical_article`, `source_url`, `artifact_url`, `source_url_role`, `reviewer`, `reviewed_at_utc`, `raw_sha256`, `canonical_sha256`, `accepted`, `complete`, and `unresolved_reason`. For the seven regulations, `source_url=artifact_url` is the canonical official UEFA document URL; for the unresolved draw row, `source_url` is the Article 19 governing-rule anchor, `artifact_url=null`, and `source_url_role=governing_rule_anchor_for_missing_artifact`.

| `document_id` | `article_or_annex` | `edition_id` | `canonical_domain` | `canonical_article` | `source_url` / `artifact_url` |
|---|---|---|---|---|---|
| `article_17` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-17-Match-system-league-phase-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-17-Match-system-league-phase-Online` |
| `article_18` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-18-Equality-of-points-league-phase-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-18-Equality-of-points-league-phase-Online` |
| `article_19` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-19-Draw-system-knockout-phase-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-19-Draw-system-knockout-phase-Online` |
| `article_20` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-20-Match-system-knockout-phase-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-20-Match-system-knockout-phase-Online` |
| `article_21` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online` |
| `article_22` | `article` | `ucl_2026_27` | `documents.uefa.com` | `Article-22-Match-system-final-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-22-Match-system-final-Online` |
| `annex_b` | `annex` | `ucl_2026_27` | `documents.uefa.com` | `Annex-B-UEFA-Champions-League-Competition-System-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Annex-B-UEFA-Champions-League-Competition-System-Online` |
| `draw_procedure_2026_27` | `draw_procedure` | `ucl_2026_27` | `documents.uefa.com` | `Article-19-Draw-system-knockout-phase-Online` | `https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-19-Draw-system-knockout-phase-Online` (governing-rule anchor; `artifact_url=null`) |

The exact document IDs are `article_17`, `article_18`, `article_19`, `article_20`, `article_21`, `article_22`, `annex_b`, and `draw_procedure_2026_27`; no missing, foreign-edition, stale-hash, or partial regulation record may be accepted. The seven regulation rows require non-empty reviewer/timestamp and 64-hex raw/canonical hashes with `accepted=true`, `complete=true`, and `unresolved_reason=null`. The draw-procedure row is exactly `accepted=false`, `complete=false`, `reviewer=unreviewed`, `reviewed_at_utc=null`, `raw_sha256=null`, `canonical_sha256=null`, and `unresolved_reason=missing_edition_draw_procedure`; exact draw-conditioned paths remain suppressed in that state.

## Wave 0 Requirements

| Task ID | Requirement | Contract | Threat Ref | Automated command | File exists | Status |
|---|---|---|---|---|---|---|
| 20-W0-01 | UCLRULE-01 | Exact 36-club/144-fixture graph, rank bands, and empty/partial-state rejection | T20-00-01, T20-01-01, T20-02-01 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-02 | UCLRULE-02 | Article 18 criterion trace, interim first-five behavior, late-evidence interval, and no display-order closure | T20-00-01, T20-02-02 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-03 | UCLRULE-03 | Eight opponents, 4/4 venues, matchday, kickoff, lifecycle, score, stable IDs, and lineage | T20-00-01, T20-01-01, T20-02-01 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-04 | UCLOUT-01 | CR-01..CR-05 authority gate, strict cutoff, immutable completed forecast, fixture non-promotion | T20-00-02, T20-01-02, T20-02-03, T20-05-01, T20-05-02 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-05 | UCLOUT-02 | Fixed results, eligible-open sampling, full rank/band/cut-line conservation | T20-03-01, T20-04-02 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-06 | UCLOUT-03 | Legal rank paths and exact accepted same-edition draw conditioning | T20-03-02, T20-03-03 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-07 | UCLOUT-04 | Two-leg aggregate/no-away-goals/leg-order/ET/penalty and neutral-final matrix | T20-04-01 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-08 | UCLOUT-05 | Stage accounting, unresolved states, exact sums, and monotone progression | T20-04-02 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |
| 20-W0-09 | UCLOUT-06 | Normal/reverse/repeat canonical bytes and protected incumbents | T20-01-03, T20-02-04, T20-03-04, T20-04-03, T20-05-03 | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ❌ Wave 0 | ⬜ pending |

Wave 0 must create the focused suite, the full-cardinality fixture builder, the pinned rules/draw fixture, the approved-release fixture helper, and CLI/targets wiring probes before implementation waves. The RED transcript for both focused and adversarial scaffolds is written to `20-00-RED.md`; later GREEN tasks read it and record their own durable RED evidence before implementation.

## Exact 19-Item Edge-Probe Inventory

The aggregate verifier asserts `expected_edge_probe_count == 19` and exact set equality for these IDs. Each row has a stable test symbol and verifier symbol; no wildcard or prose-only edge coverage is accepted.

| Edge ID | Deterministic item | Test symbol | Verifier symbol | Expected result | Threat IDs |
|---|---|---|---|---|---|
| EDGE-01 | Empty source/club/fixture state | `phase20_test_edge_01_empty_source_blocked()` | `phase20_verify_edge_01_empty_source_blocked()` | typed `blocked`, no inferred rows | T20-01-01, T20-02-01 |
| EDGE-02 | Missing club in accepted graph | `phase20_test_edge_02_missing_club()` | `phase20_verify_edge_02_missing_club()` | typed `blocked`, cardinality failure | T20-02-01 |
| EDGE-03 | Missing fixture edge | `phase20_test_edge_03_missing_fixture()` | `phase20_verify_edge_03_missing_fixture()` | typed `blocked`, no synthesis | T20-01-01, T20-02-01 |
| EDGE-04 | Duplicate fixture identity | `phase20_test_edge_04_duplicate_fixture()` | `phase20_verify_edge_04_duplicate_fixture()` | typed `blocked`, duplicate rejected | T20-02-01 |
| EDGE-05 | Self-fixture or foreign endpoint | `phase20_test_edge_05_endpoint_integrity()` | `phase20_verify_edge_05_endpoint_integrity()` | typed `blocked`, endpoint rejected | T20-02-01 |
| EDGE-06 | Wrong opponent/home-away degree | `phase20_test_edge_06_degree_split()` | `phase20_verify_edge_06_degree_split()` | typed `blocked`, 8 and 4/4 invariant rejected | T20-01-01, T20-02-01 |
| EDGE-07 | Missing venue evidence | `phase20_test_edge_07_missing_venue()` | `phase20_verify_edge_07_missing_venue()` | typed `blocked`, no enrichment inference | T20-01-01, T20-02-01 |
| EDGE-08 | Missing or equal-to-kickoff cutoff | `phase20_test_edge_08_kickoff_cutoff()` | `phase20_verify_edge_08_kickoff_cutoff()` | `cutoff_violation` or `kickoff_unconfirmed` | T20-02-03 |
| EDGE-09 | Lifecycle/score contradiction | `phase20_test_edge_09_lifecycle_score()` | `phase20_verify_edge_09_lifecycle_score()` | typed `blocked`, canonical score owner rejects | T20-02-01 |
| EDGE-10 | Foreign edition/source lineage | `phase20_test_edge_10_foreign_lineage()` | `phase20_verify_edge_10_foreign_lineage()` | typed `blocked`, lineage mismatch | T20-01-01, T20-03-03 |
| EDGE-11 | Reverse input row order | `phase20_test_edge_11_reverse_order()` | `phase20_verify_edge_11_reverse_order()` | canonical bytes identical | T20-01-03, T20-03-04, T20-04-03 |
| EDGE-12 | Integer score/probability precision | `phase20_test_edge_12_precision_bounds()` | `phase20_verify_edge_12_precision_bounds()` | invalid/non-finite values rejected; exact sums retained | T20-02-01, T20-04-02 |
| EDGE-13 | Late-evidence interval touches rank 8 | `phase20_test_edge_13_rank8_interval()` | `phase20_verify_edge_13_rank8_interval()` | shared interval; dependent band/path suppressed | T20-02-02, T20-03-02 |
| EDGE-14 | Late-evidence interval touches rank 24 | `phase20_test_edge_14_rank24_interval()` | `phase20_verify_edge_14_rank24_interval()` | shared interval; dependent band/path suppressed | T20-02-02, T20-03-02 |
| EDGE-15 | Missing late Article 18 evidence | `phase20_test_edge_15_late_evidence_missing()` | `phase20_verify_edge_15_late_evidence_missing()` | typed unresolved reason; no lexical/provider/random rank | T20-02-02 |
| EDGE-16 | Settled row versus eligible-open sampler | `phase20_test_edge_16_settled_sampling()` | `phase20_verify_edge_16_settled_sampling()` | settled bytes fixed; only eligible open row sampled | T20-03-01 |
| EDGE-17 | Completed forecast merge immutability | `phase20_test_edge_17_completed_forecast_immutable()` | `phase20_verify_edge_17_completed_forecast_immutable()` | prior pre-kickoff bytes preserved | T20-02-04 |
| EDGE-18 | Missing/stale/partial/foreign/contradictory draw evidence | `phase20_test_edge_18_draw_evidence_states()` | `phase20_verify_edge_18_draw_evidence_states()` | typed unresolved; exact draw path suppressed | T20-03-03 |
| EDGE-19 | Two-leg/no-away-goals/ET/penalty/neutral-final matrix | `phase20_test_edge_19_knockout_matrix()` | `phase20_verify_edge_19_knockout_matrix()` | editioned stage resolver accepts only legal topology | T20-04-01 |

## Canonical Phase 19 CR-01..CR-05 Dependency Gate

Each gate is a hard consumer precondition. The Phase 20 result is `production_human_needed` or `production_blocked` until source-backed evidence passes; a fixture result can prove mechanics but cannot satisfy the gate.

| CR | Source-backed contract | Required public symbols/probes | Missing/failed result |
|---|---|---|---|
| CR-01 | Accepted current-UCL roster equals the fixed Phase 18 source roster/table identity and binds the snapshot identity | `phase19_validate_current_ucl_club_snapshot()`, `phase20_probe_cr01_forged_roster_rejected()` | `phase19_cr01_roster_mismatch` → human_needed/blocked |
| CR-02 | Rating predictions are deterministically replayed from accepted snapshots/parameters and the replay digest covers rows, state, and audit | `phase19_replay_club_ratings()`, `phase19_club_goal_validate_rating_evidence()`, `phase20_probe_cr02_rating_replay_tamper_rejected()` | `phase19_cr02_rating_replay_unverified` → human_needed/blocked |
| CR-03 | Every supplied fold is the exact accepted registry/protocol row, not a self-described fold with the right ID | `phase19_validate_club_fold_source_evidence()`, `phase19_club_evaluation_source_by_fold()`, `phase20_probe_cr03_forged_fold_rejected()` | `phase19_cr03_fold_identity_unverified` → human_needed/blocked |
| CR-04 | Goal predictions and calibrated views are regenerated from the exact fit/calibrator source rows and compared byte-for-byte | `phase19_validate_club_goal_predictions()`, `phase19_validate_club_calibrator()`, `phase20_probe_cr04_forged_probability_calibrator_rejected()` | `phase19_cr04_probability_lineage_unverified` → human_needed/blocked |
| CR-05 | Production installation consumes a source-backed staged release with the complete typed parent graph and production eligibility | `phase19_install_production_club_release()`/`phase19_install_club_release()`, `phase19_validate_club_release()`, `phase20_probe_cr05_unbacked_installer_rejected()` | `phase19_cr05_unbacked_installer` → human_needed/blocked |

The aggregate verifier fails on any CR probe that is absent, unexpectedly passing, unmapped, or reported as accepted without source-backed evidence. The known Phase 19 re-review state is an allowed typed blocker, not a waiver.

## Exact Target Graph Contract

The target namespace is exactly:

`ucl20_accepted_source`, `ucl20_rules_evidence`, `ucl20_state`, `ucl20_forecast_ledger`, `ucl20_league_simulation`, `ucl20_knockout_paths`, `ucl20_stage_events`, `ucl20_outcome_candidate`, `ucl20_outcome_manifest`, `ucl20_build_status`.

The directed edge set is exactly:

1. `ucl20_accepted_source -> ucl20_state`
2. `ucl20_rules_evidence -> ucl20_state`
3. `ucl20_state -> ucl20_forecast_ledger`
4. `ucl20_state -> ucl20_league_simulation`
5. `ucl20_forecast_ledger -> ucl20_league_simulation`
6. `ucl20_rules_evidence -> ucl20_league_simulation`
7. `ucl20_league_simulation -> ucl20_knockout_paths`
8. `ucl20_rules_evidence -> ucl20_knockout_paths`
9. `ucl20_knockout_paths -> ucl20_stage_events`
10. `ucl20_rules_evidence -> ucl20_stage_events`
11. `ucl20_stage_events -> ucl20_outcome_candidate`
12. `ucl20_forecast_ledger -> ucl20_outcome_candidate`
13. `ucl20_league_simulation -> ucl20_outcome_candidate`
14. `ucl20_outcome_candidate -> ucl20_outcome_manifest`
15. `ucl20_outcome_manifest -> ucl20_build_status`.

The verifier asserts exact set equality, no duplicate target names, no national/legacy authority edge, no wildcard-only match, and typed blocked/unresolved propagation from `ucl20_accepted_source` or `ucl20_rules_evidence` to `ucl20_build_status`.

## Exact Public Symbol Contract

The production export registry is exactly this set (no missing or extra public entrypoint):

`ucl_validate_schedule`, `ucl_build_state`, `ucl_apply_article18`, `ucl_build_forecast_ledger`, `ucl_run_simulation`, `ucl_aggregate_rank_distributions`, `ucl_enumerate_legal_knockout_paths`, `ucl_validate_draw_artifact`, `ucl_resolve_two_leg_tie`, `ucl_resolve_final`, `ucl_aggregate_stage_events`, `ucl_validate_progression_reconciliation`, `ucl_validate_outcome_candidate`, `ucl_write_outcome_candidate`, `ucl_outcomes_manifest`, `ucl20_parse_args`, `ucl20_build_outcomes`, `phase20_result_contract`, `phase20_verify_contracts`.

All non-exported helpers use the demonstrable private convention `.ucl_*` (or are local closures); names beginning `ucl_` that are not in the registry are verifier failures. The test-only CR probes and EDGE test/verifier symbols live under `tests/` or the aggregate verifier inventory and are not production exports. The aggregate verifier first reads the explicit registry, then enumerates top-level functions and excludes only `.ucl_*` names and local closures; it must not use a broad prefix filter or silently omit another `ucl_*` symbol.

## Exact Ten-File Outcome Registry

The fixed output root is `outputs/competition/ucl_2026_27/outcomes`. The aggregate verifier asserts exact set equality, schema equality, one-to-one artifact paths, and no collisions for these ten files:

| Output path | Exact schema columns |
|---|---|
| `competition_topology.csv` | `edition_id,stage_id,slot_id,seed_slot_id,parent_stage_id,ruleset_version,ruleset_sha256,source_bundle_id,row_sha256` |
| `league_schedule.csv` | `edition_id,fixture_id,matchday,home_club_id,away_club_id,venue_id,kickoff_utc,lifecycle_status,score_regulation_home,score_regulation_away,score_final_home,score_final_away,score_shootout_home,score_shootout_away,source_bundle_id,source_row_sha256,row_sha256` |
| `tie_break_trace.csv` | `edition_id,tie_group_id,criterion_order,criterion_id,subset_before,subset_after,evidence_status,source_artifact_ids,decisive,rank_interval_min,rank_interval_max,ruleset_version,ruleset_sha256,row_sha256` |
| `projected_standings.csv` | `edition_id,club_id,played,wins,draws,losses,goals_for,goals_against,goal_difference,points,ranking_phase,rank_interval_min,rank_interval_max,qualification_band,evidence_status,source_bundle_id,ruleset_sha256,row_sha256` |
| `projected_rankings.csv` | `edition_id,club_id,rank,rank_interval_min,rank_interval_max,rank_status,decisive_trace_id,qualification_band,source_bundle_id,ruleset_sha256,row_sha256` |
| `knockout_paths.csv` | `edition_id,path_id,stage_event_id,stage_id,seed_slot_id,participant_a,participant_b,leg_order,leg_1_venue_id,leg_2_venue_id,aggregate_regulation_home,aggregate_regulation_away,aggregate_final_home,aggregate_final_away,extra_time_applied,extra_time_home,extra_time_away,penalty_applied,penalty_home,penalty_away,draw_policy_id,draw_artifact_id,draw_artifact_sha256,path_status,unresolved_reason,source_artifact_ids,source_bundle_id,ruleset_sha256,simulation_run_id,row_sha256` |
| `progression_probabilities.csv` | `edition_id,club_id,stage_id,probability,status,source_bundle_id,ruleset_sha256,draw_artifact_sha256,simulation_count,seed,run_id,row_sha256` |
| `fixture_forecast_ledger.csv` | `edition_id,fixture_id,home_club_id,away_club_id,kickoff_utc,forecast_status,suppression_reason,model_release_id,model_sha256,calibrator_sha256,feature_cutoff_utc,prob_home,prob_draw,prob_away,xg_home,xg_away,likely_score,source_bundle_id,row_sha256` |
| `simulation_metadata.csv` | `run_id,edition_id,source_bundle_id,ruleset_version,ruleset_sha256,model_release_id,model_sha256,calibrator_sha256,draw_policy_id,draw_artifact_id,draw_artifact_sha256,information_cutoff_utc,algorithm_version,simulation_count,seed,path_policy_id,path_policy_count,authority_mode,production_eligible,status,run_sha256` |
| `outcomes_manifest.csv` | `manifest_id,edition_id,run_id,artifact_path,artifact_schema_version,artifact_sha256,parent_id,parent_sha256,authority_mode,production_eligible,information_cutoff_utc,canonical_hash_version,manifest_sha256` |

Every artifact carries edition/source/rules identity, typed status, and row/table hashes as appropriate; timestamps and filesystem order are excluded from canonical identity. The manifest lists exactly the ten relative paths above and binds every artifact hash plus source/rules/model/draw/cutoff/seed parents.

`knockout_paths.csv` is the durable carrier for stage-event detail; no eleventh `stage_events.csv` is added. `participant_a`/`participant_b` carry participants, `leg_order` plus `leg_1_venue_id`/`leg_2_venue_id` carry leg and venue, the four aggregate columns carry regulation/final totals, the `extra_time_*` and `penalty_*` fields carry ET/penalty application and scores, `draw_*` fields carry draw identity, and `source_artifact_ids`/`source_bundle_id`/`ruleset_sha256`/`simulation_run_id` carry source lineage. The stage-event and outcome tests assert exact column-set equality, typed values for every field, and row hashes over those fields before any manifest can be accepted.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Test type | Automated command | Status |
|---|---|---:|---|---|---|---|---|
| 20-W0-01 | 20-00 | 0 | UCLRULE-01..03 | T20-00-01, T20-01-01, T20-02-01 | contract | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-02 | 20-00 | 0 | UCLRULE-02 | T20-00-01, T20-02-02 | adversarial | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-03 | 20-00 | 0 | UCLRULE-03 | T20-00-01, T20-02-01 | contract | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-04 | 20-00 | 0 | UCLOUT-01 | T20-00-02, T20-01-02, T20-02-03, T20-05-01, T20-05-02 | authority regression | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-05 | 20-00 | 0 | UCLOUT-02 | T20-03-01, T20-04-02 | integration | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-06 | 20-00 | 0 | UCLOUT-03 | T20-03-02, T20-03-03 | adversarial | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-07 | 20-00 | 0 | UCLOUT-04 | T20-04-01 | unit | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-08 | 20-00 | 0 | UCLOUT-05 | T20-04-02 | integration | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-W0-09 | 20-00 | 0 | UCLOUT-06 | T20-01-03, T20-02-04, T20-03-04, T20-04-03, T20-05-03 | replay | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'`; `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase20_adversarial_regression.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-01-01 | 20-01 | 1 | all tracer requirements | T20-01-01, T20-01-02, T20-01-03 | end-to-end tracer | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` | ⬜ pending |
| 20-02-02 | 20-02 | 2 | UCLRULE-01..03, UCLOUT-01 | T20-02-01, T20-02-02, T20-02-03, T20-02-04, T20-02-05 | rules/ledger | focused plus Phase 14 tests | ⬜ pending |
| 20-03-02 | 20-03 | 3 | UCLOUT-02..03 | T20-03-01, T20-03-02, T20-03-03, T20-03-04 | simulation | focused plus Phase 14/16 tests | ⬜ pending |
| 20-04-02 | 20-04 | 4 | UCLOUT-04..06 | T20-04-01, T20-04-02, T20-04-03, T20-04-04 | outcomes | focused plus Phase 15/16 tests | ⬜ pending |
| 20-05-02 | 20-05 | 5 | all nine requirements | T20-05-01, T20-05-02, T20-05-03, T20-05-04, T20-05-05, T20-05-06 | aggregate | `rtk Rscript --vanilla scripts/verify_phase20_contracts.R` | ⬜ pending |

## Threat-ID Mapping Gate

The canonical threat namespace is `T20-{plan}-{ordinal}` as written in each plan’s STRIDE register. The aggregate verifier loads this table and fails when a critical/high threat is absent from the mapping, maps to no test symbol, maps to no verifier symbol, or appears under an alias.

| Critical/high threat IDs | Required mapped surfaces |
|---|---|
| `T20-00-01`, `T20-00-02` | Wave 0 fixture/evidence and authority probes |
| `T20-01-01`, `T20-01-02`, `T20-01-03` | tracer schedule, CR-01..CR-05 authority, replay/protected-byte symbols |
| `T20-02-01`, `T20-02-02`, `T20-02-03`, `T20-02-04` | schedule, Article 18, ledger authority/cutoff, completed-byte symbols |
| `T20-03-01`, `T20-03-02`, `T20-03-03`, `T20-03-04` | settled sampling, legal paths, draw evidence, RNG/replay symbols |
| `T20-04-01`, `T20-04-02`, `T20-04-03` | stage topology, reconciliation, manifest/replay symbols |
| `T20-05-01`, `T20-05-02`, `T20-05-03`, `T20-05-04`, `T20-05-05` | fixed roots, fixture publication, replay, zero-failure aggregate, metadata secrecy symbols |

## Sampling Rate and Human-Needed Status

- **After every task commit:** run the focused Phase 20 file plus the directly touched analog suite through a fresh `rtk Rscript` process; record RED or GREEN transcript before the next implementation task.
- **After every plan wave:** run the focused Phase 20 suite, adversarial suite, Phase 14 match-state/standings/forecast/state-bundle suites, Phase 15 Nations League suite, and Phase 16 EURO qualifying suite.
- **Before verification:** run `rtk Rscript --vanilla scripts/verify_phase20_contracts.R`, then the full `rtk Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary", stop_on_failure=TRUE)'`; aggregate success may be `production_human_needed` or `production_blocked` only when the typed result contract has zero failures/warnings/skips and protected bytes are unchanged.
- **Max feedback latency:** 120 seconds for focused task verification.

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Required typed result |
|---|---|---|---|
| Official 2026/27 organiser draw procedure acceptance | UCLOUT-03 | The exact edition-specific procedure artifact is unavailable in accepted repository evidence. | Until reviewed, evidence record is `accepted=false`, `complete=false`, `unresolved_reason=missing_edition_draw_procedure`; exact draw-conditioned paths are suppressed and verifier exits 0 with `unresolved_draw_procedure`. |
| Production current-state and club-release authority | UCLOUT-01, UCLOUT-02 | Phase 18 credentials/history and Phase 19 source-backed release/CR-01..CR-05 evidence require external owner acceptance. | `production_human_needed` or `production_blocked`, exact normalized human-needed reason when applicable, original parent reason retained, `production_eligible=false`, no selector change, no incumbent change, zero failure/warning/skip counts. |

## Validation Sign-Off

- [ ] Wave 0 focused and adversarial RED transcripts are durable before GREEN work.
- [ ] All tasks have an automated `rtk`-prefixed verification or explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers focused suite, 36/144 fixture builder, pinned evidence, approved-release helper, and CLI/targets wiring tests.
- [ ] Exact 19 edge IDs, exact ten output paths/schemas, exact ten targets/15 edges, exact public symbols, and CR-01..CR-05 probes pass set-equality checks.
- [ ] Every critical/high threat maps to a test and verifier symbol; unmapped IDs fail the aggregate gate.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency is below 120 seconds.
- [ ] All nine requirement IDs have executable evidence.
- [ ] `nyquist_compliant: true` is set only after coverage is proven by recorded GREEN evidence.

**Approval:** pending
