# Phase 18 External API Coverage — football-data.org v4

**Scope:** `https://api.football-data.org/v4`, competition code `CL`, season `2026`  
**Status:** design coverage only; live acceptance is **not proven** without a real `FOOTBALL_DATA_API_TOKEN` and owner-reviewed terms evidence.  
**Default production decision:** `not_run_missing_credential`, `automation_enabled = FALSE`.

## Capability Decisions

| Capability | Decision | Phase 18 contract | Reason |
|---|---|---|---|
| Competition metadata | INTEGRATE | Fetch `GET /competitions/CL`; retain competition/season IDs, start/end dates, current matchday, plan/area, `lastUpdated`, raw hash, schema fingerprint, and typed lifecycle projection. Exactly one competition object is required. | Edition and lifecycle identity are required before any other resource can be accepted. |
| Teams | INTEGRATE | Fetch `GET /competitions/CL/teams?season=2026`; require unique provider team IDs, exactly the reviewed lifecycle-specific club count (36 for the league phase), explicit owner-reviewed club-identity resolution, and complete match-team foreign-key coverage. One fewer or one extra blocks. | UCLSRC-02 and CLUBID-01 require a complete stable club set for the edition. |
| Matches | INTEGRATE | Fetch `GET /competitions/CL/matches?season=2026`; retain fixtures/results/lifecycle fields, observed stages/statuses, score semantics, kickoff and `lastUpdated`; reject duplicate match IDs, unknown required enums, stages outside the reviewed allowlist, and league-phase schedule cardinality other than exactly 144 fixtures. Later knockout expectations are separate reviewed lifecycle rows. | Fixtures, results, lifecycle evidence, and independently measurable completeness are required current state. |
| Standings | INTEGRATE | Fetch `GET /competitions/CL/standings?season=2026`; retain the provider table as source evidence only, with reviewed lifecycle-specific required/optional state and exact row/cardinality checks. | The source table supports completeness checks, but Phase 20—not the provider—owns UCL ranking rules. |
| Scorers | OPT-OUT | No `/competitions/CL/scorers` request or artifact in Phase 18. | Player/scorer features are outside Phase 18 and CLUBMOD-05 keeps player evidence unavailable without a separate accepted contract. |
| Head-to-head | OPT-OUT | No `/matches/{id}/head2head` calls. | It would introduce a per-match crawl and is unnecessary for the current-state source contract; historical evidence is handled by the pinned club corpus. |
| Match detail | OPT-OUT | No `/matches/{id}` calls; all accepted match fields must come from the competition-scoped match response. | The bounded four-resource retrieval window must stay below quota and avoid per-ID amplification. |
| Team detail | OPT-OUT | No `/teams/{id}` calls; accepted club metadata is limited to the competition team response. | Competition-scoped team data is sufficient for source IDs and display metadata; broader club enrichment is not required. |
| Person detail | OPT-OUT | No `/persons/{id}` calls. | Person/player data is outside the milestone’s accepted evidence scope. |
| Filters | INTEGRATE | Fix `season=2026` for teams, matches, and standings. Permit only enumerated local test filters; callers cannot supply host, path, arbitrary query keys, team IDs, person IDs, or match IDs. Record the exact effective query in non-secret evidence. | A fixed edition query prevents scope drift and arbitrary-host/path abuse. |
| Pagination | INTEGRATE defensively | Parse and record any documented/observed pagination or result-count metadata; require the complete competition-scoped resource. If a response indicates more pages than retrieved, block with `blocked_incomplete_pagination`. Do not invent page traversal when the endpoint supplies no pagination contract. | Partial lists must never pass as complete state, while undocumented query behavior must not be guessed. |
| Authenticated headers | INTEGRATE | Read `FOOTBALL_DATA_API_TOKEN` only inside the live request function; attach `X-Auth-Token` with `httr2::req_headers_redacted()`; never return, hash, serialize, log, or persist the request/token. Scan candidate output, logs, targets metadata delta, and Git diff for the exact token. | The credential is a primary trust boundary and must remain process-local. |
| Rate limits | INTEGRATE | Use one competition-scoped call per integrated resource, `req_throttle(capacity = 9, fill_time_s = 60)`, at most three bounded retry attempts, `Retry-After` support, and no per-ID crawl. Record call counts and observed limit headers when present. | This leaves safety margin below the documented free-tier limit and avoids retry amplification. |
| Null/empty semantics | INTEGRATE | Distinguish missing JSON, JSON `null`, schema-complete zero-row tables, and non-empty tables. Competition must be one object; required resource emptiness blocks according to edition lifecycle. Optional nullable fields remain typed missing and never become zero or inferred values. | The provider documents nulls and empty arrays as valid transport responses; semantic acceptance therefore requires explicit lifecycle rules. |
| Attribution | INTEGRATE | `provider_terms_review.csv` records exact required text, placement, terms URL/hash, reviewer and time. Automation can be enabled only when attribution is owner-approved; the accepted manifest carries the review ID/hash. | Public terms require visible attribution, and code cannot decide placement adequacy. |
| Provider exit | INTEGRATE | The owner review records retention/termination permission and exactly one exit_disposition. retain disables automation and preserves incumbent provider bytes only when continued retention/display is explicitly permitted. withdraw atomically removes provider-derived accepted/public files, preserves independently lawful reviewed manual/open files, and installs a hash-bound unavailable tombstone. | Technical last-known-good behavior cannot override provider termination or retention terms. |

