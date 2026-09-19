# Phase 18: Club and UCL Source Contracts - Research

**Researched:** 2026-09-19
**Domain:** Lawful keyed API acceptance, immutable current-state bundles, club identity, and pinned club-match history in R
**Confidence:** MEDIUM — repository patterns and public documentation are strong; production acceptance remains unproven until an owner-reviewed live-key spike runs.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UCLSRC-01 | The operator can run a live-key acceptance check covering API rights, attribution, retention, quota, schema, completeness, and freshness before automated UCL acquisition is enabled. `[VERIFIED: REQUIREMENTS.md]` | Implement a two-part gate: machine checks for endpoint/schema/cardinality/freshness/quota plus an owner-reviewed terms matrix for rights, retention, attribution, and provider exit. Missing credentials must yield `not_run` with `automation_enabled = FALSE`, never a synthetic pass. `[VERIFIED: codebase][CITED: https://www.football-data.org/about][CITED: https://www.football-data.org/pricing]` |
| UCLSRC-02 | The operator can ingest current UCL fixtures, results, standings, clubs, and lifecycle metadata without storing provider credentials in generated artifacts or Git. `[VERIFIED: REQUIREMENTS.md]` | Use competition-scoped `CL` endpoints through `httr2`, read the token inside the acquisition process, mark `X-Auth-Token` redacted, and project the response through an accepted-bundle adapter. Do not serialize a request object or raw secret into `targets`. `[CITED: https://docs.football-data.org/general/v4/coding_client.html][CITED: https://httr2.r-lib.org/reference/req_headers.html]` |
| UCLSRC-03 | Every accepted current-state artifact records provider, retrieval time, source-as-of time, edition, schema version, and content hashes. `[VERIFIED: REQUIREMENTS.md]` | Extend the proven Phase 13 source bundle/artifact pattern with `provider_id`, `source_as_of_utc`, provider schema fingerprint, canonical content hash, and accepted edition linkage. `[VERIFIED: R/competition/source_contracts.R][VERIFIED: data/competition/registries/source_artifacts.csv]` |
| UCLSRC-04 | A failed, empty, stale, or incomplete retrieval retains the last known good accepted bundle and records a blocked refresh with a machine-readable reason. `[VERIFIED: REQUIREMENTS.md]` | Reuse the Phase 13 candidate/staging/blocked-refresh transaction and its byte-snapshot tests; add typed failure reasons for credential, HTTP, null, empty, stale, schema, coverage, identity, and terms-gate failures. `[VERIFIED: scripts/acquire_uefa_snapshot.R][VERIFIED: tests/testthat/test_phase13_refresh_failure.R]` |
| CLUBID-01 | Every club resolves to one stable internal identity through source IDs, validity-aware aliases, and explicit rejection of ambiguous or cross-domain matches. `[VERIFIED: REQUIREMENTS.md]` | Create a club-only identity namespace with source-ID-first resolution, non-overlapping validity intervals, reviewed aliases, an `entity_kind = club` discriminator, and hard rejection of national `team_id`/FIFA-code assumptions. `[VERIFIED: R/competition/team_identity.R][VERIFIED: .planning/research/ARCHITECTURE.md]` |
| CLUBHIST-01 | Historical domestic and European club results are pinned, licensed, audited for coverage, duplication, and score semantics, and normalized with point-in-time availability for model training. `[VERIFIED: REQUIREMENTS.md]` | Pin every OpenFootball input by repository commit and path, retain license/provenance/hashes, normalize into a club-match schema, and emit coverage, duplicate, identity, score-semantics, and temporal-availability audit tables before setting `accepted_for_training = TRUE`. `[CITED: https://github.com/openfootball/champions-league][CITED: https://github.com/openfootball/football.json]` |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Implement the phase in R and the existing file-based `targets` architecture; do not introduce a database, application server, or second runtime. `[VERIFIED: AGENTS.md]`
- Preserve the project’s open-data-first core value and do not make a paid feed a hidden production prerequisite. `[VERIFIED: AGENTS.md][VERIFIED: PROJECT.md]`
- Do not automate sources whose terms do not permit the intended acquisition. Existing project policy already requires manual handling for restricted sources, and the v4.0 scope explicitly excludes automated UEFA page scraping. `[VERIFIED: AGENTS.md][VERIFIED: REQUIREMENTS.md]`
- Keep club identity and evidence separate from the national-team domain; the national `team_identity.csv` requires FIFA-oriented fields and is not a club registry. `[VERIFIED: AGENTS.md][VERIFIED: R/competition/team_identity.R]`
- Keep data-layer work separate from model, rules, simulation, and dashboard authority. Phase 18 may establish accepted inputs, but it must not authorize club forecasts or implement UCL standings logic. `[VERIFIED: AGENTS.md][VERIFIED: ROADMAP.md]`
- Validate with `testthat`, add phase-specific contract tests to `tests/testthat/`, run tests frequently, and verify before committing. `[VERIFIED: AGENTS.md]`
- Preserve unrelated working-tree changes and do not remove or rewrite files outside the requested Phase 18 research and later implementation scope. `[VERIFIED: AGENTS.md]`

## Summary

Phase 18 should be planned as four contract slices: provider acceptance, accepted current-state bundles, club identity, and historical corpus acceptance. The repository already has mature analogs for candidate bundles, ignored raw storage, canonical SHA-256 lineage, stable source-ID mapping, blocked refresh records, last-known-good preservation, and atomic promotion. The plan should extend those patterns under new Phase 18 names rather than retrofit club semantics into the national-team schemas. `[VERIFIED: R/competition/source_contracts.R][VERIFIED: R/competition/team_identity.R][VERIFIED: scripts/acquire_uefa_snapshot.R]`

football-data.org publicly documents Champions League free-tier coverage, `CL` competition match calls, competition-scoped team and standings resources, delayed scores/schedules, and a 10-calls-per-minute free limit. Its match representation includes IDs, `utcDate`, status, matchday, stage, `lastUpdated`, teams, and score objects; its policies explicitly allow null values and empty lists. Therefore an HTTP 200 or syntactically valid JSON response is not acceptance evidence by itself. `[CITED: https://www.football-data.org/coverage][CITED: https://www.football-data.org/pricing][CITED: https://docs.football-data.org/general/v4/match.html][CITED: https://docs.football-data.org/general/v4/policies.html]`

The source cannot be accepted from public documentation alone. Its terms bind one API key to one application, prohibit storing credentials in open-source repositories, require visible attribution, disclaim availability/accuracy guarantees, and state that after subscription cancellation the customer may not reference API-obtained football data on its site or service. Rights, normalized-field display, raw-byte retention, last-known-good retention, and provider-exit behavior therefore need an owner review and, where unclear, provider clarification; this research is not legal advice. `[CITED: https://www.football-data.org/about]`

The environment currently has no `FOOTBALL_DATA_API_TOKEN`. Phase 18 must not fabricate live evidence: offline synthetic tests can prove parsing and failure behavior, while the committed provider decision remains `not_run_missing_credential` or `manual_only` with automation disabled until a real key and owner review produce a pass. `[VERIFIED: local runtime probe][VERIFIED: STATE.md]`

