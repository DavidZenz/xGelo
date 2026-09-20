# Phase 19 Plan Review: Independent Club Forecast Authority

**Reviewed:** 2026-09-20  
**Verdict:** **REVISION REQUIRED — RE-REVIEW: 2 BLOCKERS**  
**Plans reviewed:** 19-01 through 19-10  
**Phase goal:** Forecast consumers can use an immutable, independently validated club-football release that cannot be confused with national-team authority.

## Executive verdict

The plan set is structurally disciplined: all five `CLUBMOD` requirements appear in plan frontmatter and executable tasks, the dependency graph is acyclic, every plan has two bounded TDD tasks, same-wave file ownership is disjoint, and the final adversarial gate is much stronger than a nominal happy-path suite.

Commit `3e23e21` materially closes original blockers B1, B3, B4, and B5 plus warnings W1–W3. It also adds the correct owner-review design for B2. Two blockers remain before execution:

1. `19-RESEARCH.md` still formally declares all four questions unresolved even though production plan authority now depends on their resolution-by-review design.
2. Plan 19-10 requires the current production CLI to prove every downstream blocked reason independently while simultaneously prohibiting the temporary accepted prerequisites needed to reach any reason after the first missing history gate.

These are precise artifact/executability defects; the revised roadmap goal itself was not weakened.

## Coverage and structure

| Requirement | Covering plans | Goal-backward status |
|---|---|---|
| CLUBMOD-01 | 19-01, 19-02, 19-03, 19-05, 19-08, 19-09, 19-10 | Task coverage present; production outcome remains blocked by Finding B1 |
| CLUBMOD-02 | 19-02, 19-04, 19-05, 19-06, 19-07, 19-09, 19-10 | Strong cutoff, same-batch, rolling-origin, held-out-league, nesting, and replay coverage |
| CLUBMOD-03 | 19-03, 19-04, 19-06, 19-07, 19-09, 19-10 | Gate mechanics covered; approval authority missing per Finding B2 |
| CLUBMOD-04 | 19-08, 19-09, 19-10 | MECHANICS COVERED; PRODUCTION PENDING under the Roadmap completion gate |
| CLUBMOD-05 | 19-01, 19-05, 19-08, 19-09, 19-10 | Exact five-feature typed-unavailable contract is well covered |

| Plan | Wave | Dependencies | Tasks | Structural status |
|---|---:|---|---:|---|
| 19-01 | 1 | — | 2 | Valid |
| 19-02 | 2 | 19-01 | 2 | Valid |
| 19-03 | 2 | 19-01 | 2 | Valid |
| 19-04 | 3 | 19-03 | 2 | Valid after B2 revision |
| 19-05 | 3 | 19-02, 19-03 | 2 | Valid |
| 19-06 | 4 | 19-04, 19-05 | 2 | Valid |
| 19-07 | 5 | 19-02, 19-04, 19-05, 19-06 | 2 | Missing current-club authority input; fixture status conflict |
| 19-08 | 6 | 19-07 | 2 | Fixture release input contradicts 19-07 |
| 19-09 | 7 | 19-08 | 2 | Production/fixture controller otherwise coherent |
| 19-10 | 8 | 19-01..19-09 | 2 | Strong final gate; cannot substitute for missing pre-execution validation |

No dependency cycle, missing plan reference, future dependency, or same-wave file collision was found. Sequential edits to `R/club/evaluation_protocol.R` in Plans 19-03/19-04 and release surfaces in Plans 19-08/19-09 are ordered correctly.

## Original blockers

### B1 — Phase goal cannot be achieved by the planned terminal state

**Severity:** BLOCKER  
**Dimension:** requirement coverage / goal achievement  
**Affected:** Roadmap Phase 19 success criterion 4, CLUBMOD-04, Plans 19-08 through 19-10

The Roadmap requires consumers to resolve one immutable, model-card-backed club release. Plan 19-08 says blocked production creates no club release or selector; Plan 19-09 requires the current production run to stop before fit/publication; Plan 19-10 treats selector absence as the successful terminal state. A temporary fixture release is explicitly ineligible for production consumers. Therefore the plan set can prove a safe capability, but cannot deliver the stated phase outcome in the repository's current external-evidence state.

**Exact revision required:** choose and record one of these paths before execution:

