---
phase: 16
slug: euro-qualifying-activation-and-play-off-rules
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-23
revised: 2026-08-23
---

# Phase 16 - Validation Strategy

> Per-phase validation contract for EURO 2028 qualifying activation, official rules, simulation outputs, and payload/state boundaries.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - repository-root-aware source-style tests in `tests/testthat/` |
| **Fast smoke command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="phase16_smoke", stop_on_failure=TRUE, reporter="summary")'` |
| **Focused command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", stop_on_failure=TRUE, reporter="summary")'` |
| **Relevant regression command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE, reporter="summary")' && Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase15_nations_league.R", stop_on_failure=TRUE, reporter="summary")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary")'` |
| **Baseline capture** | Wave 0 runs `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --capture --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md`; the helper runs the exact full-suite child command, records exit status, sorted normalized failing identities, complete-output SHA-256, and known-baseline disposition, including the STATE.md failure `156 fixture IDs paired with zero-length normalized source columns`. |
| **Feedback latency target** | under 30 seconds for fast smoke; under 60 seconds for focused Phase 16 tests |

## Acceptance Policy

The full suite is a regression comparison, not a claim of green status while the known baseline persists. Phase 16 acceptance requires the focused Phase 16 suite and relevant Phase 13-15 regressions to pass, then requires `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --compare --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md` to exit successfully. The comparator permits zero current failures or exactly the recorded pre-existing failure identity/signature, rejects any new or unparseable failure, and reports a persistent known baseline separately with exit status, normalized identities, output hash, and disposition; it is never silently swallowed or relabelled as a passing full suite.

## Sampling Rate

- **Wave 0:** Run the fast smoke command after each harness/fixture task and capture the full-suite baseline once in a fresh child process.
- **After every implementation task:** Run the fast smoke command, then the task-specific focused filter.
- **After every plan wave:** Run the focused Phase 16 file plus the relevant Phase 14/15 regression command.
- **Before `/gsd-verify-work`:** Run two fresh child-process replay checks, the relevant regressions, and the full suite; compare failures to `16-BASELINE.md`.
- **Max feedback latency:** 60 seconds for the focused suite; the full suite is a final regression comparison and may remain workload-dependent.

## Wave Structure

| Validation stage | Plan | Execution wave | Tasks | Gate |
|------------------|------|----------------|-------|------|
| Wave 0 | 16-00 | 1 | 16-00-01, 16-00-02 | Focused harness, fixtures, and baseline fingerprint exist |
| Wave 1 | 16-01 | 2 | 16-01-01, 16-01-02, 16-01-03 | Activation, active-after-draw, pre_draw, D-04 branches, and persistent lifecycle handoff pass |
| Wave 2 | 16-02 | 3 | 16-02-01, 16-02-02 | Ranking, four-host allocation, conservation, topology, and draw conditions pass |
| Wave 3 | 16-03 | 4 | 16-03-01, 16-03-02 | Interim-stage handoff, simulation suppression, scenarios, and replay pass |
| Wave 4 | 16-04 | 5 | 16-04-01, 16-04-02 | Outcomes schema and Phase 14 state gate pass |
| Wave 5 | 16-05 | 6 | 16-05-01, 16-05-02 | CLI/publication, current pre_draw output, fresh-process replay, and baseline comparison pass |

## Per-Task Verification Map

The task map is authoritative for planning. Every task has a runnable automated check; Wave 0 creates the focused test file and baseline artifact referenced by later rows. The table's validation-stage numbering is zero-based for the requested Wave 0 gate; each plan's frontmatter execution wave is the one-based GSD scheduling value.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-00-01 | 00 | 0 | COMP-03, COMP-04, SIM-02, SIM-04 | T-16-00-01 | Fast smoke and exact-path child-process full-suite capture record exit status, normalized identities, output hash, and known-baseline disposition; known failure is separate. | harness/baseline | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="phase16_smoke", stop_on_failure=TRUE, reporter="summary")' && Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --capture --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md` | no - Wave 0 | pending |
| 16-00-02 | 00 | 0 | COMP-03, COMP-04, SIM-02, SIM-04 | T-16-00-02 | Active-after-draw, pre_draw, four-host, topology, and interim-stage fixtures are deterministic and local. | fixture/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="phase16_smoke|fixture", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-01-01 | 01 | 1 | COMP-03, SIM-04 | T-16-01, T-16-02 | Complete source bundle activates; active zero-result and exact D-16 pre_draw states are distinct; kickoff gate is enforced. | contract/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="activation|pre_draw|active_after_draw|phase16_smoke", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-01-02 | 01 | 1 | COMP-03, SIM-04 | T-16-03, T-16-04, T-16-05 | Missing-incumbent and incumbent-continuity branches isolate invalid candidates and preserve accepted content. | contract/revision | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="revision|continuity|source_bundle|kickoff", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-01-03 | 01 | 1 | COMP-03, SIM-04 | T-16-26 | The committed EURO row remains `pre_draw` until complete acceptance; the Phase 13 transition persists `scheduled`, and the next state build reloads that lifecycle and lineage. | integration/lifecycle | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="lifecycle_activation|registry_path|date_only|scheduled|pre_draw_guard", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-02-01 | 02 | 2 | COMP-04 | T-16-06, T-16-07, T-16-08 | Ranking and host ledger preserve stable IDs, explicit slots, scenarios, source lineage, and capacity conservation. | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="ranking|host|scenario|allocation|phase16_smoke", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-02-02 | 02 | 2 | COMP-04 | T-16-09, T-16-10 | Article 15/23 evidence, four-host top-two selection, all branches, and incomplete draw-condition suppression are reproducible. | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="article15|article23|four_host|topology|draw_conditions|conservation", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-03-01 | 03 | 3 | SIM-02 | T-16-11, T-16-13, T-16-14 | Calibrated seeded simulation consumes the registered Phase 15 adapter's canonical interim-stage projection, confirmed kickoff, and active resolved inputs; final-only/wrong-stage inputs suppress probabilities. | unit/integration/replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="simulation|handoff|registered_phase15|ranking_stage|rng|suppression", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-03-02 | 03 | 3 | SIM-02 | T-16-12, T-16-15 | Host branches, fallbacks, draw conditions, scenario preservation, and fresh-process replay suppress invalid probability paths. | unit/integration/replay | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="topology|four_host|fallback|draw_conditions|fresh_process|replay", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-04-01 | 04 | 4 | COMP-03, SIM-02, SIM-04 | T-16-16, T-16-19, T-16-20 | Exact nine-file in-memory candidate validates active/pre_draw/blocked states with lineage and no fabricated rows. | integration/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="outcomes_schema|candidate|pre_draw|active_after_draw|lineage", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-04-02 | 04 | 4 | COMP-03, SIM-04 | T-16-17, T-16-18, T-16-20 | The real `phase14_build_competition_state_main()` -> `phase14_build_competition_state_batch()` -> `phase14_state_bundle_candidate_production()` path accepts pre_draw/valid active zero-result state, rejects missing/incomplete/missing-kickoff bundles, loads EURO rules in a fresh process, and maps Phase 16 reasons without fabricating active state. | integration/state | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="phase14_build_competition_state_main|state_gate|missing_activation|missing_incomplete|missing_kickoff|phase14|active_after_draw|pre_draw|reason_mapping|manifest_lineage|fresh_process", stop_on_failure=TRUE, reporter="summary")' && Rscript --vanilla scripts/build_competition_state.R --edition-id uefa_euro_2028_qualifying --dry-run && Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase14_state_bundle.R", stop_on_failure=TRUE, reporter="summary")'` | no - Wave 0 | pending |
| 16-05-01 | 05 | 5 | COMP-03, SIM-02, SIM-04 | T-16-21, T-16-22 | Registered CLI builds exact inventory from config/manifest inputs and validates exact D-16 payload fields. | integration/CLI | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="cli|inventory|dry_run|payload_copy|active_after_draw", stop_on_failure=TRUE, reporter="summary")' && Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --dry-run` | no - Wave 0 | pending |
| 16-05-02 | 05 | 5 | COMP-03, SIM-02, SIM-04 | T-16-22, T-16-23, T-16-24, T-16-25 | Atomic revision retention, both D-04 branches, fresh-process identical hashes, current pre_draw output, and the runnable no-new-failure comparator are verified. | integration/replay/publication | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase16_euro_qualifying.R", filter="publication|revision|continuity|replay|fresh_process|pre_draw", stop_on_failure=TRUE, reporter="summary")' && Rscript --vanilla scripts/build_euro_qualifying_outcomes.R --replay-check && Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --compare --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md` | no - Wave 0 | pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase16_euro_qualifying.R` exists with a repository-root-aware loader, `phase16_smoke`, fixture constructors, and focused contract sections.
- [ ] Wave 0 runs the exact command `Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --capture --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md`; the child-process full-suite baseline records exit status, normalized failing identities, complete output, SHA-256 fingerprint, date, and the known STATE.md signature `156 fixture IDs paired with zero-length normalized source columns` in `16-BASELINE.md`.
- [ ] The exact comparison command `Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R --compare --baseline .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-BASELINE.md` exits nonzero for any new or unparseable failure, permits only zero failures or the recorded pre-existing identity/signature, and reports a persistent baseline as non-green.
- [ ] The active-after-draw fixture has real groups, stable teams/fixtures, confirmed kickoffs, zero completed results, and zero completed standings; it is asserted as distinct from pre_draw.
- [ ] Four covered hosts, zero/one/two consumed host branches, all three topologies, and preserved scenario rows are available as deterministic local fixtures.
- [ ] Phase 15 handoff fixtures include valid `team_id` rows with `ranking_scope = interim_overall` and `ranking_stage = interim_overall`, plus final-only, wrong-stage, duplicate, missing, and unresolved variants.
- [ ] Exact D-16 heading/body/date/refresh/source/reason fields are fixture assertions, not manual-only checks.

