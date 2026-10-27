---
status: awaiting_owner_review
trigger: "can we fix the live data and forecast model issue for the CL dashboard?"
created: 2026-10-27
updated: 2026-10-27
---

## Symptoms

Expected: current Champions League fixtures/results and club forecasts on the dashboard.
Actual: production source and model paths remain unavailable.
Reproduction: fixed Phase 18 provider adapter, Phase 19 production controller,
and Phase 20 production outcome entrypoint.

## Current Focus

hypothesis: Confirmed separate adapter defects and incomplete production model wiring.
test: Focused adapter and staging regressions plus a live projection with provisional
in-memory mappings. Production remains untouched while owner review is pending.
next_action: Obtain approval of the prepared 36-club mapping and league-phase counts;
then create fresh provider acceptance evidence and promote the validated source.

## Evidence

- Normal project R startup finds the configured provider token; shell lookup does not.
- A genuine owner terms review exists from 2026-09-25; saved refresh state is from 2026-09-20.
- Empty club registries and blocked history prevent production model evaluation.
- Production controller and staging contain unconditional blockers even beyond input readiness.
- Four real API resources returned HTTP 200 for 2026/27 with 36 clubs and 144 league-phase fixtures.
- Real competition metadata was last edited in May and some club profiles in 2021;
  neither timestamp measures current match-data freshness.
- Standings contains TOTAL, HOME and AWAY tables. The original adapter combined all three.
- The repaired live projection returned 36 clubs, 144 matches and 36 reconciled
  standings rows with passing response freshness. This was diagnostic-only using
  provisional mappings in memory, without acceptance or production mutation.
- The existing provider acceptance generation fails its stored review_sha256:
  its terms review was modified after publication. A new immutable generation is
  required; the old generation must not be silently rehashed in place.
- Accepted historical club results are still absent. Policy/fold reviews remain
  pending. CLI, targets evaluation/promotion and forecast consumption need further
  production implementation before model publication can be claimed.

## Resolution

Fixed the adapter's response freshness, league-phase TOTAL selection, standings
reconciliation, cross-resource season checks, bounded live transport and identity
lookup date. Preserved actual entity-edit timestamps and legacy offline evidence.

Replaced unconditional production release-staging rejection with a shared writer
behind complete source-graph validation. Production installation still independently
validates the graph and controls the approved selector. No production model was
trained or promoted.

Prepared the exact 36 mappings in proposed_current_ucl_review.csv with pending
status and a reusable preparation script. Owner approval is pending in chat.

Verification: the complete adapter suite and existing complete club release suite
passed. New staging serialization and invalid-graph tests passed separately
(9 assertions). Three bounded acceptance-controller checks passed (19 assertions).
The final cache/future/missing-response-date checks also passed. Changed R sources
parse and `git diff --check` passes.

A broader source-acceptance attempt exposed the existing invalid review hash and
missing Rscript PATH in subprocesses; subsequent test commands explicitly include
the installed R binary directory. The broader acceptance suite is not claimed green.