1. Split Phase 19 into a capability phase and a production-activation phase. The capability phase may end `human_needed` with fixture mechanics and fail-closed production; retain CLUBMOD-04 and Roadmap criterion 4 in the activation phase, which cannot complete until Phase 18 real accepted history/current-UCL authority exists and a real release is promoted.
2. Keep one phase, but explicitly declare the external checkpoint and prohibit phase completion: Plans 19-08/19-10 must say implementation may execute, but the verifier must return `human_needed`/incomplete until an accepted production release and selector are created and resolved. Do not mark CLUBMOD-04 complete from fixture evidence.
3. If the product decision is intentionally fixture-only for this milestone, revise ROADMAP/REQUIREMENTS through an explicit user decision. That is a scope change, not something the planner may infer.

### B2 — Unresolved policy and fold assumptions can become production authority without review

**Severity:** BLOCKER  
**Dimension:** research resolution / production authority  
**Affected:** 19-RESEARCH Open Questions 1–4; Plans 19-03, 19-04, 19-09

`19-RESEARCH.md` still has an unresolved `## Open Questions` section. Plans adopt the first candidate family, strict leave-one-league-out interpretation, inherited numeric thresholds, one-parameter calibration, and automatic final-cutoff/fold materialization. Plan 19-04 states that an accepted snapshot atomically yields `ready` protocol state. That bypasses the research requirement to owner-review the real fold inventory and proposed gates before any real score is computed.

**Exact revision required:**

- Resolve Open Questions 1–4 in a locked decision artifact, or add a canonical `protocol_review` authority with reviewer, reviewed time, exact candidate/gate/calibration/fold hashes, accepted/rejected decision, and self-hash.
- Change Plan 19-04 from `accepted snapshot -> ready` to `accepted snapshot -> pending_review candidate fold inventory -> separately accepted immutable ready generation`.
- Production evaluation in Plans 19-07/19-09 must require accepted history **and** accepted protocol/fold review. Use stable reasons such as `protocol_policy_not_approved` and `fold_inventory_not_approved`.
- Fixture protocols remain explicitly fixture-only and cannot satisfy those production approvals.
- Mark `## Open Questions (RESOLVED)` only after the decisions or review-gate design is recorded.

### B3 — Current-UCL club coverage gate has no authoritative input

**Severity:** BLOCKER  
**Dimension:** key links / cross-plan data contract  
**Affected:** Plans 19-02, 19-03, 19-07, 19-08, 19-09

The plans declare a mandatory current-UCL club/component coverage gate, but the only Phase 18 production gateway actually planned is `phase18_read_club_history_current()`. No task calls `phase18_read_ucl_refresh_current()`, requires `accepted_status=accepted`, extracts the exact current-edition club set from the pointer-selected current bundle, or binds the current source/identity generation hashes. Plan 19-07 therefore has no trustworthy input from which to compute the declared gate.

**Exact revision required:**

- Add a Plan 19-01 or 19-04 task/artifact for a `current_ucl_club_snapshot` that resolves only `phase18_read_ucl_refresh_current()` under fixed production roots, requires one accepted non-tombstone generation, validates the selected bundle and current identity registry, and canonicalizes the exact edition club IDs.
- Bind accepted-generation, bundle-manifest, edition, source-authority, club-registry-generation, and roster hashes into that snapshot.
- Add a separate fixture-current-club snapshot for fixture evaluation; production rejects it.
- Make rating graph coverage (19-02), the gate registry/evidence (19-03/19-07), release contract (19-08), CLI/targets (19-09), and adversarial inventory (19-10) consume this explicit parent.
- Add `no_accepted_current_ucl` / `current_ucl_identity_incomplete` blocking reasons. Accepted historical data alone must never make production releasable.

### B4 — Fixture promotion and fixture release contracts contradict each other

**Severity:** BLOCKER  
**Dimension:** key links / executability  
**Affected:** Plans 19-07, 19-08, 19-09

Plan 19-07 requires every fixture-authority decision to have stable non-promotable status regardless of scores. Plan 19-08 then requires a "passing fixture decision" to create a fixture release, and Plan 19-09 requires the full fixture path to run `decision -> fixture release`. An executor cannot implement both literally without either weakening the non-promotion invariant or inventing an undocumented bypass.

**Exact revision required:** define separate, non-confusable fields and checks:

- `diagnostic_gate_outcome = pass|fail`
- `authority_eligibility = production|fixture_ineligible`
- `promotion_status = promoted|retained|ineligible_fixture|blocked`

The fixture release writer may require `diagnostic_gate_outcome=pass` and `promotion_status=ineligible_fixture`, but only through an explicitly fixture-only writer/resolver under a temporary root. The production writer must require `promotion_status=promoted` plus production authority. Tests must prove that changing only the fixture status/field names or rehashing cannot enter the production writer.

