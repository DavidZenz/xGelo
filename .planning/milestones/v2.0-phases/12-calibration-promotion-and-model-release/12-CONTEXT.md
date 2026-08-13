# Phase 12: Calibration, Promotion, and Model Release - Context

**Gathered:** 2026-08-10  
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 12 freezes the Phase 11 candidate set, calibrates candidate probabilities without outer-fold leakage, opens the sealed WC2026 evaluation exactly once, and publishes either a qualifying challenger or an explicit incumbent-retained release. The phase covers calibration, freeze/checksum manifests, final evaluation, promotion, release packaging, and fail-closed dashboard/export consumption.

The phase does not reopen model discovery after the freeze, activate new data or features, relax the Phase 9 promotion protocol, or use WC2026 labels for fitting, calibration, or selection.
</domain>

<decisions>
## Locked Decisions

### Calibration

- **D-01:** Calibrate derived 1X2 probabilities first. Preserve the fitted goal distribution and derive the calibrated match-outcome probabilities from it; do not introduce full score-distribution calibration in this phase.
- **D-02:** Fit calibration separately for every candidate and track, using that model's own inner out-of-fold predictions.
- **D-03:** Use expanding prior-tournament inner-OOF history, preserving chronology and preventing future-tournament leakage.
- **D-04:** Use calibrated output as primary only when it improves calibration and triggers none of the frozen RPS, Brier, log-loss, fold-stability, or coverage vetoes. Otherwise retain raw output as primary.

### Candidate Freeze

- **D-05:** Freeze all nine registered Phase 11 candidates, including inactive xG/context/structural candidates. Inactive candidates must remain explicit no-score rows rather than disappearing from the registry.
- **D-06:** Freeze candidate code, features, settings, panels, seeds, calibration recipes, and promotion thresholds before fitting any calibration recipe.
- **D-07:** No candidate activation or specification change is allowed after the freeze. New evidence or a new candidate requires a new reviewed benchmark phase.
- **D-08:** One aggregate Phase 12 freeze manifest is authoritative. It must identify the candidate registry, code commit, feature/settings/panel/seed/calibration/threshold hashes, and parent-graph identities.

### One-Shot Holdout Gate

- **D-09:** Any preflight failure aborts before WC2026 labels are opened. Repair requires a new reviewed freeze and rerun.
- **D-10:** Once opened, WC2026 labels are copied into an immutable final-evaluation artifact used only by scoring and reporting. They never enter fitting, calibration, or selection.
- **D-11:** Run every frozen candidate that passes its admissibility gate; retain inactive candidates as explicit no-score rows in the final registry and report.
- **D-12:** Publish an append-only final-evaluation manifest linking the freeze hash, label hash, run timestamp, candidate/prediction/score hashes, coverage, and promotion decision.

### Release Fallback

- **D-13:** If no challenger clears every promotion gate, use the incumbent version that passes the same raw-versus-calibrated development gate. Publish alternatives as audit-only.
- **D-14:** Publish a versioned complete release bundle containing the approved model object, model contract, freeze and final-evaluation manifests, benchmark report, model card, provenance, limitations, and reproducibility metadata.
- **D-15:** Dashboard and export consumers may load a model only through the approved release manifest and model contract. They must fail closed on missing or mismatched hashes.
- **D-16:** A no-promotion outcome must publish a versioned release explicitly stating `incumbent retained`, together with challenger results and gate failures. The release contract remains usable.

### Existing Protocol Constraints

The Phase 9 promotion protocol remains authoritative. The core challenger gate is challenger-minus-incumbent RPS <= -0.003 with a confidence-interval upper bound below zero, at least 8 of 12 improving folds, at least 2 World Cup and 2 Euro wins, and maximum fold regression <= 0.015. Supporting Brier/log-loss and calibration-change vetoes, plus probability, distribution, fixture, coverage, provenance, license, seed, checksum, reproducibility, code, feature, settings, panel, and `wc2026` sealing vetoes remain in force. Phase 12 plans must implement these existing values rather than restate or alter them.
</decisions>

<canonical_refs>
## Canonical References

