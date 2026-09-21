---
phase: 20
slug: ucl-rules-state-and-tournament-outcomes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-21
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none — repository tests live under `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_uefa_champions_league.R", reporter="summary", stop_on_failure=TRUE)'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary", stop_on_failure=TRUE)'` |
| **Estimated runtime** | focused target below 120 seconds; full suite measured during execution |

---

## Sampling Rate

- **After every task commit:** Run the focused Phase 20 test file plus the directly touched Phase 14–16 analog test.
- **After every plan wave:** Run the focused Phase 20 test and `test_phase14_match_state.R`, `test_phase14_standings.R`, `test_phase14_forecast_layer.R`, `test_phase14_state_bundle.R`, `test_phase15_nations_league.R`, and `test_phase16_euro_qualifying.R`.
- **Before `/gsd:verify-work`:** Full suite must be green with zero failures, warnings, and skips, except pre-existing environment/artifact blockers must be isolated and recorded rather than waived.
- **Max feedback latency:** 120 seconds for focused task verification.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-W0-01 | W0 | 0 | UCLRULE-01 | T-20-SCHEDULE / T-20-RANK | Exact 36-club/144-fixture graph and qualification bands reject partial or forged state. | contract | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-02 | W0 | 0 | UCLRULE-02 | T-20-RULES | Official-order criterion traces stop at typed unresolved evidence; no lexical/random fallback. | adversarial | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-03 | W0 | 0 | UCLRULE-03 | T-20-SCHEDULE | Eight distinct opponents, 4/4 venue split, matchday, kickoff, lifecycle, score, and lineage are exact. | contract | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-04 | W0 | 0 | UCLOUT-01 | T-20-AUTH / T-20-CUTOFF | Only production club authority can publish; fixture mode stays non-promotable and settled forecasts remain immutable. | regression | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-05 | W0 | 0 | UCLOUT-02 | T-20-SIM | Completed results remain fixed and rank/band/cut-line distributions reconcile exactly. | integration | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-06 | W0 | 0 | UCLOUT-03 | T-20-DRAW | Only legal rank-pair paths exist and accepted same-edition draws condition them exactly. | adversarial | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-07 | W0 | 0 | UCLOUT-04 | T-20-STAGE | Two-leg aggregate, no away goals, leg order, ET/penalties, and neutral final resolve by versioned rules. | unit | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-08 | W0 | 0 | UCLOUT-05 | T-20-RECON | Stage inputs/outputs reconcile and per-club progression remains monotone through champion. | integration | focused Phase 20 command | ❌ W0 | ⬜ pending |
| 20-W0-09 | W0 | 0 | UCLOUT-06 | T-20-REPLAY | Identical and reverse-ordered inputs reproduce canonical bytes with protected incumbents unchanged. | replay | focused Phase 20 command | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test_uefa_champions_league.R` — focused coverage for all nine Phase 20 requirements and adversarial authority boundaries.
- [ ] Full-cardinality fixture helper — 36 clubs, 144 league matches, eight distinct opponents, and 4/4 home-away validation variants.
- [ ] Pinned rules/draw fixture — canonical Article 18 criterion trace and Article 19/Annex B legal-path examples.
- [ ] Approved-release fixture helper — fixture authority proves mechanics while production resolution remains blocked/non-promotable.
- [ ] `scripts/build_uefa_champions_league_outcomes.R` and `_targets.R` wiring tests — added in the first implementation wave if not already created there.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Official 2026/27 knockout draw procedure acceptance | UCLOUT-03 | The exact edition-specific draw-procedure artifact is not yet available in accepted repository evidence. | Compare the accepted manual artifact to Article 19 and Annex B, record document URL/hash/review, and run the legal-path fixture suite before enabling draw-conditioned production output. |
| Production current-state and club-release authority | UCLOUT-01, UCLOUT-02 | Phase 18 credentials/history and the Phase 19 production selector require external owner evidence. | Run the fixed production entry point with accepted provider/history/release evidence and confirm selector/source lineage, cutoff, and protected incumbent bytes. |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or an explicit Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing test reference.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency is below 120 seconds.
- [ ] All nine requirement IDs have executable evidence.
- [ ] `nyquist_compliant: true` is set in frontmatter after coverage is proven.

**Approval:** pending
