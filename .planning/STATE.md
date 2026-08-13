---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Model Retrospective and Forecast Evolution
current_phase: 12
current_phase_name: calibration-promotion-and-model-release
status: complete
stopped_at: Completed 12-10-PLAN.md and fresh Phase 12 verification
last_updated: "2026-08-13T08:30:44Z"
last_activity: 2026-08-13
last_activity_desc: Phase 12 re-verification passed all 5 success criteria with no gaps
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 42
  completed_plans: 42
---

# xGelo Project State

## Current Position

Phase: 12 (calibration-promotion-and-model-release) — COMPLETE
Plan: 11 of 11
Status: Phase 12 complete; fresh verification passed 5/5
Last activity: 2026-08-13 — Completed 12-10 and re-verified Phase 12

Progress: [██████████] 100%

## Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 8 | Forecast Ledger and WC 2026 Retrospective | Complete | 6/6 |
| 9 | Rolling Tournament Benchmark Harness | Complete | 5/5 |
| 10 | Statistical Goal-Model Challengers | Complete | 4/4 |
| 11 | Hybrid ML and Contextual Priors | Complete | 5/5 |
| 12 | Calibration, Promotion, and Model Release | Complete | 11/11 |

**Overall:** 5 of 5 phases complete (100%); Phase 12 gap closure is verified

## Project Reference

See `.planning/PROJECT.md` for the product definition, constraints, and current
milestone scope.

**Core value:** Accurate, calibrated international-football forecasting without
dependence on paid data feeds.

**Current focus:** Phase 12 — calibration-promotion-and-model-release

## Decisions

- Treat the 2026 World Cup as a sealed final holdout for model promotion.
- Separate strict pre-match forecasts from exploratory retrospective estimates.
- Compare every model on identical fixtures, folds, seeds, and proper scores.
- Retain the incumbent unless a frozen promotion rule is satisfied.
- Evaluate socio-economic information as a sparse-team structural prior, not as a
  replacement for match-level forecasting.

