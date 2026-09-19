---
phase: 14
plan: 18
type: data-correction
status: ready-for-resume
bundle_id: nl-2026-27-official-uefa-v2
tags: [uefa, nations-league, provenance, identity, match-state]
---

# Plan 14-18 Data Correction: Official UEFA Nations League 2026/27

The fictional Nations League sample acceptance was replaced by a reproducible, immutable official UEFA schedule bundle. Plan 14-18 is ready to resume; this correction does not mark the plan complete.

## Official provenance

- Source page: <https://www.uefa.com/uefanationsleague/fixtures-results/>
- Structured endpoint: <https://match.uefa.com/v5/matches?competitionId=2014&seasonYear=2027&offset=0&limit=200>
- Retrieved: `2026-08-17T20:48:22Z`
- Raw bytes: `1,498,534`
- Raw SHA-256: `a8b9a1d9c4329a33ffa15a447cb84f2cf92c01caac9668f46d3f0f0abeaed4cd`
- Parser commit: `d32212133188a152583ab6fd6e98a6dea25c0ce4`

The adapter validates the official competition/season payload, preserves exact raw-byte hashes and URL lineage for each compact resource, and accepts an optional externally supplied public API key without embedding or logging a credential. Raw JSON remains in the existing ignored local raw store; committed registries retain its exact relative paths and hashes.

## Published contract

- `nl-2026-27-official-uefa-v2`: 156 fixtures, 14 groups, 156 scheduled results, 54 teams.
- All official rows are `UPCOMING` with confirmed kickoff timestamps; no Austria/Germany production fixture exists.
- Official standings are an empty, schema-valid pre-kickoff table; Phase 14 computes provisional zero standings.
- All 54 official teams resolve by UEFA source ID with stable existing xGelo IDs, FIFA/country codes, canonical names, and non-empty aliases.
- The canonical match-identity graph was rebuilt and validated at 49,832 rows (49,520 historical rows plus 156 fixture and 156 result rows), including fresh row/table hashes.
- Active source registries contain the official Nations League v2 bundle and the unchanged EURO qualifying bundle. EURO remains `pre_draw` for the 2026-12-06 draw with `phase14-open-nb-incumbent-calibrated-v1` authority.

## Tests

Focused Phase 13/14 regressions passed with no warnings or skips:

- Production UEFA contract: 58 assertions.
- Phase 13 source contracts: 175 assertions.
- Phase 13 competition registry: 162 assertions.
- Phase 13 publication integration: 175 assertions.
- Phase 14 match state: 370 assertions.
- Phase 14 forecast layer: 128 assertions.
- Phase 14 state bundle: 129 assertions.

Synthetic Austria/Germany rows remain only in explicitly labelled unit/replay cases and are not production evidence. Production tests now cover the official counts, source IDs, kickoff state, raw lineage, identity resolution, and preserved release authority.

## Correction record and deviations

- The production adapter, acquisition flags, and live-only correction runner were added before publication. The runner fails closed when the official payload cannot be fetched or validated; it has no local `/tmp` replay path.
- Expanding official FIFA codes and aliases changed the dependent martj42 identity map and its normalized historical artifact identity hash. Stable xGelo IDs and historical match semantics were preserved; the complete canonical graph was regenerated through production helpers.
- The old sample acceptance is retained only in refresh history as an audit record of the rejected/corrected sequence; it is not an active bundle or production fixture source.

## Plan 14-18 readiness

`STATE.md` now records the ac61f06 blocker as resolved. The next executor may resume Plan 14-18 against `nl-2026-27-official-uefa-v2`; it must not confirm or use the synthetic Austria/Germany row as a real fixture.

## Self-Check: PASSED

- Correction summary and updated `STATE.md` exist.
- Official counts, raw SHA lineage, no-synthetic-pair invariant, and the 49,832-row match-identity hash graph validate successfully.
- Adapter commit `d322121` exists in Git history.