**Primary recommendation:** Build the provider and club-data contracts completely offline first, then make one explicit live-key/owner-review checkpoint the only operation allowed to set `automation_enabled = TRUE`; all other outcomes preserve a reviewed manual-snapshot or explicit unavailable mode. `[VERIFIED: REQUIREMENTS.md][VERIFIED: ROADMAP.md]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Provider terms and live-key acceptance | API / Backend | Database / Storage | The R acquisition command performs machine checks; durable decision artifacts record owner review and block automation by default. `[VERIFIED: ROADMAP.md]` |
| Current UCL acquisition | API / Backend | Database / Storage | Authentication, bounded HTTP behavior, parsing, and candidate validation belong in the acquisition boundary; only accepted normalized tables cross into storage. `[VERIFIED: R/competition/source_contracts.R]` |
| Credential handling | API / Backend | — | The token is runtime-only and must not enter manifests, logs, fixtures, `targets` metadata, or Git. `[CITED: https://www.football-data.org/about][CITED: https://httr2.r-lib.org/reference/req_headers.html]` |
| Last-known-good state | Database / Storage | API / Backend | Accepted bundles and blocked-refresh records are durable state; orchestration determines whether a candidate may replace the incumbent. `[VERIFIED: R/competition/edition_registry.R][VERIFIED: scripts/acquire_uefa_snapshot.R]` |
| Club identity | API / Backend | Database / Storage | Resolution and ambiguity rules are deterministic business logic backed by revisioned identity/source-ID/alias tables. `[VERIFIED: R/competition/team_identity.R]` |
| Historical corpus pinning and audits | Database / Storage | API / Backend | Source commits, licenses, normalized matches, and audit tables are durable; R validators decide whether the corpus is training-eligible. `[VERIFIED: .planning/research/ARCHITECTURE.md]` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R | 4.6.1, released 2026-06-24 | Contract code, adapters, audit tables, and CLI entrypoints | It is the existing project runtime and is installed locally. `[VERIFIED: local runtime probe][VERIFIED: AGENTS.md]` |
| `httr2` | 1.2.2, published 2025-12-08 | Keyed requests, redacted headers, bounded retries, throttling, and optional HTTP cache validation | The installed version exposes `req_headers_redacted()`, `req_retry()`, `req_throttle()`, and `req_cache()`; no upgrade is required in this phase. `[VERIFIED: local package metadata][CITED: https://httr2.r-lib.org/reference/req_headers.html][CITED: https://httr2.r-lib.org/reference/req_retry.html][CITED: https://httr2.r-lib.org/reference/req_throttle.html]` |
| `jsonlite` | 2.0.0, published 2025-03-27 | Strict JSON validation/parsing and machine-readable decision/blocked records | It is already used by the Phase 13 acquisition and refresh contracts. `[VERIFIED: local package metadata][VERIFIED: scripts/acquire_uefa_snapshot.R]` |
| `digest` | 0.6.39, published 2025-11-19 | SHA-256 for raw bytes, canonical tables, rows, manifests, and schema fingerprints | It is the existing project integrity primitive and is already wired into the source contracts. `[VERIFIED: local package metadata][VERIFIED: R/competition/source_contracts.R]` |
| Git CLI | 2.55.0 | Pin OpenFootball repository commits and record parser identity | Commit SHAs provide immutable source references and the current source bundle uses the parser Git SHA. `[VERIFIED: local runtime probe][VERIFIED: R/competition/source_contracts.R]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `testthat` | 3.3.2, published 2026-01-11 | Provider-shape, identity, history, secret, and failure-path contracts | Use synthetic provider-shaped fixtures and temporary publication sandboxes; live-key tests remain opt-in and cannot be the default suite. `[VERIFIED: local package metadata][VERIFIED: tests/testthat/test_phase13_source_contracts.R]` |
| `targets` | 1.12.0, published 2026-02-09 | Later orchestration integration | Phase 18 may expose file-producing functions, but the secret-bearing live request should execute inside a process-local function and never serialize the token/request object as a target value. `[VERIFIED: local package metadata][VERIFIED: _targets.R]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct narrow `httr2` adapter | A sports-data SDK | No official R SDK is needed; a wrapper would obscure endpoint, secret, quota, null, and schema behavior that the acceptance gate must inspect directly. `[CITED: https://docs.football-data.org/general/v4/index.html][VERIFIED: .planning/research/STACK.md]` |
| Project-owned club IDs | Provider IDs as canonical IDs | Provider IDs are valuable source keys but do not provide cross-provider identity or provider-exit continuity. `[VERIFIED: .planning/research/ARCHITECTURE.md]` |
| Pinned OpenFootball commits | Pulling mutable `master` files on each build | Mutable branch content cannot reproduce a historical training corpus; commit-addressed URLs and raw hashes can. `[CITED: https://github.com/openfootball/football.json]` |
| Reviewed manual snapshot / unavailable mode | Automated UEFA scraping | UEFA’s platform terms prohibit systematic collection and automated tools for scraping/collection, so scraping is outside the accepted source boundary. This is an owner-review constraint, not legal advice. `[CITED: https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/]` |

**Installation:**

```bash
# No new package installation is required for Phase 18.
```

**Version verification:** The required R runtime and packages are already available locally at the versions listed above. `[VERIFIED: local runtime probe]`

## Package Legitimacy Audit

No external package installation is planned. The phase reuses locally installed packages already present in the project, so the package-legitimacy gate is not applicable. `[VERIFIED: local runtime probe]`

## Provider Acceptance Contract

### Required coverage matrix

The live spike should generate `coverage_matrix.csv`; the table below defines its rows, not their verdicts. Public docs establish endpoint existence and general fields, while only a key-backed call can establish 2026/27 completeness and new-format stage behavior. `[CITED: https://docs.football-data.org/general/v4/coding_client.html][CITED: https://docs.football-data.org/general/v4/competition.html]`

| Dimension | Probe / Evidence | Pass condition | Failure behavior |
|-----------|------------------|----------------|------------------|
| Credential/application scope | `FOOTBALL_DATA_API_TOKEN` present; owner records the registered application/domain | Token present only at runtime and owner confirms this dashboard is the registered application | `not_run_missing_credential` or `rejected_application_scope`; automation stays disabled. `[CITED: https://www.football-data.org/about]` |
| Competition lifecycle | `GET /v4/competitions/CL` | Competition/season IDs, start/end dates, current matchday, stages, and `lastUpdated` are present and map without inference | `blocked_lifecycle_schema`. `[CITED: https://docs.football-data.org/general/v4/competition.html]` |
| Clubs | `GET /v4/competitions/CL/teams?season=2026` | Exactly one provider ID per accepted league-phase club; no duplicate IDs; every match team ID is in the team set | `blocked_team_coverage`. The documented team subresource accepts a season filter. `[CITED: https://docs.football-data.org/general/v4/competition.html]` |
| Fixtures/results | `GET /v4/competitions/CL/matches?season=2026` | The league-phase projection has the edition-declared expected schedule, unique match IDs, two distinct known clubs, kickoff/status/stage fields, and valid score semantics for completed matches | `blocked_match_coverage` or `blocked_score_semantics`. The endpoint and fields are documented, but 2026/27 cardinality and stage labels require the live check. `[CITED: https://docs.football-data.org/general/v4/coding_client.html][CITED: https://docs.football-data.org/general/v4/match.html]` |
| Standings | `GET /v4/competitions/CL/standings?season=2026` | One unambiguous total-table row per accepted club at lifecycle states where standings are expected; source rank/statistics are retained as audit evidence, not UCL rules authority | `blocked_standings_coverage`. Filtered historical standings may be reconstructed from matches and can omit deductions, so exact behavior must be recorded. `[CITED: https://docs.football-data.org/general/v4/competition.html]` |
| Status vocabulary | Observed match `status` and `stage` values | Every value is explicitly mapped; unknown values block acceptance | `blocked_unknown_enum`. The documented status enum includes scheduled, timed, live phases, finished, suspended, postponed, cancelled, and awarded; the public stage enum does not prove the current UCL league-stage label. `[CITED: https://docs.football-data.org/general/v4/match.html]` |
| Null/empty behavior | Response bodies and required nested fields | Required resources are non-null/non-empty for the edition lifecycle; optional nulls remain typed missing | `blocked_null` or `blocked_empty`. Provider policy says nulls and empty lists are valid, so they require semantic validation. `[CITED: https://docs.football-data.org/general/v4/policies.html]` |
| Freshness | `retrieved_at_utc`, endpoint/row `lastUpdated`, latest completed match time | Observed delay is computed and compared with an owner-approved lifecycle threshold; no undocumented SLA is invented | `blocked_stale`. The free plan explicitly says scores and schedules are delayed. `[CITED: https://www.football-data.org/pricing]` |
| Quota | Request count plus response limit headers if present | Fixed endpoint plan fits beneath 10 calls/minute with safety margin; no per-match crawl | `rejected_quota`. `[CITED: https://docs.football-data.org/general/v4/policies.html]` |
| Attribution | Owner review of exact required text and placement | Required visible attribution is approved and recorded | `rejected_attribution`. `[CITED: https://www.football-data.org/about]` |
| Rights/retention/exit | Owner review, current terms URL/hash, provider clarification if needed | Intended normalization, display, private raw cache, last-known-good retention, and termination behavior are explicitly accepted | `rejected_terms` or `manual_only`. Public terms require credential secrecy and attribution and restrict referencing API data after cancellation. `[CITED: https://www.football-data.org/about]` |
| Secret hygiene | Scan candidate files, logs, test fixtures, and Git diff for the exact token and header | Zero matches; committed evidence contains only `credential_status`, never the credential or reversible derivative | `blocked_secret_exposure`. `[CITED: https://www.football-data.org/about][CITED: https://httr2.r-lib.org/reference/req_headers.html]` |

### Acceptance spike procedure

1. Build and test the adapter entirely with hand-authored provider-shaped fixtures and an injected `perform_request` function. Fixture success proves parser behavior only. `[VERIFIED: tests/testthat/test_phase13_source_contracts.R]`
2. Run a preflight that checks credential presence without printing it. If absent, write a decision artifact with `decision = not_run`, `reason_code = missing_credential`, and `automation_enabled = FALSE`; do not invoke the network and do not alter accepted state. `[VERIFIED: local runtime probe][VERIFIED: REQUIREMENTS.md]`
3. Require a reviewed `provider_terms_review.csv` before live execution. It records reviewer, review time, terms URL/hash, application scope, attribution text, normalized-display verdict, raw-cache verdict, retention/termination verdict, provider-exit action, and notes. Code must not auto-approve these legal/business judgments. `[CITED: https://www.football-data.org/about]`
4. Execute only the four competition-scoped calls in the matrix, with an optional competition metadata call if it is not already one of them. Use a safety limit of nine requests/minute, bounded retries, and a fixed base host; do not loop over team or match IDs. `[CITED: https://docs.football-data.org/general/v4/policies.html][CITED: https://httr2.r-lib.org/reference/req_throttle.html][CITED: https://httr2.r-lib.org/reference/req_retry.html]`
5. Keep exact live response bytes only in an ignored local candidate root. Commit normalized projections, counts, enum inventories, schema fingerprints, hashes, and the final decision, subject to the owner’s retention verdict. `[VERIFIED: .gitignore][VERIFIED: R/competition/source_contracts.R]`
6. Validate endpoints as one coherent retrieval window: edition/season identity, lifecycle, clubs, matches, standings, source IDs, cardinalities, schema, content hashes, source-as-of times, and freshness. A pass on one endpoint cannot backfill a failure on another. `[VERIFIED: REQUIREMENTS.md]`
7. Run an exact-token and suspicious-header scan over the candidate artifacts, console log, `_targets` metadata delta, and Git diff. Delete/revoke and block if any credential is found. `[CITED: https://www.football-data.org/about]`
8. Set `decision = accepted` and `automation_enabled = TRUE` only when every machine row passes and every owner-review row is approved. Any other result is `rejected`, `not_run`, or `manual_only`, with automation disabled and no accepted-bundle replacement. `[VERIFIED: REQUIREMENTS.md][VERIFIED: STATE.md]`

### Go/no-go artifacts

```text
data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/
├── provider_terms_review.csv       # owner-reviewed rights/retention/attribution/application scope
├── coverage_matrix.csv             # one row per endpoint/dimension with observed counts and verdicts
├── schema_fingerprint.csv          # endpoint, JSON path, observed type/cardinality, fingerprint hash
├── acceptance_manifest.csv         # decision, reason, automation_enabled, reviewer, evidence hashes
└── ACCEPTANCE.md                    # human-readable summary; explicitly not legal advice
```

The committed artifacts contain no raw live body and no key. The accepted current-state bundle is a separate output created only after `acceptance_manifest.csv` says `accepted` and `automation_enabled = TRUE`. `[VERIFIED: REQUIREMENTS.md][VERIFIED: .gitignore]`

## Architecture Patterns

### System Architecture Diagram

```text
Owner terms review -----------+
                              |
Runtime key -> bounded CL API calls -> ignored raw candidate bytes
                              |                  |
                              +-------> coverage/schema/freshness matrix
                                                 |
                                      +----------+-----------+
                                      |                      |
                                 any gate fails          all gates pass
                                      |                      |
                         blocked refresh record      normalized candidate
                         incumbent unchanged                |
                                      |            club identity resolution
                                      |                      |
                                      +-----------> accepted UCL bundle

Pinned OpenFootball repos @ commit SHA -> ignored raw history -> club identity
                                                        |
                                     score/duplicate/coverage/time audits
                                                        |
                                            accepted historical corpus
```

### Recommended Project Structure

```text
R/
├── club/
│   ├── identity.R                    # club registry, source IDs, aliases, validity checks
│   └── history_contract.R            # pinned-source and normalized history validators
└── competition/
    ├── football_data_org_adapter.R   # fixed-host request builder and raw -> canonical projection
    └── ucl_source_acceptance.R       # matrix, decision, accepted-bundle gate

scripts/
├── accept_ucl_provider.R             # opt-in live key spike; safe no-key outcome
└── build_club_history_corpus.R       # pinned source inventory -> audited accepted corpus

data/
├── club/
│   ├── registries/{clubs,club_source_ids,club_aliases}.csv
│   ├── history_sources.csv
│   ├── local_raw/                    # ignored
│   └── accepted/<corpus_id>/         # normalized matches + audits + manifest
└── competition/
    ├── provider_acceptance/football_data_org_v4/ucl_2026_27/
    └── accepted/uefa_champions_league_2026_27/

tests/
├── fixtures/phase18/                 # synthetic provider/OpenFootball-shaped examples only
└── testthat/test_phase18_*.R
```

### Exact existing analogs

| Phase 18 responsibility | Reuse pattern from | Required adaptation |
|-------------------------|--------------------|---------------------|
| Raw/artifact/bundle hashing | `R/competition/source_contracts.R` | Add provider, source-as-of, schema fingerprint, and accepted-provider-decision foreign key. Keep canonical ordering and self-hashes. `[VERIFIED: codebase]` |
| Candidate acquisition CLI | `scripts/acquire_uefa_snapshot.R` | Reuse argument parsing, candidate-before-publish, ignored raw store, staging, and failure handling; replace arbitrary URLs/UEFA-specific parsing with one fixed football-data.org adapter. `[VERIFIED: codebase]` |
| Blocked refresh and LKG | `R/competition/edition_registry.R`, `tests/testthat/test_phase13_refresh_failure.R` | Add Phase 18 reason-code enum and prove accepted/source artifacts stay byte-identical on credential, HTTP, null, empty, stale, schema, completeness, and identity failures. `[VERIFIED: codebase]` |
| Source-ID-first resolution | `R/competition/team_identity.R::phase13_resolve_team_identity()` | Fork the algorithm, not the schema: clubs must not require FIFA codes or national-team IDs and must add validity intervals/source system. `[VERIFIED: codebase]` |
| Historical identity coverage | Phase 13 martj42 functions in `R/competition/team_identity.R` | Reuse source-input hash, identity-map version, exact coverage, stable match ID, and future-row/score-change resistance patterns for club sources. `[VERIFIED: codebase]` |
| Accepted snapshot loader | accepted-tree validation in `R/competition/edition_registry.R` | Add `clubs.csv` and UCL lifecycle fields; preserve trusted-root, no-symlink, manifest, and raw-provenance checks. `[VERIFIED: codebase]` |
| Secret-safe local bytes | `.gitignore` entry for `data/competition/local_raw/` | Add `data/club/local_raw/` and any provider HTTP cache directory; do not ignore acceptance decisions or normalized accepted tables. `[VERIFIED: .gitignore]` |

### Pattern 1: Decision Artifact Controls Acquisition

**What:** Treat source acceptance as data. The adapter may exist and pass offline tests while production automation remains disabled. `[VERIFIED: REQUIREMENTS.md]`

**When to use:** Every provider, API version, application/domain change, material terms change, or edition requiring new coverage. `[CITED: https://www.football-data.org/about]`

**Example:**

```r
# Source pattern: REQUIREMENTS.md plus Phase 13 fail-closed registries.
accepted <- identical(decision$decision, "accepted") &&
  isTRUE(decision$automation_enabled) &&
  all(machine_checks$verdict == "pass") &&
  all(owner_review$verdict == "approved")

if (!accepted) {
  stop("UCL automated acquisition is disabled by the provider acceptance gate", call. = FALSE)
}
```

### Pattern 2: Secret-Bearing Request Is Process-Local

**What:** Read the environment token inside the request builder, add it as a redacted header, and return only response bytes plus non-secret metadata. `[CITED: https://httr2.r-lib.org/reference/req_headers.html]`

**When to use:** The opt-in live acceptance spike and later accepted refresh implementation. `[VERIFIED: ROADMAP.md]`

**Example:**

```r
# Source: official httr2 request/header/retry/throttle documentation.
token <- Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = "")
if (!nzchar(token)) stop("missing_credential", call. = FALSE)

req <- httr2::request(
  "https://api.football-data.org/v4/competitions/CL/matches"
) |>
  httr2::req_url_query(season = 2026) |>
  httr2::req_headers_redacted(`X-Auth-Token` = token) |>
  httr2::req_throttle(capacity = 9, fill_time_s = 60) |>
  httr2::req_retry(max_tries = 3, max_seconds = 45, retry_on_failure = TRUE)
```

`req_cache(use_on_error = FALSE)` may be used for normal refreshes when the server supplies standard cache headers, but the live acceptance spike should use an isolated empty cache or no cache so a previous response cannot stand in for current coverage. `[CITED: https://httr2.r-lib.org/reference/req_cache.html]`

### Pattern 3: Separate Club Identity Tables

Use three normalized registries rather than pipe-delimited aliases in one row. This makes validity overlap, alias ambiguity, and source-ID uniqueness testable. `[VERIFIED: R/competition/team_identity.R][ASSUMED]`

```text
clubs.csv:
schema_version,club_id,entity_kind,canonical_name,association_code,
valid_from,valid_to,club_status,row_sha256

club_source_ids.csv:
schema_version,club_id,source_system,source_club_id,valid_from,valid_to,
review_state,source_bundle_id,row_sha256

club_aliases.csv:
schema_version,club_id,source_system,alias,normalized_alias,valid_from,valid_to,
review_state,reviewed_by,reviewed_at_utc,row_sha256
```

Resolution order is: exact `(source_system, source_club_id)` valid at event time; then one reviewed validity-compatible alias; otherwise stop. Overlapping source-ID assignments, multiple alias matches, pending review, `entity_kind != club`, a `team_` national ID, or FIFA-code-only matching must fail closed. `[VERIFIED: REQUIREMENTS.md][VERIFIED: .planning/research/ARCHITECTURE.md]`

### Pattern 4: Pinned Historical Corpus With Evidence Time

Each source row records repository URL, full commit SHA, committed time, relative path, license URL/identifier, retrieval time, byte count, and raw SHA-256. Normalized matches carry event time and `evidence_available_at_utc` separately from source retrieval time. `[CITED: https://github.com/openfootball/champions-league][VERIFIED: REQUIREMENTS.md]`

When the source provides only a match date, use an explicit conservative policy such as next-day UTC for `evidence_available_at_utc`; never invent a kickoff time. The exact policy is a planner-visible decision because OpenFootball’s public JSON example shows dates without kickoff timestamps. `[CITED: https://github.com/openfootball/football.json][ASSUMED]`

Recommended normalized match fields:

```text
club_match_id,competition_id,season_id,stage,event_date,kickoff_utc,
kickoff_precision,evidence_available_at_utc,home_club_id,away_club_id,
venue_type,status,regulation_home_goals,regulation_away_goals,
extra_time_home_goals,extra_time_away_goals,final_home_goals,final_away_goals,
shootout_home_goals,shootout_away_goals,winner_club_id,completion_method,
counts_for_model,exclusion_reason,source_id,source_row_key,row_sha256
```

Unknown full-time/extra-time/shootout meaning is not a null-filling problem. Mark the row `counts_for_model = FALSE`, record `unresolved_score_semantics`, and include it in the audit until reviewed. `[VERIFIED: REQUIREMENTS.md]`

### Fixture strategy

- Commit hand-authored synthetic JSON with fictional club IDs/names but exact provider field shapes and enums needed by the adapter. Label every fixture `synthetic_contract_fixture`; it must not be presented as live coverage evidence. `[VERIFIED: tests/fixtures/phase13][VERIFIED: REQUIREMENTS.md]`
- Include scheduled, timed, finished, postponed, suspended, cancelled, and awarded examples; null score fields; empty endpoint payload; unknown status/stage; duplicate match/team IDs; missing nested team; stale `lastUpdated`; and mismatched season/competition. `[CITED: https://docs.football-data.org/general/v4/match.html]`
- Commit tiny hand-authored OpenFootball-shaped samples covering domestic regulation result, European two-leg labels, extra-time notation, shootout notation, date-only evidence, renamed club, ambiguous alias, exact duplicate, and cross-source duplicate. `[CITED: https://github.com/openfootball/champions-league][CITED: https://github.com/openfootball/football.json]`
- Never commit the live token, request headers, full raw live responses, or provider data merely relabeled as a fixture. Store any permitted live raw bytes only under ignored local roots; commit hashes, counts, schema inventories, and decision evidence. `[CITED: https://www.football-data.org/about][VERIFIED: .gitignore]`

### Anti-Patterns to Avoid

- **Turning on automation because offline fixtures pass:** parser correctness does not establish production rights, live schema, completeness, or freshness. `[VERIFIED: REQUIREMENTS.md]`
- **Treating HTTP 200 as a valid snapshot:** the provider explicitly allows null values and empty lists. `[CITED: https://docs.football-data.org/general/v4/policies.html]`
- **Using `req_cache(use_on_error = TRUE)` at acceptance:** it can convert a failed refresh into an apparently successful stale response. `[CITED: https://httr2.r-lib.org/reference/req_cache.html]`
- **Committing a serialized request or verbose log:** a request object may contain the credential even if print output redacts it. Return only response bytes and non-secret metadata. `[CITED: https://httr2.r-lib.org/reference/req_headers.html]`
- **Accepting the provider’s standings as rules authority:** filtered historical standings can be reconstructed and omit deductions; Phase 20 must recompute UCL rules. `[CITED: https://docs.football-data.org/general/v4/competition.html][VERIFIED: ROADMAP.md]`
- **Extending national `team_identity.csv` with clubs:** it requires national-team concepts including FIFA codes and creates cross-domain join risk. `[VERIFIED: R/competition/team_identity.R]`
- **Name-only club joins:** club names, punctuation, sponsors, and renames are not stable keys; ambiguous aliases must block. `[VERIFIED: REQUIREMENTS.md]`
- **Pulling OpenFootball `master` during training:** the resulting corpus is mutable and unreproducible. Pin complete commit SHAs and paths. `[CITED: https://github.com/openfootball/football.json]`
- **Mixing generated JSON and its upstream Football.TXT as separate evidence:** the JSON is generated from the text source, so ingesting both can duplicate the same matches. `[CITED: https://github.com/openfootball/football.json]`
- **Copying the existing UEFA hidden-service acquisition for UCL:** the v4.0 decision is to use UEFA only as manually reviewed rules evidence, and current UEFA platform terms prohibit automated scraping/systematic collection. `[VERIFIED: STATE.md][CITED: https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/]`

## Historical Corpus Acceptance

The initial audit should be inventory-driven. OpenFootball publishes public-domain domestic repositories and a Champions League repository through 2025/26, but contributor-maintained availability is not a completeness SLA. The audit must decide which competition-season paths are accepted; downstream code must consume only the accepted manifest, never scan a checkout opportunistically. `[CITED: https://github.com/openfootball][CITED: https://github.com/openfootball/champions-league][CITED: https://github.com/openfootball/football.json]`

Required outputs for one `club-history-<version>` corpus:

| Artifact | Minimum content | Acceptance rule |
|----------|-----------------|-----------------|
| `source_manifest.csv` | repo URL, full commit, commit time, path, competition/season, license ID/URL, retrieval, bytes, raw hash | Every normalized row links to exactly one pinned source; every source is license-reviewed. `[VERIFIED: REQUIREMENTS.md]` |
| `matches.csv` | canonical club IDs, competition/season/stage, temporal fields, split score semantics, status, source lineage | Unique stable match IDs; valid clubs; no unresolved score meaning in active rows. `[VERIFIED: REQUIREMENTS.md]` |
| `coverage_audit.csv` | source/competition/season row counts, clubs, date range, completed/missing-score counts, accepted state | Each accepted competition-season has an explicit reviewer verdict and no silent gaps. `[VERIFIED: REQUIREMENTS.md]` |
| `identity_audit.csv` | source identities, resolved club, method, validity, warning/review state | No unresolved, ambiguous, pending, expired, or cross-domain identity enters active matches. `[VERIFIED: REQUIREMENTS.md]` |
| `duplicate_audit.csv` | exact source duplicates, canonical duplicates, cross-source candidates, disposition | Zero unresolved duplicates in active matches; generated derivatives are not double-counted. `[CITED: https://github.com/openfootball/football.json]` |
| `score_semantics_audit.csv` | raw notation class, regulation/final/ET/shootout interpretation, reviewer/disposition | Only rows with unambiguous canonical semantics can set `counts_for_model = TRUE`. `[VERIFIED: REQUIREMENTS.md]` |
| `temporal_audit.csv` | kickoff precision, evidence-availability policy/result, future/same-cutoff violations | No active row has evidence time after its training eligibility cutoff; date-only rows use the declared conservative policy. `[VERIFIED: REQUIREMENTS.md][ASSUMED]` |
| `corpus_manifest.csv` | corpus ID/schema, component hashes/counts, parser commit, accepted time/reviewer | Self-consistent hashes and `accepted_for_training = TRUE` only when every audit gate passes. `[VERIFIED: R/competition/source_contracts.R]` |

A practical first audit window is the five completed seasons preceding 2026/27 plus European competition rows needed to connect domestic leagues, but this is an initial measurement window rather than a locked model-training decision. Coverage results should determine the final Phase 19 panel. `[ASSUMED]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Regex/string extraction | `jsonlite` | Provider JSON contains nested objects, arrays, nulls, and typed numeric fields. `[CITED: https://docs.football-data.org/general/v4/match.html][VERIFIED: local runtime probe]` |
| Retry timing | Unbounded `Sys.sleep()` loop | `httr2::req_retry()` with `max_tries` and `max_seconds` | It supports bounded attempts, `Retry-After`, backoff, and low-level failure policy. `[CITED: https://httr2.r-lib.org/reference/req_retry.html]` |
| Rate limiting | Ad hoc counters | `httr2::req_throttle(capacity = 9, fill_time_s = 60)` | The official helper implements a token bucket; nine leaves margin under the documented free limit of ten. `[CITED: https://httr2.r-lib.org/reference/req_throttle.html][CITED: https://docs.football-data.org/general/v4/policies.html]` |
| Secret redaction | String replacement after logging | `req_headers_redacted()` plus no serialization and exact-token scans | Redaction must happen before diagnostic output, and the secret-bearing object must remain process-local. `[CITED: https://httr2.r-lib.org/reference/req_headers.html]` |
| Content integrity | Custom checksum format | Existing `digest` SHA-256 canonical row/table/manifest helpers | The repository already validates these hashes and detects order/tamper changes. `[VERIFIED: R/competition/source_contracts.R]` |
| Club fuzzy matching | Edit-distance auto-merge | Source IDs plus reviewed validity-aware aliases | Automatic fuzzy joins can silently merge distinct clubs; ambiguity must block. `[VERIFIED: REQUIREMENTS.md]` |
| Historical versioning | Download timestamp alone | Git commit SHA + path + raw SHA-256 + license metadata | A retrieval date does not identify immutable repository content. `[CITED: https://github.com/openfootball]` |

**Key insight:** Phase 18’s hard problem is authority and evidence, not transport. Reusing the repository’s accepted-bundle transaction while making the provider decision and club identity explicit is safer than adding libraries or broader scraping. `[VERIFIED: codebase][VERIFIED: REQUIREMENTS.md]`

## Common Pitfalls

### Pitfall 1: Missing key becomes a fake pass
**What goes wrong:** Offline fixtures produce an “accepted” decision that is later mistaken for live coverage evidence. `[VERIFIED: REQUIREMENTS.md]`
**Why it happens:** Parser tests and production acceptance share one boolean. `[ASSUMED]`
**How to avoid:** Separate `offline_contract_tests_passed` from `live_provider_decision`; only the latter can enable automation, and its no-key state is `not_run`. `[VERIFIED: STATE.md]`
**Warning signs:** No observed endpoint timestamps/counts, no owner reviewer, or an acceptance artifact created on a machine without the token. `[VERIFIED: local runtime probe]`

### Pitfall 2: Last-known-good conflicts with provider termination terms
**What goes wrong:** The application retains/displays API-derived state after the service relationship ends even though the public terms restrict post-cancellation reference. `[CITED: https://www.football-data.org/about]`
**Why it happens:** Technical rollback policy is designed without a provider-exit policy. `[ASSUMED]`
**How to avoid:** Make termination/retention an owner-reviewed gate and define a provider-exit action that switches to an independently lawful manual/open snapshot or unavailable mode. This is not legal advice. `[CITED: https://www.football-data.org/about]`
**Warning signs:** “Retain forever” appears in the acceptance manifest without supporting permission. `[ASSUMED]`

### Pitfall 3: New-format UCL stage mismatch
**What goes wrong:** The adapter drops league-phase matches because the documented public enum does not show the provider’s actual 2026/27 label. `[CITED: https://docs.football-data.org/general/v4/match.html]`
**Why it happens:** Code assumes `GROUP_STAGE` or `REGULAR_SEASON` from old examples. `[ASSUMED]`
**How to avoid:** Inventory observed stage values in the live spike and require an explicit map before acceptance. `[VERIFIED: REQUIREMENTS.md]`
**Warning signs:** Fewer than the edition-declared league-phase schedule or unknown-stage rows filtered out before coverage counts. `[VERIFIED: ROADMAP.md]`

### Pitfall 4: Provider identity leaks into canonical identity
**What goes wrong:** A provider ID becomes the project club ID, preventing provider exit or creating collisions with national teams. `[VERIFIED: .planning/research/ARCHITECTURE.md]`
**Why it happens:** Provider IDs look stable inside one response. `[ASSUMED]`
**How to avoid:** Keep project-owned `club_id`, source-scoped IDs, `entity_kind`, and validity windows in separate registries. `[VERIFIED: REQUIREMENTS.md]`
**Warning signs:** `club_id` is numeric/provider-derived, or club rows enter `team_identity.csv`. `[VERIFIED: R/competition/team_identity.R]`

### Pitfall 5: Historical full-time scores hide extra time or shootouts
**What goes wrong:** The model learns the wrong goal totals or double-counts shootout goals. `[VERIFIED: REQUIREMENTS.md]`
**Why it happens:** Source-specific `ft` notation is treated as regulation time without auditing round/score annotations. `[CITED: https://github.com/openfootball/football.json]`
**How to avoid:** Keep regulation, extra-time, final, and shootout columns separate and exclude unresolved rows. `[VERIFIED: REQUIREMENTS.md]`
**Warning signs:** One home/away score pair is copied into every score-semantic field. `[ASSUMED]`

### Pitfall 6: Mutable or duplicate historical evidence
**What goes wrong:** Re-running training changes rows, or the same upstream match is ingested once from Football.TXT and once from generated JSON. `[CITED: https://github.com/openfootball/football.json]`
**Why it happens:** Branch URLs are used and generated derivatives are treated as independent sources. `[CITED: https://github.com/openfootball/football.json]`
**How to avoid:** Pin commits, choose one canonical representation per upstream path, and run exact plus canonical duplicate audits. `[VERIFIED: REQUIREMENTS.md]`
**Warning signs:** Source manifest contains `master`, or identical club/date/competition rows have two active source IDs. `[ASSUMED]`

## Code Examples

### Missing-key decision that does not touch accepted state

```r
# Source: Phase 13 fail-closed publication pattern and Phase 18 requirement UCLSRC-01.
phase18_provider_preflight <- function(token = Sys.getenv("FOOTBALL_DATA_API_TOKEN", "")) {
  if (!nzchar(token)) {
    return(data.frame(
      decision = "not_run",
      reason_code = "missing_credential",
      automation_enabled = FALSE,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    decision = "pending_live_checks",
    reason_code = "none",
    automation_enabled = FALSE,
    stringsAsFactors = FALSE
  )
}
```

### Validity-aware source-ID lookup

```r
# Source pattern: R/competition/team_identity.R, adapted for club/source/time scope.
resolve_club_source_id <- function(source_ids, source_system, source_club_id, at_date) {
  rows <- source_ids[
    source_ids$source_system == source_system &
      source_ids$source_club_id == source_club_id &
      source_ids$valid_from <= at_date &
      (is.na(source_ids$valid_to) | at_date <= source_ids$valid_to),
    , drop = FALSE
  ]
  if (nrow(rows) != 1L) stop("club source identity is unresolved or ambiguous", call. = FALSE)
  rows$club_id[[1L]]
}
```

### Failed candidate preserves incumbent bytes

```r
# Source pattern: scripts/acquire_uefa_snapshot.R and test_phase13_refresh_failure.R.
incumbent <- snapshot_tree(accepted_root)
result <- try(build_and_validate_candidate(), silent = TRUE)
if (inherits(result, "try-error")) {
  write_blocked_refresh(reason_code = classify_failure(result))
  stopifnot(identical(snapshot_tree(accepted_root), incumbent))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Treat a free API as open data | Treat it as a revocable keyed service with application, attribution, retention, and exit gates | Required by v4.0 scope | Source acceptance becomes a first-class artifact; automation is conditional. `[VERIFIED: REQUIREMENTS.md][CITED: https://www.football-data.org/about]` |
| Name-centered team normalization | Source-scoped stable IDs plus reviewed aliases and validity windows | Required for the new club domain | Renames and provider changes do not silently change canonical club identity. `[VERIFIED: REQUIREMENTS.md]` |
| Mutable latest historical files | Commit-pinned source inventory and accepted corpus manifests | Standard Git-backed reproducibility pattern | Model inputs can be recreated exactly and audited by source path/hash. `[CITED: https://github.com/openfootball]` |
| Provider table as competition truth | Provider table retained as evidence; rules recomputed later | UCL new-format milestone | Phase 18 stays a source phase and Phase 20 owns tie-break authority. `[VERIFIED: ROADMAP.md]` |

**Deprecated/outdated:**

- Automated UEFA page/hidden-service collection is not an acceptable UCL current-state path under the v4.0 source decision and current UEFA platform terms. Use manually reviewed regulations as rules evidence only. `[VERIFIED: STATE.md][CITED: https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/]`
- The Phase 13 national `team_identity.csv` schema is not a club identity schema because it requires FIFA-oriented national-team fields. `[VERIFIED: R/competition/team_identity.R]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Three normalized club identity tables are preferable to one row with pipe-delimited aliases. | Architecture Pattern 3 | More files and validators, but clearer validity/ambiguity constraints; planner may choose an equivalent normalized representation. |
| A2 | Date-only historical results should become available at the next UTC day boundary. | Architecture Pattern 4 | A different conservative cutoff changes same-day training eligibility; freeze and test the chosen policy before Phase 19. |
| A3 | Five completed seasons are a useful initial historical audit window. | Historical Corpus Acceptance | Too narrow may under-connect clubs/leagues; too broad may increase identity and coverage debt. Treat it as an audit starting point, not a promotion threshold. |
| A4 | Owner/provider clarification may permit the intended normalized display and retention model. | Provider Acceptance Contract | If it does not, automated current-state acquisition remains disabled and Phase 18 must exit in manual/unavailable mode. |

## Open Questions (RESOLVED)

1. **Will the owner accept football-data.org’s application, attribution, retention, and termination terms for this public dashboard? — Resolution: owner review remains a blocking human evidence gate.**
   - What we know: attribution, credential secrecy, one-application scope, and a post-cancellation restriction are publicly stated. `[CITED: https://www.football-data.org/about]`
   - What is unclear: normalized-field display, private raw retention, long-lived last-known-good display, and provider-exit handling for this exact application. `[ASSUMED]`
   - Chosen resolution: code records and validates the review but cannot approve it. Any unresolved dimension leaves automation disabled; written provider clarification is attached to the review when public terms are insufficient. `[CITED: https://www.football-data.org/about]`

2. **Does the live free-tier API represent the 2026/27 UCL league phase and standings completely? — Resolution: only the bounded `live_acceptance_probe` can establish live coverage.**
   - What we know: Champions League is listed in the free tier and the relevant endpoints are documented. `[CITED: https://www.football-data.org/coverage][CITED: https://docs.football-data.org/general/v4/coding_client.html]`
   - What is unclear: actual new-format stage labels, match cardinality, 36-club table shape, update delay, and null behavior for the current edition. `[ASSUMED]`
   - Chosen resolution: after owner review is complete but while automation remains false, an opt-in `live_acceptance_probe` performs only the four fixed competition endpoints in an isolated no-cache run. It checks a reviewed edition-expectation artifact, records the full machine matrix and secret scan, and atomically creates the accepted provider manifest only on an exact pass. Ordinary `provider_live` ingestion remains blocked until that manifest validates. Absent a key, retain `not_run` and automation disabled. `[VERIFIED: local runtime probe]`

3. **Which domestic leagues/seasons have enough OpenFootball coverage for the club model? — Resolution: the five-season set is audit-only.**
   - What we know: public-domain domestic and European repositories exist, but updates are contributor-maintained. `[CITED: https://github.com/openfootball][CITED: https://github.com/openfootball/football.json]`
   - What is unclear: season completeness, identity continuity, cross-league connectivity, and score semantics for the intended training window. `[ASSUMED]`
   - Chosen resolution: Phase 18 audits the declared 2021/22–2025/26 set and may accept a reproducible corpus, but this set is not a model-panel decision or promotion threshold. Phase 19 chooses the model panel only after inspecting the audit evidence. `[VERIFIED: ROADMAP.md]`

4. **What exact evidence-time policy applies to date-only historical rows? — Resolution: freeze next-day UTC availability.**
   - What we know: the public JSON example carries a date and full-time score without a kickoff timestamp. `[CITED: https://github.com/openfootball/football.json]`
   - What is unclear: whether every selected upstream path provides time detail or later corrections. `[ASSUMED]`
   - Chosen resolution: for date-only event date D, keep `kickoff_utc` missing, set `kickoff_precision=date`, and freeze `evidence_available_at_utc` to D+1 at 00:00:00 UTC. Eligibility uses strict evidence time earlier than cutoff, with equality and one-second boundary tests; no kickoff is invented. `[VERIFIED: REQUIREMENTS.md]`

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| R | All Phase 18 code | ✓ | 4.6.1 | — `[VERIFIED: local runtime probe]` |
| `httr2` | Keyed provider adapter | ✓ | 1.2.2 | Offline injected transport for tests only; not production acceptance. `[VERIFIED: local runtime probe]` |
| `jsonlite` | JSON parsing/records | ✓ | 2.0.0 | — `[VERIFIED: local runtime probe]` |
| `digest` | SHA-256 lineage | ✓ | 0.6.39 | — `[VERIFIED: local runtime probe]` |
| `testthat` | Validation suite | ✓ | 3.3.2 | — `[VERIFIED: local runtime probe]` |
| `targets` | Pipeline integration | ✓ | 1.12.0 | Direct CLI during the live acceptance spike. `[VERIFIED: local runtime probe]` |
| Git | Commit pinning/parser identity | ✓ | 2.55.0 | Store pre-resolved full SHAs in source inventory; Git still required to verify fetched checkout. `[VERIFIED: local runtime probe]` |
| `FOOTBALL_DATA_API_TOKEN` | Live provider acceptance | ✗ | — | `not_run` plus manual-snapshot/unavailable mode; no fabricated acceptance. `[VERIFIED: local runtime probe][VERIFIED: ROADMAP.md]` |

**Missing dependencies with no fallback:** A real provider key plus owner terms approval is required to enable automated current-state acquisition. `[VERIFIED: REQUIREMENTS.md]`

**Missing dependencies with fallback:** The phase can still implement and validate all contracts offline and complete with automation disabled, a reviewed manual snapshot if one lawfully exists, or explicit unavailable mode. `[VERIFIED: ROADMAP.md]`

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 `[VERIFIED: local runtime probe]` |
| Config file | `tests/testthat.R` and existing `tests/testthat/` suite `[VERIFIED: codebase]` |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` |
| Full phase run command | `Rscript --vanilla -e 'files <- list.files("tests/testthat", pattern = "^test_phase18_.*[.]R$", full.names = TRUE); for (f in files) testthat::test_file(f)'` |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` `[VERIFIED: AGENTS.md]` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UCLSRC-01 | No-key is `not_run`; offline fixtures cannot enable automation; owner and machine rows are both required; secret scan is clean | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_acceptance.R")'` | ❌ Wave 0 |
| UCLSRC-02 | Provider-shaped competition, teams, matches, and standings map into canonical edition-scoped tables with no token/header leakage | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_football_data_adapter.R")'` | ❌ Wave 0 |
| UCLSRC-03 | Provider/retrieval/source-as-of/edition/schema/raw/canonical hashes validate and tampering fails | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_source_bundle.R")'` | ❌ Wave 0 |
| UCLSRC-04 | HTTP/null/empty/stale/incomplete/schema/identity failures preserve incumbent bytes and write typed blocked reasons | integration/failure injection | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_refresh_failure.R")'` | ❌ Wave 0 |
| CLUBID-01 | Direct source IDs, validity windows, reviewed aliases, ambiguity, overlap, and national cross-domain rejection | unit/contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_identity.R")'` | ❌ Wave 0 |
| CLUBHIST-01 | Commit/license pins, normalized score fields, duplicates, coverage, identity, date-only availability, future-row rejection, and manifest hashes | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase18_club_history_contract.R")'` | ❌ Wave 0 |

### Acceptance-test layers

1. **Deterministic offline layer:** all default CI/test commands use synthetic fixtures and injected transports; no key or network is required. `[VERIFIED: tests/testthat/test_phase13_source_contracts.R]`
2. **Opt-in live layer:** one command runs only when the operator intentionally supplies the token and review inputs. Its output is acceptance evidence, not a routine unit test. `[VERIFIED: REQUIREMENTS.md]`
3. **Human gate:** the owner reviews terms/retention/attribution and the observed coverage matrix. The human decision is hashed and referenced by the machine manifest. `[CITED: https://www.football-data.org/about]`
4. **Failure proof:** snapshot the complete incumbent accepted tree and relevant registries before every injected failure; compare path→SHA-256 maps afterward. `[VERIFIED: tests/testthat/test_phase13_refresh_failure.R]`

### Sampling Rate

- **Per task commit:** run the focused Phase 18 file named by the task.
- **Per wave merge:** run all `test_phase18_*.R` files.
- **Phase gate:** full `tests/testthat` suite green, provider decision artifact validates, and automation remains false unless live/owner acceptance passes.

### Wave 0 Gaps

- [ ] `tests/testthat/test_phase18_source_acceptance.R` — decision states, no-key path, owner/machine conjunction, secret hygiene.
- [ ] `tests/testthat/test_phase18_football_data_adapter.R` — provider projection, lifecycle, enums, cardinality, null/empty/schema drift.
- [ ] `tests/testthat/test_phase18_source_bundle.R` — provenance and hash chain.
- [ ] `tests/testthat/test_phase18_refresh_failure.R` — last-known-good and blocked reason matrix.
- [ ] `tests/testthat/test_phase18_club_identity.R` — source IDs, validity intervals, alias review, ambiguity, cross-domain rejection.
- [ ] `tests/testthat/test_phase18_club_history_contract.R` — pins, license, coverage, duplicates, scores, point-in-time eligibility.
- [ ] `tests/fixtures/phase18/football_data_org/*.json` — synthetic provider-shaped positive and negative fixtures only.
- [ ] `tests/fixtures/phase18/openfootball/*` — tiny synthetic/date-only/ET/shootout/duplicate/rename examples.
- [ ] `tests/fixtures/phase18/provider_terms_review.csv` — synthetic approved/pending/rejected review rows; not a production legal verdict.

### Manual-only verification

The production acceptance gate is necessarily manual plus live: obtain the owner-approved terms review, run with a real key, inspect current 2026/27 endpoint/cardinality/stage/freshness evidence, verify visible attribution requirements, confirm secret scans, and sign the decision. Fixture replay cannot substitute. If the key remains unavailable, the correct verified result is `not_run_missing_credential`, automation disabled, and manual/unavailable mode. `[VERIFIED: REQUIREMENTS.md][CITED: https://www.football-data.org/about]`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes, service credential only | Environment-injected key, redacted request header, no serialization/logging, exact-token scans, documented revocation. `[CITED: https://www.football-data.org/about][CITED: https://httr2.r-lib.org/reference/req_headers.html]` |
| V3 Session Management | no | No user login/session is added in this phase. `[VERIFIED: ROADMAP.md]` |
| V4 Access Control | limited | Only the operator-controlled CLI may perform the live acceptance; static public consumers never receive the key. `[VERIFIED: REQUIREMENTS.md]` |
| V5 Input Validation | yes | Fixed HTTPS host/path allowlist, content-type/JSON/schema/type/cardinality/enum checks, trusted-root paths, no symlinks, and fail-closed identity. `[VERIFIED: R/competition/source_contracts.R][VERIFIED: R/competition/edition_registry.R]` |
| V6 Cryptography | yes, integrity only | TLS transport plus existing SHA-256 content/manifest hashes; never hash a token into an artifact. `[VERIFIED: R/competition/source_contracts.R]` |

### Known Threat Patterns for the Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| API token in Git/log/target metadata | Information Disclosure | Process-local env read, redacted header, no request serialization, output scans, revoke on exposure. `[CITED: https://www.football-data.org/about]` |
| Arbitrary URL or redirect abuse | Spoofing / Information Disclosure | Fixed `https://api.football-data.org/v4` allowlist, fixed endpoint templates, reject user-supplied hosts, record final URL. `[VERIFIED: REQUIREMENTS.md]` |
| Tampered raw/normalized source | Tampering | Raw SHA-256, canonical table hashes, row hashes, manifest self-hash, trusted roots, no symlinks. `[VERIFIED: R/competition/source_contracts.R][VERIFIED: R/competition/edition_registry.R]` |
| Null/empty/stale response promoted | Tampering / Denial of Service | Lifecycle-aware non-empty/cardinality/freshness gates and unchanged incumbent on failure. `[CITED: https://docs.football-data.org/general/v4/policies.html][VERIFIED: tests/testthat/test_phase13_refresh_failure.R]` |
| Rate-limit amplification | Denial of Service | Competition-scoped calls, nine-per-minute throttle, bounded retry/time, no per-ID crawl. `[CITED: https://docs.football-data.org/general/v4/policies.html][CITED: https://httr2.r-lib.org/reference/req_retry.html]` |
| Club/national identity collision | Tampering | Separate roots, `entity_kind`, distinct ID syntax, foreign-key validators, explicit national-ID rejection. `[VERIFIED: REQUIREMENTS.md]` |
| Path traversal/symlink escape | Tampering / Information Disclosure | Existing safe-relative-path, root-containment, and accepted-tree no-symlink checks. `[VERIFIED: R/competition/source_contracts.R][VERIFIED: R/competition/edition_registry.R]` |
| Terms change unnoticed | Repudiation / Compliance risk | Terms URL/hash/review date in acceptance artifact; material change forces re-review and disables automation until accepted. `[CITED: https://www.football-data.org/about]` |

## Sources

### Primary (HIGH confidence)

- Repository source contracts and tests: `R/competition/source_contracts.R`, `R/competition/team_identity.R`, `R/competition/edition_registry.R`, `scripts/acquire_uefa_snapshot.R`, `tests/testthat/test_phase13_source_contracts.R`, and `tests/testthat/test_phase13_refresh_failure.R` — exact local patterns inspected on 2026-09-19. `[VERIFIED: codebase]`
- Project requirements/state/roadmap and milestone research — Phase 18 scope and locked v4.0 decisions inspected on 2026-09-19. `[VERIFIED: .planning]`
- Local runtime probe — R 4.6.1, `httr2` 1.2.2, `jsonlite` 2.0.0, `digest` 0.6.39, `testthat` 3.3.2, `targets` 1.12.0, Git 2.55.0, and absent provider token. `[VERIFIED: local runtime probe]`

### Secondary (MEDIUM confidence)

- [football-data.org v4 overview and examples](https://docs.football-data.org/general/v4/coding_client.html) — `CL` endpoint and authentication examples. `[CITED]`
- [football-data.org Competition resource](https://docs.football-data.org/general/v4/competition.html) — standings, matches, teams, filters, and caveats. `[CITED]`
- [football-data.org Match resource](https://docs.football-data.org/general/v4/match.html) — fields, status lifecycle, and enums. `[CITED]`
- [football-data.org policies](https://docs.football-data.org/general/v4/policies.html), [coverage](https://www.football-data.org/coverage), and [pricing](https://www.football-data.org/pricing) — null/empty behavior, free UCL coverage, delayed state, and quota. `[CITED]`
- [football-data.org terms/about](https://www.football-data.org/about) — application scope, credential secrecy, attribution, disclaimers, and post-cancellation restriction. Owner review required; not legal advice. `[CITED]`
- [`httr2` redacted headers](https://httr2.r-lib.org/reference/req_headers.html), [retry](https://httr2.r-lib.org/reference/req_retry.html), [throttle](https://httr2.r-lib.org/reference/req_throttle.html), and [cache](https://httr2.r-lib.org/reference/req_cache.html) — official implementation behavior. `[CITED]`
- [OpenFootball Champions League](https://github.com/openfootball/champions-league), [football.json](https://github.com/openfootball/football.json), and [organization](https://github.com/openfootball) — CC0/public-domain status, formats, generated-data relationship, and observed repository coverage. `[CITED]`
- [UEFA 2026/27 UCL regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27-Online) — editioned manual rules authority. `[CITED]`
- [UEFA platform terms](https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/) — automated/systematic collection restriction. Owner review required; not legal advice. `[CITED]`

### Tertiary (LOW confidence)

- Initial five-season history window, next-day date-only evidence policy, and normalized three-table club identity layout are planning recommendations marked `[ASSUMED]`; they require confirmation through implementation audit results.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — required versions and functions are installed and repository patterns are inspected.
- Current provider availability: MEDIUM — official documentation is clear, but no token was available for 2026/27 coverage/schema/freshness verification.
- Source rights/retention: MEDIUM for quoted public terms, LOW for application-specific interpretation — owner/provider review is mandatory and this document is not legal advice.
- Club identity architecture: HIGH — based on explicit requirements and proven local fail-closed identity patterns.
- Historical corpus coverage: MEDIUM — license/repository existence is documented, but completeness and score semantics require the Phase 18 audit.
- Validation architecture: HIGH — it extends existing Phase 13 deterministic fixtures and byte-preservation tests.

**Research date:** 2026-09-19
**Valid until:** 2026-10-03 for provider terms/coverage; 2026-10-19 for stable repository architecture patterns.
