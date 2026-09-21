---
phase: 19-independent-club-forecast-authority
verified: 2026-09-21T17:16:16Z
status: human_needed
score: 4/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Install the accepted Phase 18 club-history generation and verify its fixed pointer, corpus manifest, matches, registry, source manifest, cutoff, and snapshot identities are accepted by the production loader."
    expected: "phase19_load_club_training_snapshot() returns ready in production mode with the accepted immutable generation and matching Phase 18 identities."
    why_human: "The repository intentionally has no accepted external club-history generation; credentials, source acceptance, and licensing are owner/provider actions."
  - test: "Install the accepted non-tombstone current-UCL refresh and exact current identity-registry generation, then run the production current-UCL loader."
    expected: "The accepted UCL edition, source bundle, source authority, identity generation, and roster hash validate; disconnected or incomplete club graphs remain blocked."
    why_human: "Current-UCL acceptance and identity-generation provenance are external evidence, not safely synthesizable from the fixture corpus."
  - test: "Complete and accept policy_review.json and fold_review.json with owner, UTC review time, decision, and exact candidate/gate/seed/feature/protocol/history/fold/calibration parent hashes."
    expected: "Production policy and fold authorities become ready only when both exact owner reviews validate; pending or relabeled fixture reviews remain blocked."
    why_human: "Owner approval and review provenance cannot be established by source inspection or an automated fixture."
  - test: "Run the production two-family evaluation from the accepted source graph, confirm every predeclared gate and paired replay passes, then produce the production promotion decision."
    expected: "The candidate is promoted only with authority_eligibility=production, diagnostic_gate_outcome=pass, promotion_status=promoted, and incumbent/candidate identities bound to the accepted evidence."
    why_human: "This requires genuine accepted history/current-UCL data and owner-reviewed folds; the committed tree is deliberately blocked before model work."
  - test: "Stage/install the resulting production release and resolve it twice through outputs/releases/club/approved_release.csv, including the model-card and bidirectional domain checks."
    expected: "One immutable release generation is selected by the atomic self-hashed club selector and the production resolver reads it back without selector-window drift; national consumers reject it and club consumers reject national releases."
    why_human: "No production candidate or selector is present by design; fixture releases are temporary diagnostic artifacts and cannot satisfy this gate."
  - test: "Re-run the cross-phase regression inventory once the pre-existing Phase 12 approved-model artifact required by those regressions is available."
    expected: "Phase 18, national release, Phase 14 forecast/state, and Phase 15 regressions execute without being blocked by missing external release material."
    why_human: "The missing Phase 12 artifact predates Phase 19 and is an external repository/release prerequisite, not a Phase 19 implementation defect."
---

# Phase 19: Independent Club Forecast Authority Verification Report

**Phase Goal:** Forecast consumers can use an immutable, independently validated club-football release that cannot be confused with national-team authority.
**Verified:** 2026-09-21T17:16:16Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Club fixtures receive forecasts only from club-only rating and goal models, without national-team features, releases, or selectors. | ✓ VERIFIED | `R/club/model_contract.R`, `R/club/rating.R`, `R/club/goal_model.R`, the closed candidate registry, fixed-root loaders, and the final adversarial/domain suites enforce `forecast_domain=club`; national objects are rejected. |
| 2 | Analysts can reproduce frozen rolling-origin and held-out-league evaluations with exclusive information cutoffs and same-kickoff/date leakage protection. | ✓ VERIFIED | `R/club/evaluation_protocol.R` materializes both fold families with strict completion/evidence/boundary checks, nested roles, held-out exclusion, canonical row hashes, and exact declared-fixture coverage; fold and evaluation tests passed. |
| 3 | A club candidate is approved only after proper-score, calibration, coverage, reproducibility, and integrity gates pass against the documented incumbent. | ✓ VERIFIED | `R/club/evaluation.R` performs paired scoring and ordered immutable gate evaluation over `candidate=club_elo_nb` versus `incumbent=club_venue_nb`; calibration, replay, coverage, and source-regeneration tests passed. |
| 4 | Consumers can resolve one immutable model-card-backed production club release with symmetric national/club domain rejection. | ? HUMAN NEEDED | The complete staged/installed/resolved mechanics and bidirectional guards exist and fixture round-trip tests pass, but no genuine accepted Phase 18/current-UCL source graph, owner-approved policy/folds, production promotion, or production selector exists in the committed tree. |
| 5 | Current xG, injury, lineup, suspension, and player inputs remain typed unavailable evidence unless a separate lawful source contract is accepted. | ✓ VERIFIED | The exact five-row `data/club/model_protocol/feature_contract.csv` is validated in `R/club/model_contract.R`; unavailable fields reject activation, imputation, and formula use, with domain-contract tests passing. |

