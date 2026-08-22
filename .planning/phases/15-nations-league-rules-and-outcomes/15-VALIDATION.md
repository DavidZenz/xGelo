---
phase: 15
slug: nations-league-rules-and-outcomes
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false)
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-22
---

# Phase 15 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - repository `tests/testthat` conventions |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | ~72 seconds focused in this environment; full suite is workload-dependent |

---

## Sampling Rate

- **After every task commit:** Run `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'`
- **After every plan wave:** Run the focused Phase 15 test plus the relevant Phase 14 competition regressions.
- **Before `/gsd:verify-work`:** Run `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` and record any pre-existing failures separately.
- **Max feedback latency:** 120 seconds for the focused suite.

---

## Audit Result

The active Phase 15 gate was rerun from the repository root after auditing the
existing behavioral coverage. The focused suite completed in about **72
seconds** with **34 test blocks, 602 expectations, 0 failures, 0 errors, 0
warnings, and 0 skips**. This exceeds the planned 30-second feedback target
but remains within the 120-second gate.
The adjacent official-snapshot regression completed with **58 expectations,
0 failures, 0 warnings, and 0 skips**.

One real SIM-01 coverage gap was filled in the existing focused test: the
acceptance path now requires direct-promotion and direct-relegation
probabilities, applicable A/B and B/C play-off transitions, and their explicit
unresolved status when no completed play-off capture is available. No
production files were changed. The repository-wide `tests/testthat` suite was
not used as this phase gate and remains outside this focused validation result.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-00-01 | 00 | 0 | COMP-02, SIM-01 | T-15-00 | Wave 0 fixture builders encode exact status, reciprocal-leg, host-order, completed-score, calibrated-sampling, and replay fields before production APIs exist. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-01-01 | 01 | 1 | COMP-02 | T-15-01 | Unknown stages/resources, fabricated official IDs, incomplete completed scores, and unregistered stage captures are rejected. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-01-02 | 01 | 1 | COMP-02 | T-15-01 | The separate raw/accepted/manifest/registry stage-capture path loads, hashes, and replays without changing five Phase 13 resources. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-01-03 | 01 | 1 | COMP-02 | T-15-01 | Article 13 admitted access-list/group-formation inputs validate seeded groups; current source without admitted metadata remains unresolved_access_list with no invented positions or draw pots. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-02-01 | 02 | 2 | COMP-02 | T-15-02 | Article 15/19 ranking is deterministic; missing discipline/access-list inputs return blocked metadata and never pass fake contiguous ranks. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-02-02 | 02 | 2 | COMP-02 | T-15-02 | Fourth-place/cardinality rules, transitions, and explicit unresolved C/D eligibility are preserved. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-02-03 | 02 | 2 | COMP-02 | T-15-02 | Article 19 final overall ranking applies exact stage/rank bands and final/third-place overwrite; C/D cancellation retains C46/47 and D50/51 with no fabricated play-off probabilities. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-03-01 | 03 | 3 | SIM-01 | T-15-03 | Calibrated simplex sampling passes seeded empirical tolerance; Article 14 reciprocal legs, Article 16-18 resolution, and Article 17 host ordering follow the ruleset. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-03-02 | 03 | 3 | SIM-01 | T-15-03 | Completed results, legal draws, C/D branches, and no-forecast-leakage replay are deterministic. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-03-03 | 03 | 3 | SIM-01 | T-15-03 | Simulation propagates final_overall_rank/ranking_stage and explicit C/D cancellation retention/suppression without emitting play-off probabilities. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-04-01 | 04 | 4 | COMP-02, SIM-01 | T-15-04 | The in-memory outcomes candidate carries the exact nine-file schemas including fixture_forecast_form.csv, completed score fields, stage-capture parent lineage, and status-specific provenance without changing eleven Phase 14 artifacts. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-04-02 | 04 | 4 | COMP-02, SIM-01 | T-15-04 | Manifest self/content/parent hashes and sibling writer reject inventory, status, score, fixture pass-through, and lineage violations. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-04-03 | 04 | 4 | COMP-02, SIM-01 | T-15-04 | Fixture-level pass-through joins calibrated forecasts to both form scopes with explicit unavailable status/current cutoffs, parent hashes, loader visibility, and no fabricated history. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-05-01 | 05 | 5 | COMP-02, SIM-01 | T-15-05 | Nations League-only CLI loads both durable boundaries, writes the exact nine sibling files including fixture_forecast_form.csv, and replay compares stage-capture and completed-score hashes without mutation. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |
| 15-06-01 | 06 | 6 | COMP-02, SIM-01 | T-15-06 | Production acceptance proves truthful current state, access-list/group-formation validation, final overall ranking, durable completed-stage representation, host ordering, blocked ranking, C/D retention, fixture pass-through, registered-root enforcement, replay equality, and Phase 14 immutability. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ verified | green |

*Status: ✅ verified · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Plan `15-00-PLAN.md` creates `tests/testthat/test_phase15_nations_league.R` before Plan `15-01-PLAN.md` can execute.
- [x] Synthetic three-team and four-team group fixtures with tied standings, disciplinary points, and access-list positions.
- [x] Wave 0 fixtures include admitted Article 13 rows with `access_list_position`, `league_id`, `group_id`, `draw_pot`, `group_formation_status`, and `source_artifact_id`, plus a current-source case with `status = unresolved_access_list`, `NA_integer_` positions, and no invented draw pots.
- [x] Wave 0 defines `phase15_test_output_root()` as the only temporary-output validator/registration path; production-root tests reject arbitrary unregistered children of `tempdir()`.
- [x] Synthetic Article 14 reciprocal two-leg and single-leg stage fixtures covering aggregate, extra time, penalties, Article 17 host/Team A ordering, and C/D cancellation.
- [x] Synthetic Article 19 pre-final/post-final ranking fixtures cover every final-overall stage band, champion/runner-up/third/fourth overwrite, and exact C46/47 plus D50/51 cancellation retention with no play-off probabilities.
- [x] Completed QF, semi-final, final, A/B, B/C, and C/D capture rows contain regulation, extra-time, shootout, final-score, and `completed_at_utc` fields.
- [x] Fixture pass-through fixtures cover scheduled forecast availability, explicit current form unavailability, completed form availability, all requested model/release/cutoff/form/source/parent hashes, and loader/manifest visibility.
- [x] Deterministic replay fixture includes explicit source bundle, separate stage-capture manifest/raw/content hashes, model release, ruleset, seed, and output hashes.
- [x] Seeded empirical W/D/L sampling fixture uses target `c(home = 0.45, draw = 0.25, away = 0.30)`, seed `15017L`, 100000 draws, and max absolute error `0.01`.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Official source publication should still be reviewed when a later UEFA snapshot adds downstream pairings or results, but the resulting admission and status checks are automated.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [ ] Feedback latency < 30s for focused tests (observed ~72s; within 120s gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** partial, validated 2026-08-22; WARNING: focused feedback exceeded the 30-second target