- [Phase 09]: Represent historical groups with stable edition-local component IDs rather than infer unverified display letters.
- [Phase 09]: Derive regulation scores from checked local goal events through minute 90 while retaining final and shootout outcomes separately.
- [Phase 09]: Permit absolute benchmark registry paths only when they normalize inside the approved project registry root.
- [Phase 09]: Use the conservative registered NB envelope mu=5 theta=8 to seal global score support G=40 across all folds.
- [Phase 09]: Keep output coverage and promotion eligibility as post-prediction observations outside frozen panel membership.
- [Phase 09]: Bootstrap only the 12 paired tournament deltas with seed 920001, 10,000 replicates, and type-8 quantiles.
- [Phase 09]: Require optional-data candidates to pass the production-hybrid rich gate and a complete 630-fixture open-core companion gate.
- [Phase 09]: Derive rich promotion eligibility from observed post-adapter output coverage plus frozen provenance and per-edition floors.
- [Phase 09]: Limit canonical benchmark parallelism to two independent model-track workers after a 4.935-second worst-case fit diagnostic. — Completes both sealed passes in bounded time without changing any fit or evidence semantics.
- [Phase 09]: Preserve every matchday refit and G=40 support while optimizing only execution order, grid access, hashing, and staged publication. — Leakage safety and the frozen D-10 through D-15 statistical contract remain unchanged.
- [Phase 09]: Parent every durable benchmark output to the complete frozen registry and promotion-protocol graph. — Independent validation can reject drift in any checked input, not only model, boundary, or support files.
- [Phase 09]: Preserve source-row presence separately from numeric value presence. — Observed zero must remain distinguishable from missing-then-zero.
- [Phase 09]: Hash feature coverage IDs from run, model, track, boundary, and fixture identity. — Frozen and updating prediction groups must never collide.
- [Phase 09]: Represent venue advantage as checked fixture-derived evidence without a historical source date. — The fixture field is observable without fabricating point-in-time provenance.
- [Phase 09]: Keep all 6,300 prediction rows audit-visible while routing every evaluation consumer through the registered frozen panel. — Preserves the complete audit artifact while preventing output availability from redefining any evaluation denominator.
- [Phase 09]: Separate adapter-emitted feature evidence from observed output coverage. — Evidence validation and post-output promotion eligibility have distinct contracts and must not be conflated.
- [Phase 09]: Include the canonical hybrid goal-training feature content hash in the checked benchmark parent graph. — Bundle read-back must fail when the canonical analytical input drifts.
- [Phase 09]: Canonical benchmark decisions call evaluate_promotion exactly once per registered model with no injectable or hard-coded policy path. — Prevents governance bypass and makes the frozen evaluator the sole authority.
- [Phase 09]: Promotion reproducibility remains false until normal and reversed-order non-decision artifacts reconcile, then final evaluator hashes must match. — Reproducibility is derived evidence rather than a pre-decision assumption.
- [Phase 09]: production_hybrid_nb promotion input combines its rich self-comparison with complete open-incumbent companion evidence. — Preserves the frozen D-19 optional-data shape and 630-fixture open companion contract.
- [Phase 09]: Preserve the accepted seal until staged pre-validation and post-install validation both succeed. — Unique staging plus retained rollback backup prevents an invalid candidate from displacing the known-good bundle.
- [Phase 09]: Evaluate canonical promotion decisions from CSV-persisted numeric views. — Durable read-back is the authority and eliminates sub-precision evaluator/hash drift.
- [Phase 09]: Require fresh-process bundle acceptance with explicit validator dependencies. — Ambient producer-session state cannot serve as standalone validation evidence.
- [Phase 10]: Keep Plan 10-03 Task 1 design contracts free of Task 2 tuning, Elo-offset, and manifest APIs. — This preserves independent RED-to-GREEN ownership for the two production tasks.
- [Phase 10]: Install the official glmnet 5.0 source archive into the ignored project-local Phase 10 library with dependencies disabled. — One retained verified artifact prevents unrelated dependency updates and supports offline replay.
- [Phase 10]: Use official PACKAGES.gz bytes plus the selected package-row hash as repository identity, with C++17 read from the checksum-verified archive DESCRIPTION. — CRAN source index metadata omits SystemRequirements while the verified source DESCRIPTION retains it.
- [Phase 10]: Require complete Phase 9 output hashes, checksum self-hash, parent graph, sealed run flags, and bundle SHA before challenger work. — Manifest declarations alone cannot detect output-byte tampering.
- [Phase 10]: Make each Wave 0 API gate abort its current test with one explicit missing-production-API message so RED evidence cannot be confused with scaffold errors.
- [Phase 10]: Keep dynamic-state and dependence-PMF contracts independent of later sibling tuning, fold-parameter, and manifest APIs.
- [Phase 10]: Use inherited benchmark distribution and market validators for every complete 0:40 dependence grid.
- [Phase 10]: Keep each RED file gated only by the production APIs owned by its downstream task. — Sibling tasks can turn GREEN independently without later APIs.
- [Phase 10]: Use synthetic normal/reversed publication execution in Wave 0. — Historical benchmark execution remains reserved for the explicit Phase 10 gate.
- [Phase 10]: Allow only reproducible whole-file coverage instrumentation exceptions. — Exact source, command, error hash, evidence, and review notes keep the 80-percent gate fail-closed.
- [Phase 10]: Use normalized canonical Phase 9 model-registry SHA semantics — Cross-check the reconstructed identity against both checksum and run manifests.
- [Phase 10]: Hash sorted exact match identities for every eligible inner edition — Retain strict inner-final-date before outer-opener-date chronology.
- [Phase 10]: Keep deeper xG and form ablations present but inactive — All 20,160 relevant Phase 9 open-core evidence rows are source-absent, value-absent, imputed, and inactive.
- [Phase 10]: Measure storage using deterministic high-entropy identifiers and normalized probabilities — Use the exact production score-distribution CSV schema and require byte-identical seeded gzip replays.
- [Phase 10]: Plan 10-03: Treat registered zero-prior and unseen teams as global-zero centered effects while retaining full sparse coefficient blocks and cold-start evidence.
- [Phase 10]: Plan 10-03: Fit canonical Elo only as a no-intercept lasso increment over the immutable centered team-model predictor, preserving exact nesting at zero.
- [Phase 10]: Plan 10-03: Select ridge then Elo penalties from equal-weight completed prior tournaments and reuse one settings identity across frozen and updating tracks.
- [Phase 10]: Represent dynamic evidence as decayed GF, GA, and W sufficient statistics while keeping global pseudo-exposure fixed. — This makes inactivity continuously remove team effects without deleting historical match counts or resetting tournament cycles.
- [Phase 10]: Select dynamic pseudo-exposure by equal-weight completed-prior-tournament updating RPS with the largest pseudo-exposure tie-break. — One deterministic setting identity is selected without assessed-tournament labels and reused across frozen and updating tracks.
- [Phase 10]: Fit Elo only as one signed adapter-supplied point-in-time increment over immutable standalone dynamic log-means. — This preserves exact nesting and prohibits raw rating reads, reconstruction, and nearest-date model-layer lookups.
- [Phase 12]: Keep the five exact Phase 12 validation filenames as the stable downstream test surface.
- [Phase 12]: Keep Wave 0 synthetic and defer production APIs behind explicit RED gates.
- [Phase 12]: Use assembled forbidden tokens so the static boundary scan remains contract-only.
- [Phase 12]: Phase 12 Plan 01 uses the durable Phase 11 hybrid run manifest path as the sole Phase 11 parent identity.
- [Phase 12]: Phase 12 Plan 01 binds a canonical base-R temperature recipe and SHA before any calibration fit.
- [Phase ?]: Use the validated Phase 12 freeze and recipe checksum as a hard pre-fit gate for candidate/track calibration.
- [Phase ?]: Fit deterministic derived-1X2 temperature calibrators only from strictly prior expanding inner-OOF rows, with explicit raw fallback below frozen support floors.
- [Phase ?]: Keep Plan 12-02 durable evidence synthetic and label-free; final evaluation and promotion remain downstream.
- [Phase ?]: Raw versus calibrated derived-1X2 development gate requires strict calibration improvement, non-regressing RPS, inherited score/stability/coverage vetoes, and explicit raw fallback.
- [Phase ?]: Persist all nine candidate/track identities with G=40 support, retaining unavailable states as explicit no-score rows.
- [Phase ?]: Phase 12 Plan 04 admits only phase11_rf_dynamic_elo_open and preserves eight inactive candidates as explicit no-score rows.
- [Phase ?]: Final evaluation preflight is label-free, and the exact opener requires approved state plus a passed unopened preflight.
- [Phase ?]: Final-fit validation reconciles every persisted contract field against freshly derived frozen inputs.
- [Phase ?]: Phase 12 Plan 09: Metadata-only release preflight must validate trusted topology, bundled candidate authority, contract-declared artifact paths, and hashes before any RDS load.
- [Phase ?]: Phase 12 Plan 09: Exported dashboard builders accept only resolver-returned models and reject caller-supplied raw model or baseline arguments.
- [Phase 12]: Plan 12-10 requires exact raw promotion decision-token hashing, unconditional freeze/final-evaluation cross-links, explicit retained-release compatibility, calibrated outcome propagation, and dirty-worktree-safe delta verification.
- [Phase ?]: Bind release authority to canonical paths and byte hashes only after trusted-root topology and evidence links pass.
- [Phase ?]: Keep the immutable retained fixture behind an explicit raw-only missing-freeze-self compatibility branch; new contracts require freeze_self_sha256.
- [Phase ?]: Map the established probability_view=derived_1x2 Phase 12 calibrator identity to the calibrated_1x2 dashboard consumer view.

