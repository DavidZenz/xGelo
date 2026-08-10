# Phase 12: Calibration, Promotion, and Model Release - Discussion Log

> Audit trail of decisions made during phase discussion. This records the selected direction before planning begins.

**Date:** 2026-08-10  
**Phase:** 12 - Calibration, Promotion, and Model Release  
**Areas discussed:** Calibration; candidate freeze; one-shot holdout gate; release fallback

---

## Calibration

| ID | Decision | Selected direction |
|---|---|---|
| D-01 | Probability object | Derived 1X2 probabilities; preserve the goal distribution. |
| D-02 | Calibration scope | Fit separately per candidate and track using each model's own inner-OOF predictions. |
| D-03 | Historical window | Expanding prior-tournament inner-OOF history with chronology preserved. |
| D-04 | Raw versus calibrated output | Calibrated primary only when calibration improves without RPS, Brier, log-loss, fold-stability, or coverage vetoes; otherwise raw primary. |

**User's choice:** `1, 1, 1, 1` across the calibration questions.

**Notes:** The calibration boundary is deliberately narrow and compatible with the existing fixed-bin scoring contract. Full score-distribution calibration is deferred rather than mixed into the first release candidate.

## Candidate Freeze

| ID | Decision | Selected direction |
|---|---|---|
| D-05 | Candidate set | Freeze all nine registered Phase 11 candidates, including inactive optional candidates with explicit no-score gates. |
| D-06 | Freeze timing | Freeze code, features, settings, panels, seeds, calibration recipes, and thresholds before any calibration fit. |
| D-07 | Post-freeze changes | Do not activate or change candidates after the freeze; new evidence requires a new reviewed benchmark phase. |
| D-08 | Authoritative artifact | Use one aggregate Phase 12 freeze manifest containing candidate, code, feature, settings, panel, seed, calibration, threshold, and parent-graph identities. |

**User's choice:** `1, 1, 1, 1` across the candidate-freeze questions.

**Notes:** Inactive candidates remain visible for auditability and are not silently removed from the release comparison.

## One-Shot Holdout Gate

| ID | Decision | Selected direction |
|---|---|---|
| D-09 | Preflight failure | Abort before WC2026 labels open; repair through a new reviewed freeze and rerun. |
| D-10 | Label handling | Copy opened labels into an immutable final-evaluation artifact used only for scoring and reporting. |
| D-11 | Evaluation set | Run every frozen candidate with a passing admissibility gate; retain inactive candidates as explicit no-score rows. |
| D-12 | Audit record | Publish an append-only manifest linking freeze, label, prediction, score, coverage, timestamp, and promotion hashes. |

**User's choice:** `1, 1, 1, 1` across the one-shot holdout questions.

**Notes:** The WC2026 evaluation is a one-time opening. Labels cannot flow backward into fitting, calibration, candidate selection, or threshold changes.

## Release Fallback

| ID | Decision | Selected direction |
|---|---|---|
| D-13 | No qualifying challenger | Retain the incumbent that passes the same raw-versus-calibrated development gate; keep alternatives audit-only. |
| D-14 | Release contents | Publish a versioned complete bundle with model object, model contract, freeze/final-evaluation manifests, benchmark report, model card, provenance, limitations, and reproducibility metadata. |
| D-15 | Consumer contract | Dashboard/export load only through the approved release manifest and model contract and fail closed on hash mismatches. |
| D-16 | No-promotion communication | Publish a versioned release stating `incumbent retained`, with challenger results and gate failures; keep the release contract usable. |

**User's choice:** `1, 1, 1, 1` across the release-fallback questions.

**Notes:** The Phase 9 promotion protocol and its locked thresholds remain authoritative. Phase 12 implements the protocol and does not renegotiate it.

## Claude's Discretion

The implementation may choose internal function boundaries, file names, target names, release version naming, manifest field ordering, deterministic hash serialization, test fixture construction, and exact validation error wording. These choices must preserve the locked decisions, existing benchmark contracts, and fail-closed behavior.

## Deferred Ideas

None. No out-of-scope ideas were carried forward from discussion.