Revise the Plan 19-08 wording from "passing fixture decision" to "gate-complete, production-ineligible fixture diagnostic decision" and carry the same distinction into Plan 19-09 and the final probe inventory.

### B5 — Required Nyquist validation artifact is missing before execution

**Severity:** BLOCKER  
**Dimension:** Nyquist compliance  
**Affected:** Phase-level; Plan 19-10

`.planning/config.json` has `workflow.nyquist_validation=true`, while `19-VALIDATION.md` is absent. Plan 19-10 proposes creating it after nineteen implementation tasks have already executed. That defeats the pre-execution validation gate.

**Exact revision required:** create `19-VALIDATION.md` now, before execution, mapping all 20 tasks to their focused automated commands, test files, wave, feedback latency, requirement IDs, and final aggregate gate. Plan 19-10 should **update/finalize** the artifact with observed results, not create the validation architecture for the first time. Include the current production-blocked expectation and fixture-only distinction without treating them as proof of CLUBMOD-04 production completion.

## Original warnings

### W1 — National consumer regression coverage omits the file actually modified

**Severity:** WARNING  
**Dimension:** verification strength / compatibility  
**Affected:** Plans 19-08, 19-10

Plan 19-08 modifies `R/competition/forecast_layer.R` but its automated regression command runs `test_phase12_release.R` and `test_phase14_calibration_release.R`, not `test_phase14_forecast_layer.R`. The same guarded path is consumed by later Nations League/state flows.

**Exact revision:** add at least `test_phase14_forecast_layer.R`, `test_phase14_state_bundle.R`, and `test_phase15_nations_league.R` to the Plan 19-08 compatibility command and the exact Plan 19-10 regression inventory, unless a targeted dependency audit proves one is irrelevant.

### W2 — Focused task checks do not fail on skips/warnings until the final gate

**Severity:** WARNING  
**Dimension:** TDD verification strength  
**Affected:** Plans 19-01 through 19-09

The final Plan 19-10 runner explicitly fails on warning/skip/inventory drift, but focused `testthat::test_file()` commands may allow an executor to commit a task whose relevant test was skipped or warned. The final gate catches this late.

**Exact revision:** use one shared focused-test wrapper that fails on failures, errors, warnings, and skips, or add explicit result inspection to every `<automated>` command. Keep Plan 19-10 as the independent full-suite check.

### W3 — Automated shell commands omit the project-mandated `rtk` prefix

**Severity:** WARNING  
**Dimension:** AGENTS.md compliance  
**Affected:** all plans

Project instructions import `RTK.md`, whose rule is to prefix shell commands with `rtk`. The plan `<automated>` commands currently invoke `Rscript` and `git` directly.

**Exact revision:** prefix executable verification commands with `rtk` (including each segment after shell control operators), or explicitly state in the execution context that the executor wraps every plan command through `rtk` while preserving command semantics.

## Dimensions that pass

- **Requirement references:** every Phase 19 requirement appears in plan frontmatter and substantive tasks.
- **Task structure:** all 20 tasks contain files, action, measurable acceptance criteria, automated verification, and done conditions.
- **Dependencies/waves:** valid and acyclic; wave ordering matches data flow.
- **Scope:** two tasks per plan and bounded file sets; no plan exceeds the configured task threshold.
- **Temporal leakage controls:** strict dual timestamps, exclusive cutoffs, exact-kickoff/conservative-date batching, held-out exclusion through fit/tune/calibration, and permutation tests are explicitly planned.
- **Model integrity:** fail-closed negative-binomial fitting, no Poisson/zero-imputation fallback, complete `0:40` grids, exact coverage, and shared scorer reuse are explicit.
- **Release security:** exact recursive inventory, safe paths, no symlinks, metadata-before-RDS preflight, object validation, selector reread, lock/rollback, and bidirectional domain probes are planned.
- **Fixture/production root separation:** strong throughout, subject to resolving B4's decision vocabulary.
- **Final prohibition inventory:** exactly three flagged prohibitions per plan, 30 total, with a planned bijection to executable evidence.

## Re-review acceptance gate

Return this plan set for execution only when:

- the intended Phase 19 completion semantics are reconciled with the absent real release (B1);
- research decisions or explicit production review authority are resolved (B2);
- the accepted current-UCL club-set producer is wired to all coverage/release consumers (B3);
- fixture gate outcome and promotion eligibility are distinct and consistent end to end (B4);
- `19-VALIDATION.md` exists before execution (B5);
- the national consumer regression set is expanded (W1);
- focused test and RTK command handling are documented or revised (W2/W3).

