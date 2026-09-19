# Phase 18 Multi-Source Coverage Audit

| SOURCE | ID | Feature / constraint | Plan | Status | Notes |
|---|---|---|---|---|---|
| GOAL | — | Lawful current and historical UCL data through stable club identities without credential or accepted-state risk | 18-01..18-06 | COVERED | Provider decision, club identity, transport/probe, accepted bundle, rollback, and history corpus are separate slices. |
| REQ | UCLSRC-01 | Live-key and owner-reviewed provider acceptance gate | 18-01, 18-03 | COVERED | No-key/manual-only are valid disabled outcomes; first acceptance uses only the bounded no-cache `live_acceptance_probe`, then ordinary live ingestion requires its manifest. |
| REQ | UCLSRC-02 | Secret-safe complete current UCL ingestion | 18-03 | COVERED | Fixed four-resource boundary plus reviewed lifecycle expectations for exactly 36 league-phase clubs, 144 league-phase fixtures, allowed stages, and standings shape. |
| REQ | UCLSRC-03 | Provenance and content hashes on accepted artifacts | 18-06 | COVERED | Complete raw/canonical/row/manifest hash chain and discriminated source authority. |
| REQ | UCLSRC-04 | Last-known-good preservation and typed blocked refresh | 18-04 | COVERED | Technical failure matrix and byte-equivalence proof are separate from reviewed provider-exit retain/withdraw compliance transactions. |
| REQ | CLUBID-01 | Stable validity-aware club identity | 18-02 | COVERED | Separate club namespace, reviewed current/history bootstrap, explicit validity intervals, durable unresolved ledger, and no auto-merge. |
| REQ | CLUBHIST-01 | Pinned licensed audited historical corpus | 18-05 | COVERED | Inventory-driven corpus with exact eligibility gates and a shared owner-reviewed identity bootstrap over every declared token. |
| RESEARCH | — | Use installed R/httr2/jsonlite/digest/testthat stack; no package install | 18-01, 18-03, 18-05, 18-06 | COVERED | Package legitimacy gate is not applicable. |
| RESEARCH | — | Two-part machine plus owner decision artifact | 18-01, 18-03 | COVERED | Terms changes invalidate prior approval; bounded probe breaks first-acceptance dependency without authorizing normal ingestion. |
| RESEARCH | — | Fixed host, redacted process-local token, bounded retry/throttle | 18-03 | COVERED | Arbitrary URLs and per-ID crawls are excluded. |
| RESEARCH | — | Exact accepted-bundle hash graph and trusted roots | 18-06 | COVERED | Extends Phase 13 contracts after transport/probe acceptance is proven. |
| RESEARCH | — | Independent lifecycle completeness expectations | 18-01, 18-03 | COVERED | Reviewed expectation hash blocks truncated or excessive club, schedule, stage, and standings state. |
| RESEARCH | — | Discriminated live/manual/fixture authority | 18-06, 18-04 | COVERED | Plan 18-06 defines exact mutually exclusive IDs/hashes; Plan 18-04 recomputes them and rejects fixture authority. |
| RESEARCH | — | Separate normalized club/source-ID/alias registries | 18-02, 18-03, 18-05 | COVERED | A1 is implemented with one reviewed bootstrap shared by current and historical source tokens. |
| RESEARCH | — | Pinned OpenFootball inputs, audit family, evidence time | 18-05 | COVERED | A2/A3 remain explicitly flagged assumptions with executable boundaries. |
| RESEARCH | — | Candidate-first last-known-good transaction | 18-04 | COVERED | Technical failures preserve incumbent bytes; provider exit uses separately reviewed retain or atomic withdraw/tombstone behavior. |
| CONTEXT | — | No phase CONTEXT.md exists | — | EXCLUDED | The user authorized direct planning from research and requirements. |

No source item is missing. The resolved research decisions are explicit: owner terms remain a human gate, live completeness is established only by the bounded acceptance probe, the five-season inventory is audit-only, and date-only evidence uses frozen next-day UTC availability. Deferred v4.x enhancements, Phase 19 models, Phase 20 rules/simulations, and Phase 21 dashboard rendering are intentionally outside Phase 18.
