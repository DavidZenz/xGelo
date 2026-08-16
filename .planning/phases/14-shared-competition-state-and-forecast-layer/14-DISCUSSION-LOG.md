# Phase 14: Shared Competition State and Forecast Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-08-16
**Phase:** 14-shared-competition-state-and-forecast-layer
**Areas discussed:** Match states and score semantics, standings and ranking boundary, form windows and cutoffs, forecast contract, shared inputs versus isolated state

---

## Match States and Score Semantics

| Decision | Alternatives considered | Selected |
|----------|-------------------------|----------|
| Source and canonical status | Keep both; canonical only; source only with consumer interpretation | Keep canonical `match_status` plus original `source_status` |
| Extra time and penalties | One overloaded status; separate lifecycle and completion axes | Separate `match_status` and `completion_method` |
| Score representation | One final score; separate regulation/final/shootout scores and winner | Separate score fields; awarded score marked explicitly |
| Eligibility | One completed flag; separate standings and form eligibility | Separate `counts_for_standings` and `counts_for_form` |

**User's choice:** Approved all recommended two-axis, explicit-score, and separate-eligibility contracts.
**Notes:** Awarded matches may affect standings but should not distort played-form evidence.

---

## Standings and Ranking Boundary

| Decision | Alternatives considered | Selected |
|----------|-------------------------|----------|
| Standings authority | UEFA only; computed only; dual with reconciliation | Computed metrics plus official rank/points |
| Tie-break ownership | Guess shared ordering; implement all rules now; adapter boundary | Universal metrics now, competition adapters in Phases 15/16 |
| Snapshot identity | Latest table only; cutoff- and bundle-scoped snapshots | Edition/group/cutoff/source-bundle key |
| Reconciliation failure | Always warn; always block; severity by mismatch type | Block aggregate mismatches, warn rank-only differences |

**User's choice:** Approved dual authority, point-in-time snapshots, and severity-based reconciliation.
**Notes:** Official rank remains the display authority when available; computed rank is provisional without the edition adapter.

---

## Form Windows and Cutoffs

| Decision | Alternatives considered | Selected |
|----------|-------------------------|----------|
| Form windows | One shared window; last-five display plus existing model EWMA | Last 5 for display, span 12 EWMA for the model |
| Competition form | Carry prior editions; current edition only | Current edition only, with explicit sample count |
| International form | Competitive matches only; all senior A internationals | Include friendlies and retain competition type |
| Cutoff | Inclusive date; latest available; strict pre-kickoff | Exclusive cutoff with conservative date-only handling |

**User's choice:** Approved all recommended windows, scopes, and cutoff rules.
**Notes:** Missing descriptive form remains unavailable; it is not silently imputed.

---

## Forecast Contract

| Decision | Alternatives considered | Selected |
|----------|-------------------------|----------|
| Forecast eligibility | Omit unavailable fixtures; forecast every row; explicit suppression | Scheduled confirmed fixtures only, with suppression rows/reasons |
| Probability views | Raw only; calibrated only; calibrated primary plus raw audit | Approved calibrated primary view plus raw audit values |
| Scoreline support | Truncated dashboard grid only; full unbounded output; approved bounded canonical support | Full G=40 canonical distribution plus top-10 projection |
| Uncertainty | Qualitative badge; simulation count only; distribution-derived metadata | Entropy, mass, intervals, method, and availability status |
| Current raw-release conflict | Relabel raw values; publish raw temporarily; require calibrated release | Fail closed until a validated calibrated release revision is approved |

**User's choice:** Approved calibrated consumer probabilities, invariant G=40 scorelines, quantitative uncertainty, and the calibration-release prerequisite.
**Notes:** Inspection confirmed the current release declares `raw_1x2` and calibrator `fit_status = raw_fallback`; raw probabilities must never be labeled calibrated.

---

## Shared Inputs Versus Isolated State

| Decision | Alternatives considered | Selected |
|----------|-------------------------|----------|
| Ownership boundary | Shared competition tables; duplicated shared inputs; explicit boundary | Shared identity/model/history, edition-scoped competition state |
| Match duplication | Keep source rows independently; fuzzy deduplication; canonical match identity | One canonical `match_id` with both source lineages |
| Forecast lineage | Generation timestamp only; release ID only; full compact lineage | State, release, identity, evidence, support, and generation lineage |
| Failure propagation | Block both builds always; publish healthy edition; independent builds under atomic publication | Shared failures affect both, edition failures remain local, public batch stays atomic |

**User's choice:** Approved the explicit ownership boundary, canonical deduplication, complete lineage, and failure-isolation rule.
**Notes:** A healthy edition may still build for diagnosis, but Phase 17 must retain the last complete public batch when either edition fails.

## Claude's Discretion

- Exact R module boundaries, table names, column ordering, hash projections, and compact paths.
- Deterministic central-interval calculation and complete machine-readable reason enums.
- Focused fixture sizes and helper decomposition used to test the production contracts.

## Deferred Ideas

- Nations League ranking and outcome rules remain Phase 15.
- EURO qualification and play-off topology remain Phase 16.
- Simulation publication, shared dashboards, and atomic hourly operations remain Phase 17.