Until then, the plans can implement valuable mechanics but cannot truthfully satisfy the Roadmap phase goal.

## Revision resolution — 2026-09-20

All five blockers and three warnings were addressed in commit-ready plan revisions:

| Finding | Resolution |
|---|---|
| B1 completion semantics | Roadmap and Plans 19-08..19-10 now distinguish executable fixture capability from phase completion. Verification remains `human_needed`; CLUBMOD-04 cannot complete until a real reviewed production release is promoted, selector-published, and resolver-read back. |
| B2 owner policy/fold authority | Plans 19-03/19-04 add self-hashed `policy_review.json` and `fold_review.json`. Research values are reviewable candidates, accepted history produces `pending_review`, and production scoring requires exact accepted reviews or returns `protocol_policy_not_approved` / `fold_inventory_not_approved`. |
| B3 current-UCL coverage producer | Plan 19-01 now resolves `phase18_read_ucl_refresh_current()` plus the fixed identity `current.json`, requires accepted non-tombstone state, canonicalizes the exact edition roster, and binds refresh/bundle/source/identity/registry/roster hashes. Plans 19-02/07/08/09/10 consume and attack this parent. |
| B4 fixture decision conflict | Plans 19-07..19-10 use separate `diagnostic_gate_outcome`, `authority_eligibility`, and `promotion_status`. A fixture diagnostic pass may stage only a fixture release as `fixture_ineligible` / `ineligible_fixture`; production requires `production` / `promoted`. |
| B5 Nyquist artifact | `19-VALIDATION.md` now exists before execution with all 20 task commands, Wave 0 gaps, strict feedback policy, requirements, and the separate production human-needed completion gate. Plan 19-10 updates/finalizes it rather than creating it. |
| W1 national regressions | Plan 19-08 and the final inventory now include Phase 14 forecast layer, Phase 14 state bundle, and Phase 15 Nations League tests in addition to release regressions. |
| W2 warning/skip handling | Plan 19-01 creates `scripts/run_phase19_focused_test.R`; every focused plan command uses it and must fail on failure, error, warning, skip, empty, or missing tests. |
| W3 RTK convention | Every executable plan verification segment is prefixed with `rtk`, including commands after shell control operators. |

**Resolution status:** ready for re-review; no roadmap requirement was weakened or marked complete from fixture evidence.

## Re-review — 2026-09-20 after `3e23e21`

### Closure audit

| Prior finding | Re-review result | Evidence |
|---|---|---|
| B1 — terminal state missed production release goal | **CLOSED** | ROADMAP now retains success criterion 4 and adds an explicit completion gate: mechanics may execute, but Phase 19 stays `human_needed` and CLUBMOD-04 incomplete until real accepted inputs, reviewed policy/folds, production promotion, selector publication, and resolver readback exist. Plans 19-08..19-10 repeat and verify that distinction. |
| B2 — policy/fold assumptions gained authority without review | **PARTIALLY CLOSED; R1 remains** | Plans 19-03/19-04 now add pending, self-hashed policy/fold reviews, exact parent binding, pending-review state, separate review application, and stable blocking reasons. However, the authoritative research artifact still says `## Open Questions` with four unresolved questions. |
| B3 — no current-UCL roster authority producer | **CLOSED** | Plan 19-01 now resolves the fixed Phase 18 refresh and club-registry generation, rejects no-incumbent/tombstone/incomplete identity, and binds edition/source/identity/roster hashes. Plans 19-02/19-07/19-08/19-09/19-10 consume or attack this parent. |
| B4 — fixture decision contradicted fixture release | **CLOSED** | Plans 19-07..19-10 consistently separate diagnostic outcome, authority eligibility, and promotion status. Fixture pass is `fixture_ineligible`/`ineligible_fixture`; only production plus `promoted` enters the production writer. |
| B5 — no pre-execution validation artifact | **CLOSED** | `19-VALIDATION.md` now exists, maps all 20 tasks/commands/requirements, defines strict focused/full feedback, and separately records the production human-needed gate. Plan 19-10 updates it rather than first creating the design. |
| W1 — incomplete national consumer regressions | **CLOSED** | Plan 19-08 and Plan 19-10 include Phase 12/14 release, Phase 14 forecast/state, and Phase 15 Nations League regressions. |
| W2 — focused checks allowed skip/warning | **CLOSED** | Plan 19-01 creates one strict focused runner; every plan uses it and requires nonzero exit on failure, error, warning, skip, empty, or missing test. |
| W3 — commands omitted RTK | **CLOSED** | Every `<automated>` executable segment, including commands after `&&`, is prefixed with `rtk`. |