**Score:** 4/5 roadmap truths verified (the remaining truth is an explicit external completion gate, not an implementation gap).

## Plan Must-Have Coverage

All 10 plans and all declared truth items were accounted for. The status below distinguishes verified implementation mechanics from the deliberately absent external production authority.

| Plan | Truth inventory and result |
| --- | --- |
| 19-01 | Five truths verified: fixed accepted-history/current-UCL loaders and reason codes; isolated fixture authority; typed five-feature unavailable contract; national boundary rejection. |
| 19-02 | Four truths verified: registered club IDs and prior regulation results; simultaneous exact-kickoff/date batch updates; permutation-stable pre/post state; current-UCL graph coverage fails closed. |
| 19-03 | Four truths verified: immutable candidate/control/parameter/seed/gate policy with owner-review binding; `club_elo_nb` versus `club_venue_nb` and report-only controls; all gates predeclared; no national protocol constants. |
| 19-04 | Four truths verified: two immutable fold families and owner-review parent binding; exclusive nested boundaries; held-out exclusion from fit/tuning/calibration; committed production protocol truthfully blocked. |
| 19-05 | Four truths verified: strict prior-only club fitting; converged registered NB or explicit failure with no fallback; exact 1,681-cell 0:40 grids and derived markets; unavailable enrichment cannot activate. |
| 19-06 | Four truths verified: prior-only inner OOF calibration; raw/calibrated views preserve the goal distribution; calibration gate cannot bypass a proper-score veto; calibrator identity binds all parents/support/cutoffs/optimizer. |
| 19-07 | Five truths verified: exact paired two-family evaluation; persisted scores/bins/coverage/convergence/summaries/bootstrap/replay; incumbent retained unless every gate passes; diagnostic/authority/promotion status separation; production prerequisite and current-roster graph checks. |
| 19-08 | Truths 2–4 verified by metadata-first release validation, model-card/selector topology, domain guards, fixture-only publication, and rollback tests. Truth 1 (a promoted production candidate actually installed and selector-authorized) and truth 5 (phase completion after production readback) remain human-needed because the required external authority is absent. |
| 19-09 | Truths 2–4 verified: separate `club_*` targets namespace, club-only dependency chain, and explicit temporary-root fixture path. Truth 1's missing-authority fail-closed behavior is verified, but its genuine accepted production happy path and truth 5's production-completion condition remain human-needed. |
| 19-10 | Truths 1–5 verified by the exact adversarial inventory, fresh-process test gate, 30-prohibition one-to-one map, protected production-byte snapshots, and boundary-only reason-code probes. Truth 6 is pending the pre-existing Phase 12 artifact for cross-phase regressions; truth 7 intentionally remains human-needed until a real reviewed selector resolves. |