## Integrated Resource Window

The live acceptance command performs one coherent bounded retrieval window:

1. `GET /competitions/CL`
2. `GET /competitions/CL/teams?season=2026`
3. `GET /competitions/CL/matches?season=2026`
4. `GET /competitions/CL/standings?season=2026`

No individual match, team, person, scorer, or head-to-head requests are part of Phase 18. All four responses must agree on competition/season identity, and no passing response can compensate for a failed, null, stale, incomplete, or identity-invalid sibling response.

## Reviewed Edition and Lifecycle Expectations

`data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/edition_expectations.csv` is a separately reviewed, hash-bound acceptance input. It records:

- `edition_id`, lifecycle state, reviewer, and reviewed-at UTC;
- `expected_club_count = 36` for the league phase;
- `expected_league_phase_match_count = 144`, derived from 36 clubs × 8 fixtures ÷ 2, plus separate reviewed lifecycle rows for later knockout stages;
- the closed set of allowed provider stage values;
- whether standings are required for that lifecycle and the exact expected table/row/club coverage;
- row hashes and one aggregate `expectation_sha256`.

The live matrix records observed values and the expectation hash. Any club, schedule, or standings shortfall or excess, any stage outside the allowlist, or any expectation-hash mismatch blocks with a typed completeness reason even when foreign keys, pagination metadata, and the returned subset are internally consistent. A changed expectation requires a new owner review and invalidates the prior provider manifest.

## Identity Coverage

All current club IDs/names and historical inventory club tokens pass through `scripts/bootstrap_club_identity.R`. Extraction produces evidence rows only; it never proposes or creates a canonical club. An owner-authored mapping must name the exact `club_id`, source scope, half-open validity interval, reviewer, time, and approved state before the three registries can be updated atomically. Pending, ambiguous, conflicting, rejected, or missing mappings remain in `data/club/identity_reviews/unresolved_club_tokens.csv` and block their respective current or historical completeness gate. Both gates are rerun after every approved registry update.

## Source-Mode Authority Contract

Every candidate bundle carries exactly one discriminated authority variant:

| source_mode | authority_type | Required ID/hash | Forbidden fields | Promotion eligibility |
|---|---|---|---|---|
| `provider_live` | `provider_acceptance` | `provider_decision_id`, `provider_decision_sha256` for a recomputed accepted manifest | manual-review and fixture ID/hash fields | eligible only after all bundle gates pass |
| `manual_reviewed` | `manual_source_review` | `manual_source_review_id`, `manual_source_review_sha256` for an accepted source/license review | provider-decision and fixture ID/hash fields | eligible only after all bundle gates pass; never enables automation |
| `fixture_contract` | `fixture_contract` | `fixture_contract_id`, `fixture_contract_sha256` | provider-decision and manual-review ID/hash fields | never eligible for promotion |

Mixed, missing, surplus, stale, or hash-mismatched authority fields invalidate the bundle. Plan 18-06 defines and tests this union; Plan 18-04 recomputes it rather than trusting a stored eligibility boolean.

## Acceptance Boundary

- Synthetic fixtures prove parsing, canonicalization, failure classification, and secret hygiene only.
- A missing key produces `decision = not_run`, `reason_code = missing_credential`, and `automation_enabled = FALSE` without a network call or accepted-state mutation.
- A reviewed manual snapshot may produce `decision = manual_only`, but cannot enable provider automation.
- The first `decision = accepted` and `automation_enabled = TRUE` can be created only by `live_acceptance_probe`: owner review is already complete, automation is still false, the run has no cache, and exactly the four fixed endpoints produce a complete expectation-bound machine matrix plus a clean exact-token scan. The manifest and evidence are installed atomically.
- Ordinary `provider_live` is prohibited until that accepted manifest independently validates. It cannot bootstrap its own authority.
- Phase completion must not be described as live-provider acceptance unless those artifacts exist and the owner has reviewed them.