## Verification Notes

- Phase 12 completed the approved one-shot WC2026 evaluation: source SHA-256 7dd366f457460c435ca3b8bdf9a456cc85903ee639d31f29bbd9c62ff604e1dc, one opener call, 104/104 active fixtures scored, and exact incumbent-retained promotion.

## Pending Todos

The accepted local release is outputs/releases/phase12-wc2026-incumbent-retained-v1.
The exported dashboard consumer boundary gap closure in 12-09-PLAN.md and the final release-integrity/calibrated-consumer gap closure in 12-10-PLAN.md are complete and verified.

## Next Action

Run the next-milestone workflow when ready; Phase 12 is complete and no verification gaps remain.

---
*State reset for milestone v2.0 on 2026-07-20*

## Session

**Last session:** 2026-08-13T08:30:44Z
**Stopped at:** Completed 12-10-PLAN.md and fresh Phase 12 verification
**Resume file:** None

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 09 P01 | 21min | 3 tasks | 14 files |
| Phase 09 P02 | 30min | 3 tasks | 13 files |
| Phase 09 P03 | 18min | 2 tasks | 5 files |
| Phase 09 P04 | 1h 12m | 3 tasks | 16 files |
| Phase 09 P05 | 35min | 2 tasks | 10 files |
| Phase 09 P06 | 56min | 2 tasks | 7 files |
| Phase 09 P07 | 36min | 2 tasks | 4 files |
| Phase 09 P08 | 1h 22m | 2 tasks | 9 files |
| Phase 10 P01 | 8 min | 1 tasks | 3 files |
| Phase 10 P02 | 11 min | 1 tasks | 3 files |
| Phase 10 P10 | 7m | 1 tasks | 4 files |
| Phase 10 P11 | 9 min | 1 tasks | 8 files |
| Phase 10 P09 | 20 min | 2 tasks | 10 files |
| Phase 10 P03 | 15 min | 2 tasks | 2 files |
| Phase 10 P04 | 9 min | 2 tasks | 1 files |
| Phase 10 P05 | 10 min | 2 tasks | 2 files |
| Phase 10 P06 | 15 min | 3 tasks | 4 files |
| Phase 10 P07 | 26 min | 3 tasks | 6 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 11 P08 | 17min | 3 tasks | 1 files |
| Phase 11 P09 | 5min | 2 tasks | 1 files |
| Phase 12 P00 | 7 min | 2 tasks | 5 files |
| Phase 12 P01 | 19 min | 2 tasks | 4 files |
| Phase 12 P02 | 26 min | 2 tasks | 6 files |
| Phase 12 P03 | 32 min | 2 tasks | 3 files |
| Phase 12 P04 | 13m46s | 2 tasks | 4 files |
| Phase 12 P09 | 2h 16m | 2 tasks | 6 files |
| Phase 12 P10 | 37min | 3 tasks | 5 files |