### Phase and project contracts

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-CONTEXT.md`
- `.planning/phases/09-rolling-tournament-benchmark-harness/09-VERIFICATION.md`
- `.planning/phases/10-statistical-goal-model-challengers/10-CONTEXT.md`
- `.planning/phases/10-statistical-goal-model-challengers/10-VERIFICATION.md`
- `.planning/phases/11-hybrid-ml-and-contextual-priors/11-CONTEXT.md`
- `.planning/phases/11-hybrid-ml-and-contextual-priors/11-VERIFICATION.md`

### Promotion and evaluation protocol

- `data/benchmark/phase09/promotion_protocol.json`
- `R/evaluation/benchmark_scores.R`
- `R/evaluation/promotion.R`
- `R/evaluation/challenger_selection.R`
- `R/evaluation/worldcup_retrospective.R`

### Benchmark execution and consumers

- `R/benchmark/runner.R`
- `R/benchmark/challenger_runner.R`
- `_targets.R`
- `tests/testthat/test_benchmark_promotion.R`
- `tests/testthat/test_benchmark_scoring.R`
- `tests/testthat/test_statistical_targets.R`
</canonical_refs>

<code_context>
## Existing Codebase Context

### Reusable assets

- `R/evaluation/benchmark_scores.R` already provides fixed-bin calibration, proper scoring rules, score support, paired comparisons, and metric summaries. Phase 12 should extend or compose these helpers instead of creating a parallel scoring contract.
- `R/evaluation/promotion.R` loads and validates the locked protocol and evaluates the promotion gates. The Phase 12 release decision should consume this contract.
- `R/evaluation/challenger_selection.R` contains evidence-linked shortlist and non-promotion selection patterns that can support the final audit report.
- `R/benchmark/runner.R` and `R/benchmark/challenger_runner.R` provide common schemas, panel routing, manifests, target/holdout protection, coverage checks, and publication patterns.
- `_targets.R` is file-oriented and should remain the orchestration boundary for durable artifacts.
- `R/visualization/worldcup_retrospective.R` contains established calibration and report-plot patterns for the final benchmark report.

### Established patterns to preserve

- Use explicit R scripts and functions with source paths consistent with the existing project.
- Keep benchmark contracts deterministic, retain the fixed `G = 40` score support, and fail closed instead of silently dropping fixtures or repairing invalid artifacts.
- Put all randomness behind explicit seeds and record seeds/checksums in manifests.
- Use `stop()`-style validation for missing, malformed, mismatched, or unapproved artifacts.
- Keep development folds/panels and the sealed `wc2026` final evaluation strictly separate.

### Integration points

- Phase 9, 10, and 11 durable bundles, candidate registries, and parent manifests feed the Phase 12 freeze manifest.
- Calibration must consume inner-OOF predictions only; outer-fold and WC2026 labels are evaluation-only.
- The final-evaluation artifact and append-only manifest feed the promotion report and release bundle.
- Dashboard and export code must resolve the approved release manifest/model contract rather than selecting the latest artifact by path or modification time.
- Phase 12 should minimize reruns: preflight and freeze checks happen before the one-shot final evaluation, and the sealed holdout is opened only after every precondition passes.
</code_context>

<specifics>
## Implementation Specifics

- The primary calibration object is the derived 1X2 probability vector; the underlying goal distribution remains unchanged.
- Each candidate/track gets its own chronology-safe calibrator trained on expanding prior-tournament inner-OOF history.
- Raw versus calibrated selection is a development-stage decision governed by calibration improvement and the existing score/stability/coverage vetoes.
- The nine-candidate freeze must include inactive optional candidates with explicit no-score status and admissibility reasons.
- The aggregate freeze manifest must make code, feature, settings, panel, seed, calibration, threshold, and parent-graph identities independently auditable.
- The final evaluation is a one-time `wc2026` label opening for scoring/reporting only. Its output must be immutable and append-only from the audit perspective.
- A release must be complete and versioned even when the incumbent is retained. The human-facing no-promotion status is exactly `incumbent retained`.
</specifics>

<deferred>
## Deferred Ideas

None. Discussion stayed within the Phase 12 boundary.
</deferred>
