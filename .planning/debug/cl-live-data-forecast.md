---
status: investigating
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
next_action: Implement the production source-to-state adapter and genuine historical
club corpus/evaluation path. Live data acquisition, acceptance and promotion are working.

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

Prepared the exact 36 mappings in proposed_current_ucl_review.csv. David Zenz
explicitly approved these mappings and the 36-club/144-match expectation in chat
on 2026-10-27. Applied that review to current_ucl_owner_review.csv and the
generation-backed identity registry; preserved the original pending proposals.

Published a fresh, validating acceptance generation, preserving the old edited
generation unchanged. The real four-resource acceptance probe passed. Fixed three
additional production defects revealed by activation: normalized-only storage now
honors the approved no-durable-raw-cache policy through exact hash receipts;
new schema observation timestamps no longer invalidate unchanged schemas; and
explicit null-row evidence preserves absent winner/scores on CSV round-trip.

The first live bundle and a second repeatable update both passed candidate
validation and atomic accepted-source promotion. The current local source has
36 clubs, 144 fixtures, 54 completed results and 90 upcoming fixtures. No raw
response JSON is retained in candidate or accepted generations.

Added update_ucl_live_source.R and render_ucl_live_dashboard.R. The local dashboard
shows accepted facts independently of forecast availability, preserves null scores,
uses provider attribution and exposes stale/last-accepted state. Browser checks
passed at desktop and 390px widths; all counts reconcile, no page overflow, no
forecast rows, and implementation metadata is collapsed.

Fixed missing stats::setNames imports in the closed Phase 20 CLI/targets
environments. They can now read the accepted source; the production outcome path
truthfully blocks on fixture_schema_incomplete. The Phase 18 provider tables still
need a source-backed adapter to the Phase 20 fixture/venue/lineage/score contract.

Fixed production current-roster validation in model_contract.R: source-generation
tables were incorrectly accessed through the bundle data frame, edition identity
was read through a nonexistent nested bundle, and the source pointer was shadowed
by the identity pointer. The genuine production club loader now returns ready
with 36 clubs and validates both distinct source and identity generations.

Verification: the complete adapter suite and existing complete club release suite
passed. New staging serialization and invalid-graph tests passed separately
(9 assertions). Three bounded acceptance-controller checks passed (19 assertions).
The final cache/future/missing-response-date checks also passed. Changed R sources
parse and `git diff --check` passes.

A broader source-acceptance attempt exposed the original invalid review hash and
missing Rscript PATH in subprocesses; subsequent commands include the installed R
directory. The new acceptance generation validates, but historical tests assuming
committed pending/no-key production state require migration before the aggregate
Phase 18 suite can be treated as a current-state production gate.

Activation verification: full source-bundle, refresh-failure and club-domain suites
passed; full Phase 21 publication and live-dashboard suites passed. New tests cover
raw-receipt tampering/inventory, schema timestamp vs drift, null/empty/literal-NA
round-trip, source-only facts without model authority, stale views and isolated
runtime read-back. No national dashboard or approved-model selector was changed.

Source diff hygiene passes. Generated immutable ACCEPTANCE.md files retain their
writer-produced final blank line; these two generated-only EOF warnings are not
repaired in place because accepted evidence generations are immutable.
