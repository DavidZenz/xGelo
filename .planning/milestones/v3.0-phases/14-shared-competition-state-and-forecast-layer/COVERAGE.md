# API Coverage - UEFA Match API

> Full coverage by default. Opt-outs are explicit, reasoned decisions.
>
> Phase 14 uses one bounded official UEFA match collection as the external
> source boundary. The adapter preserves the exact response bytes and projects
> the collection into the existing fixtures, groups, standings, results, and
> status contracts. It does not scrape rendered UEFA pages.

| capability | decision | reason |
|---|---|---|
| `GET /v5/matches` for UEFA Nations League 2026/27 | INTEGRATE | Official match collection used by the Phase 14 correction runner. |
| Competition and season filtering via `competitionId` and `seasonYear` | INTEGRATE | The approved endpoint is pinned to competition 2014 and season 2027. |
| Bounded result retrieval via `offset` and `limit` | INTEGRATE | The current 156-fixture edition is retrieved with the approved limit of 200. |
| Optional `x-api-key` request authentication | INTEGRATE | An operator-supplied key is supported without embedding or logging credentials. |
| Retry, rate-limit, and response validation boundary | INTEGRATE | The shared structured-fetch contract applies bounded acquisition and fail-closed payload validation. |
| Fixture projection from the match collection | INTEGRATE | The adapter emits the accepted fixture resource and preserves source IDs and hashes. |
| Group projection from the match collection | INTEGRATE | Groups are derived from validated official match data; no fabricated groups are created. |
| Standings projection from the match collection | INTEGRATE | Standings inputs are retained for the shared state contract and reconciled before publication. |
| Result projection from the match collection | INTEGRATE | Completed scores and completion semantics are normalized through the canonical match contract. |
| Match-status projection from the match collection | INTEGRATE | Lifecycle and availability status are emitted as an explicit accepted resource. |
| Team and competition metadata in the match payload | INTEGRATE | Official IDs and metadata feed the stable identity and edition-scoped registries. |
| Exact raw-byte and source-URL provenance | INTEGRATE | Raw response bytes, URL lineage, retrieval time, parser identity, and hashes are persisted locally and in manifests. |
| Rendered UEFA HTML page scraping | OPT-OUT | The UEFA page is retained as a public provenance reference only; Phase 14 parses structured data, not rendered page text. |
| Pagination beyond the approved single-page edition retrieval | OPT-OUT | The current edition fits within the approved limit; multi-page retrieval is deferred until an edition exceeds that bound. |
| EURO 2028 qualifying post-draw endpoint and group activation | OPT-OUT | EURO remains `pre_draw` in Phase 14; official draw and topology handling belong to Phase 16. |
| Live match events and real-time score polling | OPT-OUT | Phase 14 is a bounded snapshot/correction boundary; live refresh belongs to the later dashboard operations phase. |
| Lineups, player availability, injuries, odds, and tracking feeds | OPT-OUT | These capabilities are outside the Phase 14 competition-state and forecast contract and have no approved open source boundary. |
| Unbounded automated or hourly external polling | OPT-OUT | Acquisition is operator-triggered and rate-limited; atomic hourly public refresh belongs to Phase 17. |