### R1 — Research questions remain formally unresolved

**Severity:** BLOCKER  
**Dimension:** research resolution  
**Affected:** `19-RESEARCH.md`, Plans 19-03/19-04

The revised plan correctly resolves uncertainty by making the model/gate values reviewable candidates, making accepted history produce only `pending_review`, and requiring exact accepted policy/fold reviews before production scoring. But `19-RESEARCH.md` still contains `## Open Questions` and all four questions remain written as unclear recommendations. Under the research-resolution gate, a downstream plan cannot silently supersede an unresolved upstream artifact.

**Exact revision required:** change the section to `## Open Questions (RESOLVED)` and record an inline resolution for each question:

1. real fold inventory is materialized as a candidate and requires accepted exact-hash fold review;
2. strict held-out-league transport is fixture-testable policy and requires accepted policy review for production;
3. inherited numeric gates are candidates and require accepted exact-hash policy review;
4. final-fit cutoff is bound into the exact fold review and cannot be inferred at runtime.

This does not approve the values; it resolves the architecture by explicitly deferring production authority to the owner-review contracts.

### R2 — The final gate cannot independently reach all promised production blocked reasons

**Severity:** BLOCKER  
**Dimension:** verification executability / internal consistency  
**Affected:** Plan 19-10 Task 19-10-01 and Task 19-10-02

Current production stops first at `no_accepted_club_history`. Reaching `no_accepted_current_ucl`, `current_ucl_identity_incomplete`, `protocol_policy_not_approved`, or `fold_inventory_not_approved` through the full production controller requires valid earlier production authorities. Plan 19-10 nevertheless requires current production to prove every reason independently while also saying verification must not manufacture accepted history/current-UCL evidence or owner reviews. Both conditions cannot be satisfied in the current repository.

**Exact revision required:** separate the two kinds of proof:

- The fixed-root production CLI/readback must assert only the actual first missing reason (`no_accepted_club_history` today), selector absence, and protected-byte preservation.
- Public boundary validators must exercise the later reason codes using explicitly non-production temporary harnesses/objects that cannot be written under or resolved by production roots.
- Revise "proves current production blocks independently on missing history/current-UCL/policy/fold authority" and "execute current production and require exact blocked reasons" to this first-real-reason plus isolated-boundary formulation.
- Keep the prohibition against manufacturing accepted **production** authority. Explicitly allow temporary non-production test parents solely to reach downstream validators, with authority/root checks proving they cannot publish.
- Change Plan 19-10 success text from "All five requirements have direct automated evidence" to: CLUBMOD-01/02/03/05 have direct automated evidence; CLUBMOD-04 mechanics have automated evidence while its production outcome remains `human_needed` until the roadmap completion gate is satisfied. Likewise mark the CLUBMOD-04 coverage row `MECHANICS COVERED; PRODUCTION PENDING`.

## Final re-review verdict

**REVISION REQUIRED: 2 blockers, 0 warnings.**

The substantive authority architecture is now strong and the roadmap outcome is preserved. Once R1 and R2 are corrected, no other blocker is known and the plans should be ready for execution with an expected post-mechanics status of `human_needed` rather than false completion.

## Final revision resolution — 2026-09-20

| Finding | Resolution |
|---|---|
| R1 research questions | `19-RESEARCH.md` now records all four questions under `Open Questions (RESOLVED)`: reviewed candidate fold materialization, strict held-out-league policy, candidate-only inherited numeric gates, and an explicit fold-reviewed final-fit cutoff. Each decision retains its real Phase 18 evidence and owner-review dependency without leaving the architecture unresolved or treating candidate values as approved. |
| R2 unreachable production reasons | Plan 19-10 now asserts only the truthful first fixed-root production failure, `no_accepted_club_history`, plus selector absence and byte preservation. Later current-UCL/identity/policy/fold reason codes are reached through public validators with tagged non-production temporary parents, and root/resolver/publication guards must prove those parents cannot become accepted production authority. |
| CLUBMOD-04 status | The coverage record now says `MECHANICS COVERED; PRODUCTION PENDING`. Automated fixture/release/domain evidence does not complete CLUBMOD-04; its outcome stays `human_needed` until the Roadmap completion gate is satisfied. |

**Resolution status:** ready for final re-review; both remaining blockers are addressed without weakening the Phase 19 goal.
