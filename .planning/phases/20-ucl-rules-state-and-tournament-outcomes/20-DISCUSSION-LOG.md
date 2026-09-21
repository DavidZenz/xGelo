# Phase 20: UCL Rules, State, and Tournament Outcomes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-21
**Phase:** 20-ucl-rules-state-and-tournament-outcomes
**Mode:** `--auto`
**Areas discussed:** Rules authority and tie resolution, league schedule and forecast ledger, league-phase probability outputs, knockout path conditioning and match resolution, reproducibility and fail-closed artifacts

---

## Rules authority and tie resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Editioned rules contract with provider reconciliation | Recompute standings from accepted matches and preserve provider standings only as audit evidence. | ✓ |
| Provider table as authority | Accept source ranks without independently applying UCL rules. | |
| Generic or random fallback | Use points/GD plus lexical or random ordering when later evidence is missing. | |

**Selection:** Recommended fail-closed option selected automatically.
**Notes:** Late unavailable criteria produce an unresolved rank interval and suppress exact-rank-dependent paths.

## League schedule and forecast ledger

| Option | Description | Selected |
|--------|-------------|----------|
| Exact complete schedule and immutable ledger | Validate all 36 clubs/144 fixtures and retain the selector-authorized pre-kickoff forecast or typed suppression for every fixture. | ✓ |
| Accept partial schedules | Compute state from whatever subset the source currently exposes. | |
| Infer or regenerate | Guess missing pairings or regenerate old forecasts after results. | |

**Selection:** Recommended complete-contract option selected automatically.
**Notes:** Production does not become available through fixture or partial evidence.

## League-phase probability outputs

| Option | Description | Selected |
|--------|-------------|----------|
| Condition on accepted results with full distributions | Fix completed results and publish bands, all ranks, and cut lines. | ✓ |
| Resimulate the whole phase | Treat settled matches as uncertain on every run. | |
| Summary-only output | Publish only qualification bands or expected rank. | |

**Selection:** Recommended conditional/full-distribution option selected automatically.
**Notes:** Top-8, play-off, and eliminated are mutually exclusive and exhaustive.

## Knockout path conditioning and match resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Legal path distribution then accepted-draw conditioning | Use only rank-constrained legal paths and switch to the exact accepted draw when available. | ✓ |
| Fixed assumed bracket | Hard-code one future bracket before a draw exists. | |
| Uniform pairing | Pair teams without UCL draw restrictions. | |

**Selection:** Recommended legal-path option selected automatically.
**Notes:** Two-leg aggregate, leg order, no away goals, extra time, penalties, and neutral final remain stage-specific rules.

## Reproducibility and fail-closed artifacts

| Option | Description | Selected |
|--------|-------------|----------|
| Complete input-bound identity and strict invariants | Hash all authoritative inputs, enforce reconciliation/monotonicity, and reproduce canonical bytes. | ✓ |
| Seed-only identity | Treat the RNG seed as sufficient run provenance. | |
| Partial/fallback publication | Publish fixture-backed or incomplete probability artifacts when production authority is missing. | |

**Selection:** Recommended complete-authority option selected automatically.
**Notes:** Identical inputs reproduce bytes; blocked production emits typed diagnostics without overwriting incumbents.

## Claude's Discretion

- Exact R module boundaries, artifact names, reason enums, row order, and test fixture sizes.
- Deterministic enumeration versus seeded sampling for future legal draw paths, subject to bounded runtime and verified legality.

## Deferred Ideas

- Dashboard presentation and atomic N-edition publication (Phase 21).
- Scheduled refresh and release hardening (Phase 22).
- What-if scenarios and richer forecast-change explanations (future v4.x).
