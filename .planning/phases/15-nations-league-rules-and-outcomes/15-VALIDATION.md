---
phase: 15
slug: nations-league-rules-and-outcomes
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false)
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Estimated runtime** | ~30 seconds focused; full suite is workload-dependent |

---

## Sampling Rate

- **After every task commit:** Run `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'`
- **After every plan wave:** Run the focused Phase 15 test plus the relevant Phase 14 competition regressions.
- **Before `/gsd:verify-work`:** Run `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` and record any pre-existing failures separately.
- **Max feedback latency:** 30 seconds for the focused suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-00-01 | 00 | 0 | COMP-02, SIM-01 | T-15-00 | Wave 0 fixture builders encode exact status, reciprocal-leg, host-order, completed-score, calibrated-sampling, and replay fields before production APIs exist. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-01-01 | 01 | 1 | COMP-02 | T-15-01 | Unknown stages/resources, fabricated official IDs, incomplete completed scores, and unregistered stage captures are rejected. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-01-02 | 01 | 1 | COMP-02 | T-15-01 | The separate raw/accepted/manifest/registry stage-capture path loads, hashes, and replays without changing five Phase 13 resources. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-02-01 | 02 | 2 | COMP-02 | T-15-02 | Article 15/19 ranking is deterministic; missing discipline/access-list inputs return blocked metadata and never pass fake contiguous ranks. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-02-02 | 02 | 2 | COMP-02 | T-15-02 | Fourth-place/cardinality rules, transitions, and explicit unresolved C/D eligibility are preserved. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-03-01 | 03 | 3 | SIM-01 | T-15-03 | Calibrated simplex sampling passes seeded empirical tolerance; Article 14 reciprocal legs, Article 16-18 resolution, and Article 17 host ordering follow the ruleset. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-03-02 | 03 | 3 | SIM-01 | T-15-03 | Completed results, legal draws, C/D branches, and no-forecast-leakage replay are deterministic. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-04-01 | 04 | 4 | COMP-02, SIM-01 | T-15-04 | The in-memory outcomes candidate carries exact eight-file schemas, completed score fields, stage-capture parent lineage, and status-specific provenance without changing eleven Phase 14 artifacts. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-04-02 | 04 | 4 | COMP-02, SIM-01 | T-15-04 | Manifest self/content/parent hashes and sibling writer reject inventory, status, score, and lineage violations. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-05-01 | 05 | 5 | COMP-02, SIM-01 | T-15-05 | Nations League-only CLI loads both durable boundaries, writes exactly eight sibling files, and replay compares stage-capture and completed-score hashes without mutation. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` | ✅ planned | ⬜ pending |
| 15-06-01 | 06 | 6 | COMP-02, SIM-01 | T-15-06 | Production acceptance proves truthful current state, durable completed-stage representation, host ordering, blocked ranking, C/D unresolved state, replay equality, and Phase 14 immutability. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE)'` plus `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` | ✅ planned | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Plan `15-00-PLAN.md` creates `tests/testthat/test_phase15_nations_league.R` before Plan `15-01-PLAN.md` can execute.
- [ ] Synthetic three-team and four-team group fixtures with tied standings, disciplinary points, and access-list positions.
- [ ] Synthetic Article 14 reciprocal two-leg and single-leg stage fixtures covering aggregate, extra time, penalties, Article 17 host/Team A ordering, and C/D cancellation.
- [ ] Completed QF, semi-final, final, A/B, B/C, and C/D capture rows contain regulation, extra-time, shootout, final-score, and `completed_at_utc` fields.
- [ ] Deterministic replay fixture includes explicit source bundle, separate stage-capture manifest/raw/content hashes, model release, ruleset, seed, and output hashes.
- [ ] Seeded empirical W/D/L sampling fixture uses target `c(home = 0.45, draw = 0.25, away = 0.30)`, seed `15017L`, 100000 draws, and max absolute error `0.01`.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Official source publication should still be reviewed when a later UEFA snapshot adds downstream pairings or results, but the resulting admission and status checks are automated.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for focused tests
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
