# Stack Research

**Domain:** Open-data UEFA Champions League forecasting and static dashboard publication
**Researched:** 2026-09-19
**Confidence:** MEDIUM

## Recommendation in One Sentence

Keep the existing R, `targets`, static-dashboard, and atomic-publication stack; add one isolated `football-data.org` v4 adapter for delayed current UCL state, a pinned OpenFootball CC0 history adapter for club-model training, and a separately promoted `glmnet`-based club model. Do not add a database, web server, frontend framework, scraper, or current-xG dependency.

The stack is technically realistic, but automated publication must be gated on a key-backed source spike. The free API is a service dependency, not open data, and the free fields do not close every UEFA tie-break input.

## Source Stack

| Source | Class | Use | Current availability | Hard constraints |
|--------|-------|-----|----------------------|------------------|
| [football-data.org API v4](https://www.football-data.org/coverage) | Free-but-keyed service | Current UCL fixtures, results, team metadata, and candidate standings | UEFA Champions League is listed in the free tier; free plan includes fixtures, delayed scores/schedules, tables, and 10 calls/minute | API key required; credentials may not be committed; visible attribution is required; scores are delayed; raw-response redistribution rights are not stated clearly enough to assume and require an explicit acceptance review |
| [OpenFootball](https://github.com/openfootball) | Open data, CC0 | Historical domestic-league and UCL results for club Elo and goal-model backfill | European league repositories and a UCL repository exist; the UCL repository currently runs from 2011/12 through 2025/26 | Contributor-maintained coverage is not a current-state SLA; pin commit SHAs and validate row/season completeness before model use |
| [StatsBomb Open Data](https://github.com/hudl/open-data) | Free research data with attribution terms | Optional historical shot-model experiments only | The official manifest lists UCL seasons through 2018/19, but the official 2018/19 match file contains only the final | Not a current UCL feed and not a complete UCL season panel; publication requires StatsBomb attribution and logo; do not make current xG a release feature |
| [UEFA 2026/27 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27-Online) | Manual rules authority | Versioned competition format, tie-break ordering, and knockout topology | Official 2026/27 regulation is published | [UEFA platform terms](https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/) prohibit systematic collection and automated scraping; manually review and encode rules, never automate UEFA page capture |

### Source acceptance gate

Before implementation treats `football-data.org` as production authority, run an edition-scoped source spike with a real key and archive the evidence. It must prove:

1. `CL` current-season match coverage includes every 2026/27 league-phase fixture and result needed by the normalized state contract.
2. Returned stage, status, matchday, team, score, and `lastUpdated` fields are stable enough to map without inference.
3. The standings endpoint either represents the 36-team table correctly or is ignored in favour of recomputing standings from accepted matches.
4. Terms permit the intended public display of normalized/derived fields with the required attribution. Raw API bytes remain in an ignored local cache unless redistribution permission is explicit.
5. A delayed-score refresh cadence is acceptable; this stack is not a live-score system.

If any item fails, keep the dashboard in `unavailable` or reviewed-manual-snapshot mode. Do not silently fall back to UEFA scraping.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| R | Existing tested runtime; workspace is 4.6.1 | Ingestion, modelling, rules, simulation, and payload generation | The existing release system is R-native; switching languages would duplicate contracts and increase verification surface |
| `targets` | 1.12.0 | Incremental orchestration and N-edition publication graph | Already proven in the repository; use the edition registry as data and branch/iterate over editions instead of adding a scheduler or queue |
| `httr2` | 1.3.0 target | Authenticated API acquisition | Official helpers cover redacted headers, token-bucket throttling, retries, and HTTP caching; a controlled upgrade is needed because the workspace currently has 1.2.2 |
| `jsonlite` | 2.0.0 | Decode API and OpenFootball JSON; emit browser payloads | Already used by the competition source contracts and suitable for exact raw-to-normalized adapters |
| `digest` | 0.6.39 | SHA-256 source, rules, model, and publication lineage | Already the repository standard for accepted-source and release integrity |
| `glmnet` | 5.0 | Regularized club attack/defence Poisson candidate | Existing `R/forecast/penalized_poisson.R` already targets `glmnet`; sparse shrinkage is appropriate for many clubs with unequal match counts and cold starts |
| `MASS` | Existing R-recommended version; workspace 7.3-65 | Negative-binomial club baseline | Reuses the existing, interpretable goal-model baseline; keep as a benchmark, not automatic promotion authority |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Matrix` | Workspace 1.7-5 | Sparse attack/defence design matrices | Required by the existing penalized club/team design and `glmnet` |
| `testthat` | Workspace 3.3.2 | Contract, rules, simulation, and publication tests | Use captured synthetic/API fixtures and dependency-injected fetch functions; live-token tests remain opt-in |
| Base R RNG | R runtime | Deterministic league-phase and knockout simulation | Preserve the existing seed policy and output hashing; no simulation package is needed |
| Existing static HTML/CSS/JS renderer | Repository code | Third dashboard edition | Extend the registry-driven renderer; do not create a second frontend stack |

### No New Package Needed For

- Rate limiting: use `httr2::req_throttle(capacity = 9, fill_time_s = 60)` to stay below the documented free-plan limit of 10/minute.
- Transient errors: use `httr2::req_retry()` for 429/503 responses and honour `Retry-After`.
- Secret redaction: read `FOOTBALL_DATA_API_TOKEN` from the environment and set `X-Auth-Token` with `req_headers_redacted()`.
- Conditional caching: use `req_cache()` when the response exposes standard cache headers, while still persisting accepted raw bytes and a SHA-256 provenance manifest under the existing source contract.
- Publication locking: retain the existing atomic directory-lock/staging/backup implementation. Adding `filelock` would create a second locking mechanism without solving a current failure mode.
- Rule simulation: implement pure R functions against versioned inputs. A generic tournament library will not encode UEFA Article 18 or the edition-specific knockout draw contract.

## Integration Points

### 1. Current-state adapter

Add one provider-specific module, for example `R/competition/football_data_org_adapter.R`, behind the existing source-bundle contract.

```text
football-data.org v4
  -> raw response bytes + HTTP/provenance metadata
  -> provider adapter
  -> canonical edition-scoped fixtures/results/team IDs
  -> existing state bundle and validation boundary
```

Recommended calls are competition-scoped rather than one request per match: resolve the configured UCL competition (`CL`) and season, request the season's matches, and request standings only as reconciliation evidence. Do not trust provider stage labels or standings as the UEFA rules authority. Persist provider IDs as aliases; use project-owned stable club IDs in model and publication contracts.

### 2. Historical club data

Add an OpenFootball adapter that accepts repository URL, commit SHA, season, competition, and license metadata. Normalize domestic and European match results into one club-match schema before rating/model code sees them. Validate duplicates, abandoned/awarded fixtures, neutral venues, regulation versus extra-time scores, club renames, and season completeness.

The current-state API and the historical CC0 corpus must remain separate adapters. They may reconcile through canonical club IDs, but one source must not silently backfill the other's missing rows.

### 3. Club forecast authority

Create a club-only model bundle and promotion manifest. Reuse the existing sparse penalized-Poisson, NB baseline, calibration, scoring, and rolling-origin benchmark machinery, but use club histories, club identity, club-specific hyperparameters, and UCL/domestic holdouts. National-team Elo or its release manifest must never satisfy the club model gate.

Recommended first candidates:

1. Internally computed club Elo from accepted domestic plus European results.
2. Regularized Poisson attack/defence model using `glmnet` with home/neutral context and optional Elo offset.
3. Existing negative-binomial Elo baseline as a benchmark.

Promote only on predeclared log-loss/Brier/calibration gates over temporally held-out club matches and UCL editions. Current xG, injuries, and lineups remain unavailable fields, not zero-valued predictors.

### 4. UEFA rules and simulation

Encode the reviewed 2026/27 regulation into a local, hashed rules object. Compute the league table from accepted match rows. Article 18 requires result-derived criteria plus opponent aggregates, disciplinary points, and club coefficient. The first opponent criteria can be derived from complete results; the free API does not include bookings and does not document club coefficients in its free plan.

Therefore add a versioned manual rule-input overlay for observed disciplinary totals and club coefficients, with provenance and acceptance checks. For future simulated matches, define and validate an explicit simulation policy for disciplinary tie resolution; if the required input/policy is absent, return an unresolved/fail-closed state rather than substituting alphabetical order. This is a source gap, not a package gap.

### 5. N-edition publishing

Generalize hardcoded two-edition lists to registry iteration. Each edition contributes the same typed publication slots, and the atomic transaction operates over the registry's accepted editions. Keep a single selector, manifest, staging root, rollback path, and read-back validator. No database or runtime API is required for a third edition.

## Development and Operational Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Existing `launchd` job | Scheduled refresh | Keep one bounded batch; delayed-source semantics mean hourly is sufficient and should not be described as live |
| Environment variable | API secret injection | `FOOTBALL_DATA_API_TOKEN`; never serialize it in `_targets` metadata, request logs, fixtures, manifests, or Git |
| Captured JSON fixtures | Adapter regression tests | Scrub tokens and headers; retain representative scheduled, postponed, awarded, finished, knockout, and schema-drift cases |
| Existing publication transaction | Atomic third-edition release | Extend target enumeration from fixed pairs to registry-derived N editions; keep fail-closed rollback |

## Installation / Dependency Change

Do not install a broad sports-data SDK. Declare only the packages the repository already uses plus `glmnet` for the club model.

```r
install.packages(c(
  "targets",   # 1.12.0
  "httr2",     # 1.3.0
  "jsonlite",  # 2.0.0
  "digest",    # 0.6.39
  "glmnet",    # 5.0
  "testthat"
))
```

The `httr2` 1.3.0 upgrade must be performed with `rlang >= 1.3.0`; the current workspace has `rlang` 1.2.0. Treat this as a controlled dependency upgrade with the full existing test suite, because `httr2` 1.3.0 also changes HTTP cache filenames. If the upgrade is deferred, keep 1.2.2 temporarily and implement the adapter against its verified API surface.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| football-data.org free v4 adapter | Paid football-data.org Deep Data/Standard | Only if the project deliberately expands scope to lineups/bookings or needs less-delayed data and accepts a paid dependency; still keep the same adapter boundary |
| OpenFootball CC0 pinned history | A separately licensed commercial historical feed | Use only if completeness checks show the open panel cannot validate a club model and the core value is formally changed to permit a paid dependency |
| Internal club Elo | ClubElo ratings | Use only after a stable machine interface and redistribution/model-use license are explicitly confirmed; otherwise it is an unaccepted external authority |
| Pure R UEFA rules | Generic bracket/simulation package | Only for non-authoritative exploratory work; bespoke UEFA tie-break and draw rules still need project code |
| Static dashboard | Shiny/server API | Only if user-driven queries or authenticated/private data become a requirement in a later milestone |

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Automated UEFA website scraper (`rvest`, browser automation, hidden endpoints) | UEFA terms prohibit systematic collection and automated scraping; it creates an immediate compliance and stability risk | Manually reviewed, versioned rules plus an accepted machine-readable provider for match state |
| `worldfootballR`, Python `soccerdata`, or similar scraping wrappers | They do not create permission where the upstream site withholds it and hide source-specific failure modes | Direct, narrow provider adapters with explicit terms and provenance |
| Current xG as a v4.0 dependency | No accepted free current UCL xG feed was found; StatsBomb Open Data is historical and incomplete for UCL | Results-based club Elo/goal model; render xG as unavailable |
| Injury or lineup model | Free plan does not provide these features and no accepted open current feed was found | Explicit unavailable states; consider a separately licensed future enrichment |
| External ClubElo as release authority | Public availability is not the same as a licensed, stable API or redistributable source | Compute club Elo from accepted match history |
| New database, message queue, Docker service, React/Vue, or Shiny | The data volume and static publication path do not require them; they multiply deployment and rollback surface | Existing files, `targets`, and static assets |
| `filelock` | Existing atomic directory lock already owns publication serialization | Extend the one proven transaction boundary |
| Alphabetical or random tie-break fallback | It is not the UEFA final table rule and would create false certainty | Versioned disciplinary/coefficient inputs or an explicit unresolved state |

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `httr2` 1.3.0 | R >= 4.1, `curl` >= 6.4.0, `rlang` >= 1.3.0 | Workspace R 4.6.1 and `curl` 7.1.0 satisfy requirements; `rlang` 1.2.0 must be upgraded |
| `targets` 1.12.0 | R >= 3.5 | No milestone-specific framework change; preserve current target metadata and run full DAG tests after registry generalization |
| `jsonlite` 2.0.0 | Current R | Verify simplification behaviour against captured provider JSON before accepting schema changes |
| `glmnet` 5.0 | R >= 3.6, `Matrix` >= 1.0-6, C++17 toolchain | Existing club/team sparse model code already calls `glmnet`; ensure it is declared and installed in the release environment |
| `digest` 0.6.39 | R >= 3.3 | Continue SHA-256 hashing; do not use it for API secret storage |

## Hard Gaps That Roadmap Must Address

1. **API acceptance is unproven without a key.** Documentation establishes free UCL coverage and limits, but a live 2026/27 capture must prove schema and completeness.
2. **The free current-state feed is delayed, not live.** Product language and freshness indicators must say so.
3. **Full Article 18 inputs are not all free API fields.** Bookings are a paid Deep Data feature and club coefficients are not documented in the free contract; manual accepted overlays or fail-closed outcomes are required.
4. **No accepted current xG, injury, or lineup source exists.** Those features must remain unavailable in v4.0.
5. **Open historical coverage needs audit.** CC0 is excellent for licensing, but completeness, club identity, and cross-league comparability must be measured before model training.

## Sources

- [football-data.org pricing](https://www.football-data.org/pricing) — free-plan fields, delayed scores/schedules, and 10 calls/minute (official; MEDIUM via verified provider seam)
- [football-data.org coverage](https://www.football-data.org/coverage) — Champions League in free tier (official; MEDIUM)
- [football-data.org terms](https://www.football-data.org/about) — registration, API-key secrecy, and attribution (official; MEDIUM)
- [football-data.org v4 policies](https://docs.football-data.org/general/v4/policies.html) — throttling and null semantics (official; MEDIUM)
- [football-data.org v4 Match resource](https://docs.football-data.org/general/v4/match.html) — match fields, stages, and statuses (official; MEDIUM)
- [httr2 retry documentation](https://httr2.r-lib.org/reference/req_retry.html), [throttle documentation](https://httr2.r-lib.org/reference/req_throttle.html), [cache documentation](https://httr2.r-lib.org/reference/req_cache.html), and [redacted headers](https://httr2.r-lib.org/reference/req_headers.html) — adapter implementation behaviour (official; MEDIUM)
- [OpenFootball organisation](https://github.com/openfootball), [Champions League repository](https://github.com/openfootball/champions-league), and [football.json repository](https://github.com/openfootball/football.json) — CC0 coverage and update model (official project repositories; MEDIUM)
- [StatsBomb/Hudl Open Data](https://github.com/hudl/open-data), [competition manifest](https://raw.githubusercontent.com/hudl/open-data/master/data/competitions.json), and [2018/19 UCL match file](https://raw.githubusercontent.com/hudl/open-data/master/data/matches/16/4.json) — terms and observed one-final coverage (official repository; MEDIUM)
- [UEFA Champions League 2026/27 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27-Online) and [official tie-break explanation](https://www.uefa.com/uefachampionsleague/news/0291-1bd88ae04870-e1e038c319e3-1000--champions-league-league-phase-standings-how-teams-level-on-/) — 36-team format and Article 18 ordering (official; MEDIUM)
- [UEFA general terms](https://www.uefa.com/news-media/news/0256-0dc91ad71f32-ce04913814f0-1000--general-terms-and-conditions/) — no automated scraping/systematic collection (official; MEDIUM)
- [CRAN: httr2](https://cran.r-project.org/package=httr2), [targets](https://cran.r-project.org/package=targets), [jsonlite](https://cran.r-project.org/package=jsonlite), [digest](https://cran.r-project.org/package=digest), [glmnet](https://cran.r-project.org/package=glmnet), and [filelock](https://cran.r-project.org/package=filelock) — current versions and dependencies (official; MEDIUM)

---
*Stack research for: UEFA Champions League Forecast Dashboard v4.0*
*Researched: 2026-09-19*
