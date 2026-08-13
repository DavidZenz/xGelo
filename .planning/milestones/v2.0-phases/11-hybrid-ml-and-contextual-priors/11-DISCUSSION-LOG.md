# Phase 11: Hybrid ML and Contextual Priors - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-08-08
**Phase:** 11-Hybrid ML and Contextual Priors
**Areas discussed:** RF and team ability, open context and tournament coverage, structural prior and xG activation, enriched and external modes

---

## RF and team ability

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Two goal forests, one for home goals and one for away goals, with a common score-distribution adapter. | ✓ |
| 2 | Direct 1X2 random forest. | |
| 3 | Random-forest residual correction around the statistical mean. | |

**User's choice:** 1
**Notes:** The selected architecture is the primary Groll-style replication. The common output must remain a full score distribution.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Combine RF-predicted goal means with registered/tuned negative-binomial marginals. | ✓ |
| 2 | Combine RF-predicted goal means with Poisson marginals. | |
| 3 | Learn the score distribution directly. | |

**User's choice:** 1
**Notes:** Negative-binomial marginals preserve the established football-goal overdispersion treatment.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Reuse fold-local Phase 10 dynamic attack/defence abilities plus Elo as separate inputs. | ✓ |
| 2 | Re-estimate RF-specific attack/defence abilities inside each training fold. | |
| 3 | Use Elo only as the ability proxy. | |

**User's choice:** 1
**Notes:** The ability signal must remain independently estimated from the forest and point-in-time auditable.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Compare with the strongest Phase 10 baseline on identical folds and require consistent proper-score improvement or non-inferiority, with no automatic promotion. | ✓ |
| 2 | Select on one chosen metric even if other scores worsen. | |
| 3 | Use tournament-level hit rate as the main acceptance criterion. | |

**User's choice:** 1
**Notes:** Phase 11 reports challenger evidence; Phase 12 retains the final promotion decision.

## Open context and tournament coverage

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Register host, neutral venue, rest, travel, and tournament stage, with separate ablations. | ✓ |
| 2 | Start with host, neutral venue, and rest, adding travel and stage only if stable. | |
| 3 | Use one combined context model without individual ablations. | |

**User's choice:** 1
**Notes:** Incremental value must be attributable to each named context feature.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Freeze the existing core and use Copa America and AFCON for supplemental training plus separately labelled regional diagnostics. | ✓ |
| 2 | Add Copa America and AFCON directly to the core benchmark and recompute denominators. | |
| 3 | Use Copa America and AFCON only as separate evaluation sets. | |

**User's choice:** 1
**Notes:** Regional additions must not silently change the established 630/609 benchmark panels or their estimand.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use a strict common open-context panel, retain the baseline's established panel, report explicit counts, and do not silently impute. | ✓ |
| 2 | Impute unavailable context values and add missingness indicators. | |
| 3 | Let every model variant use its own eligible subset. | |

**User's choice:** 1
**Notes:** Coverage and denominator differences remain visible for every context variant.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use deterministic rest, travel, and stage proxies with source, vintage, derivation, and missingness records. | ✓ |
| 2 | Use detailed stadium, route, altitude, and time-zone travel information. | |
| 3 | Use rest and venue only and defer travel. | |

**User's choice:** 1
**Notes:** Reproducible great-circle travel and date-derived rest are preferred to a high-burden routing layer.

## Structural prior and xG activation

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use point-in-time, vintage-aware structural data only as a sparse-team shrinkage prior. | ✓ |
| 2 | Use current structural values as ordinary model features. | |
| 3 | Use a structural prior only for a current snapshot. | |

**User's choice:** 1
**Notes:** The structural lineage is used to stabilize sparse evidence, not to leak current values into historical folds.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use continuous evidence-weighted shrinkage toward the structural prior. | ✓ |
| 2 | Use a fixed sparse-team threshold with a hard switch or blend. | |
| 3 | Add raw structural variables directly to the RF or goal model. | |

**User's choice:** 1
**Notes:** The prior's role remains isolated and interpretable.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use a recency-weighted effective match count. | ✓ |
| 2 | Use the raw number of prior matches. | |
| 3 | Use a manually defined sparse/not-sparse label. | |

**User's choice:** 1
**Notes:** Prior influence decreases smoothly as relevant recent evidence accumulates.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Activate xG only after a strict point-in-time coverage, variance, and provenance gate. | ✓ |
| 2 | Activate xG whenever any point-in-time xG data exists. | |
| 3 | Keep xG permanently isolated to an enriched mode. | |

**User's choice:** 1
**Notes:** When the gate fails, xG is explicitly inactive and missing is not treated as observed zero.

## Enriched and external modes

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Implement a point-in-time enriched squad mode using local derived aggregates. | ✓ |
| 2 | Use current squad information across the historical benchmark. | |
| 3 | Define a squad feature contract but defer implementation. | |

**User's choice:** 1
**Notes:** No automated collection or raw restricted-data redistribution; the open default remains independent.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use a manually frozen point-in-time external bookmaker benchmark with timestamp, source, and licensing metadata. | ✓ |
| 2 | Automate bookmaker collection. | |
| 3 | Defer bookmaker consensus entirely. | |

**User's choice:** 1
**Notes:** The market benchmark remains external and outside open-data candidate selection.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Report open default, enriched squad, and external market as three separate modes. | ✓ |
| 2 | Create one combined enhanced model. | |
| 3 | Put all modes into one common candidate-selection pool. | |

**User's choice:** 1
**Notes:** Different information and licensing sets must remain directly visible.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Keep promotion eligibility mode-specific; only open data can compete for the open default. | ✓ |
| 2 | Allow enriched squad models to replace the open default if they score better. | |
| 3 | Rank all modes together and note licensing afterward. | |

**User's choice:** 1
**Notes:** Enriched and external modes are research/reference outputs, not open-default candidates.

## Claude's Discretion

- Exact RF tuning grid and package wiring.
- Exact structural variable registry, historical vintages, shrinkage parameterization, and numerical xG gate thresholds, subject to pre-registration and chronology safety.
- Concrete open-data source and derivation schemas for the context fields.
- Derived squad aggregates, permitted bookmaker representation, and report layout within licensing and mode boundaries.

## Deferred Ideas

- XGBoost after stable RF evidence.
- Automated restricted-data collection.
- Current structural snapshots in historical folds and unrestricted raw structural RF features.
- A changed primary denominator that directly includes Copa America or AFCON.
- A pooled leaderboard or promotion path across open, enriched, and external modes.
- Final 2026 holdout opening and final promotion/release decisions in Phase 12.
