# Phase 13 API Coverage Matrix

This matrix records the public source and API surface for Phase 13. The
integration boundary is operator-supplied, public structured HTTPS JSON from
the official UEFA source, with a reviewed local fallback for publication when
the official source is unavailable.

| capability | decision | reason |
|---|---|---|
| fixtures-json | INTEGRATE | Capture fixture identity, dates, teams, venue context, and match status from the structured fixture resource. |
| groups-json | INTEGRATE | Capture competition groups or league structure needed to build the registry and standings context. |
| standings-json | INTEGRATE | Capture official table rows, points, rank, and tie-break fields when published. |
| results-json | INTEGRATE | Capture completed match scores and result state for form and forecast inputs. |
| status-json | INTEGRATE | Use an explicit status resource when supplied; otherwise derive status only from unambiguous evidence in mandatory resources. |
| reviewed-fallback-source | INTEGRATE | Support a separately reviewed, provenance-preserving fallback capture for publication when official structured capture cannot be refreshed. |
| bounded-http-retry | INTEGRATE | Retry only bounded transient failures with timeouts and an explicit JSON Accept header. |
| raw-payload-provenance | INTEGRATE | Preserve source URL, capture metadata, and raw-byte SHA-256 so accepted data can be audited and replayed. |
| schema-validation | INTEGRATE | Fail closed on non-JSON responses, missing mandatory resources, malformed tables, schema drift, or hash mismatch. |
| staged-publication | INTEGRATE | Validate a complete bundle before promotion and retain the prior accepted bundle for rollback. |
| endpoint-discovery | OPT-OUT | Endpoint discovery is intentionally operator-supplied; Phase 13 does not implement an unrestricted crawler or undocumented endpoint scraper. |
| rendered-html-scraping | OPT-OUT | The contract accepts structured JSON only; rendered page or PDF scraping is outside the supported source boundary. |
| webhook-push-updates | OPT-OUT | Refresh is an explicit batch capture in the file-based pipeline; no push or webhook service is required. |
| authenticated-private-api | OPT-OUT | The project uses public official resources and reviewed fallback evidence, not private credentials or authenticated vendor APIs. |
| paid-third-party-feed | OPT-OUT | No paid feed is part of the open-data source contract for this phase. |

The matrix is deliberately scoped to source acquisition, validation, and
publication capabilities. Competition-specific endpoint URLs remain explicit
configuration and are not inferred from a broad discovery process.