No plan truth was classified as a Phase 19 code gap. The human-needed items are the completion gate expressly stated in ROADMAP.md and REQUIREMENTS.md.

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `R/club/model_contract.R` | Club authority snapshot, blocked results, feature contract | ✓ VERIFIED | Fixed production roots, accepted-generation identity checks, fixture separation, typed unavailable enrichment, national rejection. |
| `R/club/rating.R` | Batch-safe independent club rating replay | ✓ VERIFIED | Closed parameters, strict time boundaries, simultaneous updates, component audit, replay digest/source validation. |
| `R/club/evaluation_protocol.R` | Candidate/gate/seed policy and immutable fold protocol | ✓ VERIFIED | Exact registries, canonical-v2 hashes, owner-review schemas, two fold families, blocked production state. |
| `R/club/goal_model.R` | Registered club NB models and deterministic score grids | ✓ VERIFIED | No family fallback, strict prior cutoff, exact 1,681-cell grid, source-regenerated fit/prediction identities. |
| `R/club/calibration.R` | Prior-only club calibration and view selection | ✓ VERIFIED | Inner OOF role checks, fixed temperature recipe, paired raw/calibrated evidence, gate-controlled primary view. |
| `R/club/evaluation.R` | Paired scoring, replay, integrity, authority, promotion | ✓ VERIFIED | Exact denominator pairing, source graph replay, production wrapper, incumbent-retaining blocked semantics. |
| `R/club/release.R` | Immutable release/model card/selector/resolver | ✓ VERIFIED (mechanics) | Metadata-first validation, trusted-root paths, atomic install/selector reread, production parent graph; production tree intentionally has no release yet. |
| `R/release/domain_contract.R`, `R/release/release_contract.R`, `R/competition/forecast_layer.R` | Symmetric club/national domain guards | ✓ VERIFIED | Explicit expected-domain checks reject cross-domain releases/objects at resolver and consumer boundaries. |
| `scripts/run_phase19_club_evaluation.R`, `_targets.R` | Closed CLI and separate targets DAG | ✓ VERIFIED | Fixed production source order and typed blocked record; `club_*` targets stop before fit/release/selector when prerequisites are blocked. |
| `data/club/model_protocol/*` | Frozen registries and truthful blocked production descriptors | ✓ VERIFIED | Candidate/gate/seed/feature/calibration policy is hash-valid; production fold registry is truthfully header-only and state/review are pending/blocked. |
| `outputs/releases/club/approved_release.csv` | Production selector | ? HUMAN NEEDED | Correctly absent; creating it without accepted external authority would violate the phase contract. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Club model contract | Phase 18 history/UCL/identity readers | Fixed pointer/generation loaders and exact parent hashes | ✓ WIRED | Production loaders reject arbitrary paths and fail closed on the committed blocked state. |
| Rating replay | Goal model | Typed pre-boundary `rating_difference` and replay identities | ✓ WIRED | Goal fitting validates the complete replay source and snapshot/current-UCL parents. |
| Protocol registries | Fold/evaluation/calibration | Exact registry/table hashes and review parent fields | ✓ WIRED | Fold, calibration, evaluation, and gate functions compare the fixed parent graph. |
| Goal model | Calibration/evaluation | Typed predictions, score grids, and source regeneration | ✓ WIRED | Calibration changes only derived 1X2; evaluation consumes exact 0:40 grids and paired rows. |
| Evaluation authority | Release | Production writer requires promoted decision plus complete typed source graph | ✓ WIRED | Validation occurs before RDS/object use and before rename/selector write. |
| Club release | Club resolver / national consumers | Self-hashed club selector and expected-domain guard | ✓ WIRED (fixture; production pending) | Fixture resolver round trips and cross-domain rejection tests pass; production selector is intentionally absent. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| Club rating | pre-match club ratings/differences | Accepted history rows and current-UCL roster graph | Yes in fixture mode; production blocked without accepted inputs | ✓ FLOWING / production gated |
| Club goal predictions | NB means, 1,681-cell distributions, markets | Typed rating replay + registered formulas + prior history | Yes in fixture mode; no fabricated production fallback | ✓ FLOWING / production gated |
| Club calibration | raw/calibrated 1X2 views | Inner OOF source rows and frozen recipe | Yes in fixture mode, with source hashes | ✓ FLOWING |
| Evaluation/promotion | scores, bins, coverage, bootstrap, gate decision | Exact paired candidate/incumbent fold inputs | Yes in fixture mode; production requires accepted authority | ✓ FLOWING / production gated |
| Release resolver | model card, model/calibrator objects | Atomic selector → exact manifest/inventory/hash graph | Fixture release only; production selector absent by design | HUMAN NEEDED |

## Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
| --- | --- | --- | --- |
| Paired evaluation and promotion authority | `Rscript --vanilla scripts/run_phase19_focused_test.R tests/testthat/test_phase19_club_evaluation.R` | 14 tests / 84 assertions, pass | ✓ PASS (directly run) |
| Cross-boundary adversarial regression | Final-tree authoritative run of `test_phase19_adversarial_regression.R` | Zero failures after final verifier-scope fixes | ✓ PASS (authoritative final evidence) |
| Release/selector/domain/transaction regression | Final-tree authoritative run of `test_phase19_club_release.R` | Zero failures after final verifier-scope fixes | ✓ PASS (authoritative final evidence) |
| Protocol, folds, rating, goal model, calibration, and pipeline contracts | Earlier focused suites and final integrated validation record | Passed; production blocked state is asserted | ✓ PASS (authoritative final evidence) |

## Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| `scripts/verify_phase19_contracts.R` | Final-tree aggregate verifier | Final independent authority verdict reports 0 blockers / 0 warnings; protected production state remains unchanged and truthful blocked output is preserved | ✓ PASS (authoritative final evidence) |

## Requirements Coverage

| Requirement | Source plans | Status | Evidence |
| --- | --- | --- | --- |
| CLUBMOD-01 | 19-01, 19-02, 19-05, 19-08, 19-09 | ✓ SATISFIED | Independent club IDs/rating/NB models, no national dependency, domain guards, and club-only orchestration. |
| CLUBMOD-02 | 19-04, 19-05, 19-06, 19-07, 19-09 | ✓ SATISFIED | Frozen rolling/held-out folds, strict cutoffs, same-batch checks, prior-only calibration, and persisted paired evaluation. |
| CLUBMOD-03 | 19-03, 19-04, 19-06, 19-07, 19-09 | ✓ SATISFIED | Predeclared immutable gate registry and ordered promotion decision with proper-score/calibration/coverage/replay/integrity checks. |
| CLUBMOD-04 | 19-08, 19-09, 19-10 | ? NEEDS HUMAN | Release, selector, model-card, resolver, and bidirectional guards are implemented and fixture-tested, but genuine accepted parents, owner reviews, production promotion, and selector readback are absent. REQUIREMENTS.md intentionally remains unchecked. |
| CLUBMOD-05 | 19-01, 19-05, 19-08, 19-09 | ✓ SATISFIED | Exact typed unavailable enrichment registry and fail-closed formula/imputation guards. |

No Phase 19 requirement is orphaned: all five IDs are declared in ROADMAP.md, REQUIREMENTS.md, and the Phase 19 plan set. CLUBMOD-04 is the intentional external completion gate, not an unimplemented code path.

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| Phase 19 implementation files | No unreferenced `TBD`, `FIXME`, or `XXX` completion markers; no placeholder user-visible output or static production data path found | Info | Intentional empty/header-only production artifacts are validated blocked states, not stubs. |
| `data/club/model_protocol/fold_registry.csv`, `outputs/releases/club/` | Empty/absent production artifacts | Info / human gate | Required while accepted history/current-UCL/reviews are unavailable; manufacture would be a security/provenance defect. |

## Human Verification Required

The automated implementation gate is complete. The remaining actions are external and must not be fabricated:

1. Accept and pin a real Phase 18 club-history generation with source/license and exact corpus/manifest/registry identities.
2. Accept and pin a non-tombstone current-UCL source bundle plus exact current identity-registry generation and roster graph.
3. Obtain owner acceptance of the exact candidate/gate/seed/feature policy and generated fold inventory, including reviewer/time and parent hashes.
4. Run the real two-family evaluation/replay and confirm the candidate passes every frozen gate against `club_venue_nb` before marking authority production-ready.
5. Install the immutable production club release, write its atomic selector, resolve it twice, and complete club↔national rejection checks.
6. Restore the pre-existing Phase 12 approved-model artifact if the cross-phase regression inventory is required; then rerun those regressions.

## Gaps Summary

No implementation gaps found. The committed production controller correctly remains `human_needed`/blocked, does not start model work, does not create a release or selector, and leaves the incumbent as the production authority while genuine accepted external club authority is unavailable. Fixture success is diagnostic-only (`fixture_ineligible`/`ineligible_fixture`) and cannot close CLUBMOD-04.

---

_Verified: 2026-09-21T17:16:16Z_  
_Verifier: the agent (gsd-verifier)_
