# Phase 10: Statistical Goal-Model Challengers - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 10-statistical-goal-model-challengers
**Areas discussed:** Penalized Poisson design, Dynamic ability role, Score dependence, Incumbent ablations

---

## Penalized Poisson Design

### Registered structure

| Option | Description | Selected |
|--------|-------------|----------|
| Nested pair | Minimal team-effects-plus-venue model and an open-covariate variant | Yes |
| Literature-rich single model | One model combining team effects and all open covariates | |
| Pure team-strength model | Team effects and venue only | |

### Penalty roles

| Option | Description | Selected |
|--------|-------------|----------|
| Stabilize teams, select covariates | Grouped/ridge team shrinkage plus sparse covariate selection | Yes |
| Elastic net for everything | One common penalty mixture | |
| Sparse everything | Team and covariate effects may all disappear | |

### Tuning boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Before each assessment tournament | Tune on earlier tournaments, then freeze | Yes |
| One global penalty | Use one value across all folds | |
| Retune every matchday | Repeat model selection within the assessed edition | |

### Cold starts

| Option | Description | Selected |
|--------|-------------|----------|
| Global shrinkage | Sparse/unseen team effects revert to zero on the log scale | Yes |
| Elo initialization | Initialize effects from point-in-time Elo | |
| Confederation fallback | Use regional priors | |

**User's choice:** Recommended option in all four questions.
**Notes:** Preserve every fixture and make cold-start evidence explicit.

---

## Dynamic Ability Role

### Relationship to Elo

| Option | Description | Selected |
|--------|-------------|----------|
| Both controlled variants | Standalone dynamic model and dynamic-plus-Elo model | Yes |
| Standalone replacement | Dynamic ratings without Elo | |
| Additional signal only | Elo mandatory in the dynamic model | |

### Update rhythm

| Option | Description | Selected |
|--------|-------------|----------|
| Matchday batches | Same-boundary fixtures share the same prior state | Yes |
| Every fixture | Update using kickoff order where available | |
| Tournament windows | Freeze ratings through wider windows | |

### Update signal

| Option | Description | Selected |
|--------|-------------|----------|
| Observed goals only | Use scored/conceded goals on the complete open panel | Yes |
| Goals plus outcome | Blend scores with result information | |
| xG when available | Mix xG with actual-goal fallback | |

### Memory policy

| Option | Description | Selected |
|--------|-------------|----------|
| Continuous mean reversion | Preserve history but decay inactive teams toward global | Yes |
| Fixed recent window | Drop old matches | |
| Tournament-cycle reset | Reset at World Cup-cycle boundaries | |

**User's choice:** Recommended option in all four questions.
**Notes:** Dynamic ability must distinguish replacement value from value beyond Elo.

---

## Score Dependence

### Common backbone

| Option | Description | Selected |
|--------|-------------|----------|
| Same independent-Poisson backbone | Isolate dependence while holding means fixed | Yes |
| Independently optimized backbones | Let each correction choose predictors | |
| Incumbent NB backbone | Correct the incumbent means | |

### Parameter flexibility

| Option | Description | Selected |
|--------|-------------|----------|
| One global parameter per fold | Estimate on prior data and freeze for assessment | Yes |
| Era/tournament-specific | Vary dependence across periods | |
| Match-specific | Predict dependence from fixture features | |

### Representative selection

| Option | Description | Selected |
|--------|-------------|----------|
| RPS-first gated selection | Primary RPS plus supporting-score and stability vetoes | Yes |
| Joint-score log loss only | Optimize observed scoreline probability | |
| Always bivariate Poisson | Prefer the richer model whenever valid | |

### Negligible gains

| Option | Description | Selected |
|--------|-------------|----------|
| Retain independence as preferred | Name a research representative without forcing adoption | Yes |
| Carry correction forward anyway | Prefer explicit dependence despite negligible gain | |
| Drop dependence entirely | Nominate no reusable representative | |

**User's choice:** Recommended option in all four questions.
**Notes:** The representative dependence implementation and preferred release candidate may differ.

---

## Incumbent Ablations

### Ablation structure

| Option | Description | Selected |
|--------|-------------|----------|
| Hierarchical ablations | Test blocks first, then split only when justified | Yes |
| Leave one feature out | Remove predictors individually | |
| Every combination | Exhaustive subset search | |
| Regularized selection only | No predeclared ablation variants | |

### Zero-coverage features

| Option | Description | Selected |
|--------|-------------|----------|
| Declare inactive and simplify | Remove zero-coverage columns | |
| Keep zero-coded predictor | Preserve formula compatibility with inactive evidence | Yes |
| Mark untestable and retain | Leave formula unchanged without an activity verdict | |

### Simplification standard

| Option | Description | Selected |
|--------|-------------|----------|
| Practical non-inferiority | Prefer smaller model when scores and stability do not regress materially | Yes |
| Require improvement | Simplify only when scores improve | |
| Coefficient significance | Decide from fitted coefficient diagnostics | |

### Phase 12 handoff

| Option | Description | Selected |
|--------|-------------|----------|
| Small evidence-based shortlist | Best score, simplest non-inferior, dependence representative | Yes |
| One statistical winner | Nominate one model now | |
| Every valid candidate | Carry the full model set | |

**User's choice:** Hierarchical ablations, zero-coded compatibility, practical non-inferiority, and a small shortlist.
**Notes:** Inactive zero-coded columns must never be represented as observed zero measurements.

---

## The Agent's Discretion

- Exact model matrix and identifiability constraints.
- Package-level implementation and deterministic optimization details.
- Tuning grids, mean-reversion formula, and predeclared practical margins.
- Candidate identifiers, report presentation, and plan decomposition.

## Deferred Ideas

None.