## Focused Contract Assertions

| Contract | Required assertion |
|----------|--------------------|
| D-04 without incumbent | Empty unavailable output; candidate reason retained; no candidate rows. |
| D-04 with incumbent | Incumbent rows/manifest remain visible and byte/hash stable; candidate isolated; revision warning visible. |
| Active after draw | Real groups and confirmed fixtures, zero completed results/standings, active/scheduled status, not pre_draw. |
| D-10 / SIM-02 | Registered Phase 15 stable-ID handoff has exact `ranking_stage = interim_overall`; final-only/wrong-stage handoffs suppress probabilities. |
| Host cardinality | Four covered hosts select only two highest-ranked covered hosts; zero/one/two consumed branches conserve places and preserve unused slots. |
| Additional conditions | Missing/incomplete accepted draw conditions return `unresolved_draw_conditions` and `unsupported_topology`, with probabilities suppressed. |
| D-16 | Exact heading/body, expected draw date, last refresh time, source bundle, and explicit unavailability reason are present in focused tests. |
| Phase 14 gate | Missing/incomplete/missing-kickoff bundles cannot emit active state; accepted pre_draw and valid active zero-result bundles are schema-valid. |
| Phase 14 edition lineage | The real production main/batch/candidate path loads per-edition manifests, maps the six Phase 16 reasons into the accepted state contract, explicitly loads EURO rules in a fresh process, and never fabricates active state. |
| Lifecycle persistence | The registry stays `pre_draw` through date passage and becomes `scheduled` only through `phase13_transition_competition_edition()` after a complete accepted bundle; the next state path observes the persisted row. |
| Replay | In-process normal/reversed/repeated and fresh child-process runs have identical complete artifact bytes/hashes. |

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Review the first official UEFA post-draw bundle and any additional play-off draw conditions when published. | COMP-03, COMP-04 | The official post-draw source does not exist yet and future UEFA operational constraints may be published after implementation. | Confirm the registered source/config locator, raw snapshot metadata, accepted URL/resource lineage, complete five resources, kickoff completeness, rules/draw-condition revision, and manifest hashes before promoting the first live bundle. |

## Validation Sign-Off

- [x] Every planned task has an automated verification command or an explicit Wave 0 dependency that creates its test file.
- [x] Sampling continuity has no three consecutive implementation tasks without automated verification.
- [x] Wave 0 explicitly creates the focused test file, the exact-path baseline capture/compare helper contract, baseline fingerprint, and all shared fixtures required by later tasks.
- [x] No watch-mode flags are used.
- [x] Fast smoke feedback is targeted below 30 seconds; focused feedback is targeted below 60 seconds.
- [x] `nyquist_compliant: true` is justified by the explicit Wave 0 task, exact capture/compare commands, task map, focused commands, regression commands, replay commands, and final baseline comparison policy above.
- [ ] Wave 0 has been executed and `16-BASELINE.md` has a captured fingerprint.
- [ ] All planned task rows are complete and signed off after execution.

**Planning sign-off:** ready for execution; execution status remains pending until Wave 0 runs.
