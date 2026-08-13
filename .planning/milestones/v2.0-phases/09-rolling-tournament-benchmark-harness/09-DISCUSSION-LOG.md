# Phase 9: Rolling Tournament Benchmark Harness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-07-20
**Phase:** 09-rolling-tournament-benchmark-harness
**Areas discussed:** Tournament folds, Training evidence, Baseline contract, Promotion rule

---

## Tournament Folds

| Question | Options presented | Selected |
|----------|-------------------|----------|
| Development tournament universe | 2002 onward; 1998 onward; maximum available history | 2002 onward |
| Forecast timing | Pre-match updating; pre-tournament frozen; equal dual tracks | Pre-match updating, with frozen secondary |
| Fold weighting | Equal tournament; equal fixture; separate competition panels | Equal tournament |
| Sparse optional features | Fixed core plus named panels; core only; paired available subsets | Fixed core plus named panels |

**User's choice:** Use 12 World Cup/Euro folds from 2002 onward, operational
pre-match updates, equal tournament weight, and a fixed open-data core panel.

**Notes:** The user proposed Copa America and Africa Cup of Nations as useful
additional evidence. They were preserved as a deferred expansion because Phase
9 is explicitly scoped to World Cups and Euros.

---

## Training Evidence

| Question | Options presented | Selected |
|----------|-------------------|----------|
| Historical window | Expanding weighted; fixed eight-year; expanding unweighted | Expanding weighted |
| Match types | All with importance tiers; competitive only; all equal | All with importance tiers |
| Weight selection | Fixed common; inner-fold tuning; model-specific | Fixed common |
| In-tournament updates | State only; refit by matchday; refit every fixture | Refit by matchday |

**User's choice:** Supervised models use expanding, recency-weighted history and
fixed match-importance tiers, with model refits between matchdays.

**Notes:** The user explicitly distinguished Elo: it continues to use all
chronological history and its own recursive importance/K-factor logic. Model
features and hyperparameters remain frozen while coefficients may be refitted.

---

## Baseline Contract

| Question | Options presented | Selected |
|----------|-------------------|----------|
| Naive baseline | Uniform plus base rate; uniform only; base rate only | Uniform plus base rate |
| Elo output | Elo-driven goal model; direct multinomial; draw heuristic | Elo-driven goal model |
| Incumbent hierarchy | Open and production incumbents; production only; open only | Open and production incumbents |
| Baseline tuning | Frozen; nested per fold; frozen plus tuned diagnostic | Frozen |

**User's choice:** Register two naive controls, a complete-distribution Elo goal
baseline, the open NB core incumbent, and the production hybrid NB secondary
incumbent. Freeze all baseline settings.

**Notes:** Every baseline must emit the same complete prediction and provenance
schema; incomplete model-specific outputs do not receive a separate scoring path.

---

## Promotion Rule

| Question | Options presented | Selected |
|----------|-------------------|----------|
| Primary RPS gate | Practical plus uncertainty; statistical only; practical only | Practical plus uncertainty |
| Fold consistency | Two-thirds; simple majority; average only | Two-thirds |
| Supporting metrics | Non-inferiority veto; improve everything; advisory only | Non-inferiority veto |
| Sealed WC2026 gate | Confirmatory improvement; non-inferiority; audit only | Confirmatory improvement |

**User's choice:** Require at least `0.003` historical RPS improvement, paired
uncertainty below zero, gains in 8/12 folds, bounded worst-fold regression,
supporting-score non-inferiority, and lower RPS on the sealed WC2026 holdout.

**Notes:** Contract, coverage, licensing, reproducibility, or open-mode failures
veto promotion regardless of average score improvement.

---

## The Agent's Discretion

- Exact fixed recency and match-importance weights.
- Deterministic matchday boundaries across tournament formats.
- Interval estimator, calibration-error metric, adapter/file layout, and report styling.
- Complete scoreline support and explicit tail representation.

## Deferred Ideas

- Add Copa America and Africa Cup of Nations after the World Cup/Euro harness is proven.
