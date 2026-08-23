# Phase 16: EURO Qualifying Activation and Play-off Rules - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-08-23
**Phase:** 16-EURO Qualifying Activation and Play-off Rules
**Areas discussed:** Draw activation boundary, Host-reserved places, Best runners-up and play-off topology, Pre-draw visibility and unavailable-state behavior

---

## Draw activation boundary

### Question 1: What makes the edition active after the draw?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Require a complete official draw-and-schedule bundle; status, groups, stable IDs, and complete fixtures are required, while initial standings/results may be empty. | ✓ |
| 2 | Activate as soon as any official draw snapshot exists, even if the schedule is incomplete. | |
| 3 | Keep the edition pre-draw until the first completed match. | |

### Question 2: What fixture evidence is required for activation and forecasts?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Every official pairing needs a stable fixture ID and confirmed kickoff before activation and forecast eligibility. | ✓ |
| 2 | Allow pairings without confirmed kickoff and add forecasts later. | |
| 3 | Activate from team pairings alone and treat schedule identity as optional. | |

### Question 3: How should post-draw corrections be published?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Validate a new complete official source bundle and atomically replace the active bundle. | ✓ |
| 2 | Patch the affected rows directly in the active bundle. | |
| 3 | Rebuild the full edition without retaining a source-bundle revision. | |

### Question 4: What should remain visible during revision validation?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Keep the last accepted bundle active, show a refresh/revision warning, and isolate the candidate. | ✓ |
| 2 | Show the candidate immediately with a provisional label. | |
| 3 | Hide the edition until the candidate is accepted. | |

**User's choice:** Option 1 for all four questions.
**Notes:** The activation boundary is deliberately strict, but the initial active bundle may contain no completed standings or results.

---

## Host-reserved places

### Question 1: How should host places be represented?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use explicit conditional host slots separate from direct qualification, with occupied, unused, or unresolved states. | ✓ |
| 2 | Treat hosts as ordinary qualifiers and apply host treatment only during final allocation. | |
| 3 | Leave host treatment unresolved until the official rules are explicit. | |

### Question 2: How should host capacity be handled when a host qualifies directly?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use an allocation ledger; direct qualification consumes the relevant host slot first and prevents double counting. | ✓ |
| 2 | Report host qualification independently and leave final capacity unresolved. | |
| 3 | Treat host slots as guaranteed and remove hosts from ordinary qualification immediately. | |

### Question 3: What if the host guarantee is unresolved?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Publish a conditional or `host_place_unresolved` state and no fabricated qualification probability. | ✓ |
| 2 | Keep the host as a normal qualifier with a warning. | |
| 3 | Block all qualification output until the host rule is resolved. | |

### Question 4: Where should host treatment be visible?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Show qualification status and source/rules lineage in the main qualification table. | ✓ |
| 2 | Show it only in an outcome panel. | |
| 3 | Keep it in metadata and audit records only. | |

**User's choice:** Option 1 for all four questions.
**Notes:** Host treatment is a first-class qualification state and must remain auditable without consuming capacity twice.

---

## Best runners-up and play-off topology

### Question 1: How should the play-off structure be modeled?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Derive the topology from accepted official rules/source data, support every valid official format, and mark incomplete formats unresolved. | ✓ |
| 2 | Implement the expected play-off bracket as a fixed format. | |
| 3 | Provide a generic play-off table without simulating the topology. | |

### Question 2: How should Nations League-linked eligibility enter the model?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Consume Phase 15 transition outcomes by stable `team_id` and require a complete accepted eligibility bundle. | ✓ |
| 2 | Infer eligibility from current Nations League rankings and qualifying status. | |
| 3 | Use an operator-maintained eligibility list without a source bundle. | |

### Question 3: How should best runners-up be calculated?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Calculate after direct qualifiers and host allocations using official tie-break rules; remain unavailable until complete. | ✓ |
| 2 | Publish provisional best runners-up from current standings. | |
| 3 | Show the runners-up ranking but do not produce qualification probabilities. | |

### Question 4: How should topology changes be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Use versioned, replayable rules/source revisions with atomic publication and prior-version retention until validation. | ✓ |
| 2 | Hardcode the expected play-off shape and update it manually. | |
| 3 | Permit an operator override without a new source or rules revision. | |

**User's choice:** Option 1 for all four questions.
**Notes:** The topology and eligibility logic must be data-driven and fail closed rather than assume the expected UEFA format.

---

## Pre-draw visibility and unavailable-state behavior

### Question 1: What should be visible before the official draw?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Show status, draw date, source confidence, refresh timestamp, warnings, and empty/unavailable sections. | ✓ |
| 2 | Add team-strength context but no qualification probabilities. | |
| 3 | Show only a minimal pre-draw status. | |

### Question 2: How should empty sections be represented?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Keep schema-valid empty tables with explicit `pre_draw` or `unavailable` statuses. | ✓ |
| 2 | Hide sections until rows exist. | |
| 3 | Use provisional teams or placeholder structures. | |

### Question 3: How should forecasts behave before draw and schedule publication?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Publish no fixture-level or qualification probabilities; expose an edition-level unavailable status with the reason. | ✓ |
| 2 | Publish team-strength context and indicative probabilities. | |
| 3 | Hide all forecast sections. | |

### Question 4: What should the visible pre-draw message include?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | State that the dashboard awaits the official draw, show expected date, refresh time, source bundle, and the reason forecasts are unavailable. | ✓ |
| 2 | Show only pre-draw and the expected draw date. | |
| 3 | Show a generic data-unavailable message without source or timing details. | |

**User's choice:** Option 1 for all four questions.
**Notes:** Pre-draw behavior is explicit, informative, schema-stable, and contains no invented competition structure or probabilities.

---

## Claude's Discretion

- Exact module boundaries, table names, column order, compact artifact paths, and status reason enum names within existing contracts.
- The official UEFA rules-adapter and topology representation after research, provided it supports every valid official shape and fails closed on incomplete rules.
- Presentation details inside the existing dashboard payload; the shared renderer is Phase 17.

## Deferred Ideas

- Shared dashboard rendering, responsive filtering, hourly launchd refresh, browser smoke checks, atomic cross-competition promotion, and compact auto-push remain Phase 17.
- Full historical EURO qualifying editions and broader live-event evaluation remain future work.

---

*Phase: 16-euro-qualifying-activation-and-play-off-rules*
*Discussion log generated: 2026-08-23*
