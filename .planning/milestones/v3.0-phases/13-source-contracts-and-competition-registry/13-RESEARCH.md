# Phase 13: Source Contracts and Competition Registry - Research

**Researched:** 2026-08-13
**Domain:** Structured UEFA source capture, auditable snapshot contracts, canonical team identity, and competition-edition registry for a file-based R pipeline.
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Accept structured UEFA resources only. Ordinary HTML pages and PDFs are not first-class accepted snapshot inputs for this contract.
- **D-02:** Assemble fixtures, groups, standings, results, and competition status into one edition-scoped accepted snapshot bundle, even when UEFA exposes them through separate structured resources.
- **D-03:** Treat each bundle as a candidate that must pass required-resource and schema validation before acceptance. On failure, reject the candidate and retain the last accepted bundle.
- **D-04:** Retain exact raw response bytes in an ignored, edition-scoped local snapshot store. Keep Git publication compact by committing manifests, hashes, parser identity, and compact normalized or dashboard-ready artifacts rather than raw response bodies.
- **D-05:** Record provenance at both bundle and raw-artifact level. Each artifact row must expose its source URL, retrieval time, byte count, raw SHA-256, parser identity, and fallback status; the accepted bundle must reference its component artifacts.
- **D-06:** A manual fallback requires explicit review before publication. The operator must record source, retrieval date, reason, operator note, and checksum, and the bundle must carry an acceptance/review state.
- **D-07:** A manual fallback replaces a complete edition-wide bundle. Do not silently mix official and fallback resources within one accepted edition snapshot.
- **D-08:** Parser identity is the Git commit only, as selected by the user. The implementation must make that identity available in each accepted snapshot manifest and keep the source bytes and hashes sufficient for replay.
- **D-09:** Use an xGelo-owned stable `team_id` as the canonical team key. Retain FIFA code, UEFA source ID, current UEFA display name, and aliases as mapped attributes for interoperability and auditability.
- **D-10:** If a UEFA team cannot be mapped unambiguously, use normalized display-name matching as a fallback and emit a visible warning and audit record. The fallback must not be silent; planner and implementer should define the warning/mapping fields and ensure downstream publication can surface them.
- **D-11:** Keep canonical identity stable when a source display name changes. Preserve the current UEFA display name on the snapshot row and append reviewed historical names to an alias mapping.
- **D-12:** Assign explicit xGelo competition-edition IDs, including `uefa_nations_league_2026_27` and `uefa_euro_2028_qualifying`. Preserve source-provided edition IDs as metadata rather than using them as the sole internal key.
- **D-13:** Use a strict forward lifecycle: `pre_draw -> scheduled -> in_progress -> complete`. Any lifecycle may enter `blocked`; recovery requires explicit operator action and validation.
- **D-14:** Require a complete registry release contract before publication, including lifecycle state, ruleset version, source bundle, model release, and output bundle target. The EURO pre-draw entry uses explicit pre-draw source and output values rather than null release fields.
- **D-15:** Pin an explicit approved model-release ID in each edition registry entry. Changing the model release requires a new registry revision and audit entry.
- **D-16:** If a candidate refresh is blocked, keep the last accepted output active, mark the edition and refresh batch as blocked, and expose the failure and timestamp in metadata. Never publish a partial bundle or silently switch to an unreviewed fallback.

### the agent's Discretion
- Choose the concrete structured-source adapter boundaries, local directory layout, table schemas, validation implementation, and test fixtures in a way that follows the existing file-based R patterns.
- Choose the exact mapping warning fields and confidence representation needed to make the selected display-name fallback auditable, provided the warning is visible and ambiguous mappings cannot pass silently.

### Deferred Ideas (OUT OF SCOPE)
- Competition-specific standings, match-status semantics, form windows, point-in-time forecasts, and leakage tests are Phase 14 work.
- Nations League promotion/relegation, quarter-final, and title-path rules are Phase 15 work.
- EURO qualifying activation, host places, Nations League-linked play-offs, and topology rules are Phase 16 work.
- Shared dashboard rendering, filters, collapsed data credits, hourly launchd refresh, browser smoke checks, atomic promotion, and compact auto-push are Phase 17 work.

No additional out-of-scope ideas were raised during discussion.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATA-01 | The analyst can capture official UEFA snapshots for competition fixtures, groups, standings, results, and status. `[VERIFIED: REQUIREMENTS.md]` | Bundle the five resource classes into one accepted edition contract; use page-bootstrap discovery plus structured service responses or embedded JSON, not rendered prose. `[VERIFIED: codebase grep][CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]` |
| DATA-02 | Every captured snapshot records its source URL, retrieval time, raw-byte hash, parser version, and fallback status. `[VERIFIED: REQUIREMENTS.md]` | Reuse the repo’s SHA-256 manifest pattern with raw-byte retention, canonical row hashing, and staged write helpers. `[VERIFIED: codebase grep][CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| DATA-03 | UEFA and open historical results are normalized to stable team IDs and competition-edition IDs while preserving source display names. `[VERIFIED: REQUIREMENTS.md]` | Centralize team identity resolution with explicit `team_id`, source IDs, FIFA codes, current display names, aliases, and a visible normalized-name fallback path. `[VERIFIED: codebase grep]` |
| DATA-04 | The pipeline supports audited manual fallback snapshots with source, retrieval date, reason, operator note, and checksum visible in the published metadata. `[VERIFIED: REQUIREMENTS.md]` | Treat fallback as an edition-wide reviewed bundle with explicit review state and no per-artifact mixing inside an accepted bundle. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]` |
| COMP-01 | Each competition edition is registered with lifecycle state, ruleset version, source bundle, model release, and output bundle. `[VERIFIED: REQUIREMENTS.md]` | Use one revisioned registry row per edition with forward lifecycle, blocked overlay, pinned Phase 12 release ID, explicit source bundle ID, and explicit pre-draw output slots for EURO. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]` |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Implement Phase 13 in R inside the repository’s script-oriented, file-based pipeline rather than introducing a server-backed API or a second runtime. `[VERIFIED: AGENTS.md]`
- Keep the dashboard/publication architecture static and compact; do not plan to commit large raw response bodies to Git. `[VERIFIED: AGENTS.md]`
- Treat official UEFA competition data as authoritative and manual fallbacks as explicit audited exceptions. `[VERIFIED: AGENTS.md]`
- Reuse existing model-release context from v2.0 instead of changing forecasting policy in this phase. `[VERIFIED: AGENTS.md]`
- Validate with `testthat::test_dir("tests/testthat")` and plan phase-specific contract tests inside the existing `tests/testthat/` suite. `[VERIFIED: AGENTS.md]`
- Respect the existing layer boundary: this phase freezes source, identity, and registry contracts only; standings, forecasts, rules, simulation, rendering, and hourly operations remain later phases. `[VERIFIED: AGENTS.md][VERIFIED: 13-CONTEXT.md]`

## Summary

Phase 13 should be planned as a contract-freezing phase, not a competition-logic phase. The repository already has strong local analogs for strict CSV schema validation, canonical SHA-256 row and table hashing, trusted-root path checks, staged file publication, and fail-closed manifest validation in [`R/benchmark/registry.R`](../../../R/benchmark/registry.R), [`R/benchmark/contracts.R`](../../../R/benchmark/contracts.R), [`R/release/release_contract.R`](../../../R/release/release_contract.R), and [`R/release/release_bundle.R`](../../../R/release/release_bundle.R). `[VERIFIED: codebase grep]` The correct plan is to reuse those patterns for one accepted-bundle contract per edition, one artifact manifest per bundle, one centralized team identity map, and one edition registry row per competition edition. `[VERIFIED: codebase grep]`

The external source surface is workable but operationally volatile. The official Nations League fixtures and standings pages currently expose stable competition bootstrap metadata in page source, including `competitionId=2014`, `currentSeason=2027`, and service hostnames such as `match.uefa.com`, `comp.uefa.com`, `standings.uefa.com`, `bracket-service.uefa.com`, and `fsp-draw-service.uefa.com`. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]` The fixtures and standings pages are JS shells keyed by competition and season, while individual match pages inline richer structured match JSON in `data-options`, including team IDs, display names, kickoff time, round, and competition metadata. `[CITED: https://www.uefa.com/uefanationsleague/match/2048003--netherlands-vs-germany/]` That means the plan should contract against captured structured payloads plus exact raw bytes, not against rendered prose HTML. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/match/2048003--netherlands-vs-germany/]`

EURO qualifying is still officially pre-draw on August 13, 2026. UEFA’s official draw announcement says the qualifying draw is on Sunday, December 6, 2026 in Belfast, and the article states the qualifying group stage begins in March 2027 and ends in November 2027. `[CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]` The official qualification-system announcement says there will be twelve groups of four or five teams, 12 group winners and 8 best runners-up qualify directly, host-reserved places may apply, and the remaining places depend on play-offs linked to the 2026/27 Nations League. `[CITED: https://www.uefa.com/news-media/news/0299-1dcf36ade17c-099c9d4b7d85-1000--uefa-uefaeuro2028-qualification-system-approved/]` The official `euro2028/fixtures-results` URL currently returns HTTP 404 and `euro2028/standings` currently redirects to `/errors/`, so the registry must encode an explicit `pre_draw` edition with real source and output slots but no fabricated groups, fixtures, or standings. `[VERIFIED: local probe][CITED: https://www.uefa.com/euro2028/about/]`

**Primary recommendation:** Plan Phase 13 around four committed contracts and one ignored raw store: `source_bundles`, `source_artifacts`, `team_identity`, `competition_editions`, plus edition-scoped accepted normalized snapshot files, while keeping raw response bytes local-only and fail-closing any incomplete, mixed, or ambiguous candidate bundle. `[VERIFIED: codebase grep][VERIFIED: AGENTS.md][CITED: https://www.uefa.com/uefanationsleague/fixtures-results/]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Structured UEFA payload discovery | API / Backend | Browser / Client | The official pages expose bootstrap metadata and service hostnames, but Phase 13 should resolve and persist structured payloads in R scripts, not in a browser runtime. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]` |
| Exact raw snapshot storage | Database / Storage | API / Backend | The locked contract requires retaining exact raw bytes in an ignored local store and keeping committed outputs compact. `[VERIFIED: 13-CONTEXT.md][VERIFIED: AGENTS.md]` |
| Candidate bundle validation | API / Backend | Database / Storage | Required-resource checks, schema validation, SHA-256 verification, and fallback-mixing rejection belong in deterministic R validators modeled on existing benchmark/release contracts. `[VERIFIED: codebase grep]` |
| Team identity normalization | API / Backend | Database / Storage | Stable `team_id` assignment, alias handling, and visible fallback warnings are business rules over snapshot rows, then persisted as checked mapping tables. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]` |
| Competition-edition registry | Database / Storage | API / Backend | Edition lifecycle, ruleset version, model release pin, source bundle ID, and output bundle target are durable registry state consumed by later phases. `[VERIFIED: 13-CONTEXT.md]` |
| Publication guardrails | API / Backend | Database / Storage | Blocked-state handling and “retain last accepted bundle” behavior are fail-closed orchestration rules, not dashboard logic. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R + `utils` | R 4.6.1 `[VERIFIED: local probe]` | CSV IO, directory control, staged file writes, path normalization | The repo is script-oriented and already uses plain R files plus file contracts rather than an installed package namespace. `[VERIFIED: codebase grep][VERIFIED: AGENTS.md]` |
| `digest` | 0.6.39, published 2025-11-19 `[CITED: https://cran.r-project.org/web/packages/digest/index.html]` | SHA-256 for raw artifacts, row hashes, and manifest hashes | The package explicitly supports `sha-256`, the repo already uses it for file and row hashing, and it avoids hand-rolled checksum logic. `[VERIFIED: codebase grep][CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| `jsonlite` | 2.0.0, published 2025-03-27 `[CITED: https://cran.r-project.org/web/packages/jsonlite/index.html]` | JSON manifest serialization, parsing, and validation | The package is already installed locally and is designed for robust JSON parsing/generation for web-facing data. `[VERIFIED: local probe][CITED: https://cran.r-project.org/web/packages/jsonlite/index.html]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `testthat` | 3.3.2 `[VERIFIED: local probe]` | Deterministic contract and fixture tests | Use for every Phase 13 validator, registry transition rule, and fallback-audit invariant. `[VERIFIED: AGENTS.md]` |
| Git CLI | 2.55.0 `[VERIFIED: local probe]` | Parser identity source and compact publication discipline | Use `git rev-parse HEAD` for parser identity only; do not invent semantic parser versions in this phase. `[VERIFIED: 13-CONTEXT.md]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `digest` | `openssl` | `openssl` is stronger for broader crypto, but the repo already uses `digest` and Phase 13 only needs auditable SHA-256 hashes, not custom cryptographic primitives. `[VERIFIED: codebase grep][CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| `jsonlite` | base string concatenation | Base string building is brittle for compact manifests and review metadata; `jsonlite` already documents `toJSON()`, `fromJSON()`, and `validate()`. `[CITED: https://cran.r-project.org/web/packages/jsonlite/index.html][CITED: https://cran.r-project.org/web/packages/jsonlite/jsonlite.pdf]` |
| New network package | existing file-based acquisition plus existing runtime tools | This phase can be planned without introducing new R dependencies because the essential work is contract design, raw-byte retention, validation, and registry state. `[VERIFIED: codebase grep][VERIFIED: local probe]` |

**Installation:**
```bash
# No new package installation is required for Phase 13.
```

**Version verification:** `Rscript` 4.6.1, `digest` 0.6.39, `jsonlite` 2.0.0, `testthat` 3.3.2, and `targets` 1.12.0 are all available locally. `[VERIFIED: local probe]`

## Package Legitimacy Audit

No new package installation is required for Phase 13. Reuse the already-installed `digest`, `jsonlite`, and `testthat` packages. `[VERIFIED: local probe]`

## Architecture Patterns

### System Architecture Diagram

```text
Official UEFA structured page bootstrap / service payloads
        + reviewed manual structured fallback bundle
        + existing open historical identity context
                         |
                         v
              candidate raw-byte capture
              (ignored local edition store)
                         |
                         v
             bundle validator + artifact manifest
       required resources / schema / sha256 / review gates
                         |
               +---------+---------+
               |                   |
               v                   v
      normalized snapshot tables   team identity resolution
      fixtures/groups/standings/   stable team_id + source ids
      results/status by edition    visible fallback warnings
               |                   |
               +---------+---------+
                         v
               competition edition registry
         lifecycle + ruleset + source bundle + model release
                         |
                         v
                committed compact artifacts only
```

### Recommended Project Structure
```text
R/competition/
├── source_contracts.R      # bundle/artifact schemas, validators, staged writes
├── team_identity.R         # canonical team_id resolution and warning-bearing fallback
└── edition_registry.R      # lifecycle transitions and registry validation

scripts/
└── acquire_uefa_snapshot.R # one manual/scripted entry point for candidate capture + acceptance

data/competition/
├── accepted/
│   ├── uefa_nations_league_2026_27/
│   └── uefa_euro_2028_qualifying/
├── registries/
│   ├── source_bundles.csv
│   ├── source_artifacts.csv
│   ├── team_identity.csv
│   └── competition_editions.csv
└── local_raw/              # ignored exact-byte store; not committed

tests/testthat/
├── test_phase13_source_contracts.R
└── test_phase13_competition_registry.R
```

Use one committed `accepted/<edition_id>/` directory containing compact normalized snapshot outputs plus manifest files, and one ignored `data/competition/local_raw/` tree containing exact raw bytes and candidate staging material. This mirrors the repo’s existing split between local raw/cache state and compact committed publication artifacts. `[VERIFIED: AGENTS.md][VERIFIED: codebase grep]`

### Pattern 1: Candidate Bundle Then Accepted Bundle
**What:** Capture a full edition candidate first, validate all five required resource classes plus fallback/review invariants, and only then promote one accepted bundle ID. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`
**When to use:** Every official refresh and every manual fallback submission. `[VERIFIED: 13-CONTEXT.md]`
**Example:**
```r
# Source: R/release/release_bundle.R and R/benchmark/registry.R local patterns
write_phase13_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 13 CSV", call. = FALSE)
}

validate_candidate_bundle <- function(bundle, artifacts) {
  required_types <- c("fixtures", "groups", "standings", "results", "status")
  if (!setequal(required_types, unique(artifacts$artifact_type))) {
    stop("Candidate bundle is incomplete", call. = FALSE)
  }
  if (length(unique(artifacts$fallback_status)) != 1L) {
    stop("Accepted bundle cannot mix official and fallback artifacts", call. = FALSE)
  }
}
```

### Pattern 2: Centralized Team Identity With Explicit Warning Path
**What:** Resolve source rows through one canonical map, then record mapping method, warning state, and source values on every normalized row. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`
**When to use:** Every normalized fixture, standings, results, and groups row. `[VERIFIED: 13-CONTEXT.md]`
**Example:**
```r
# Source: R/elo/preprocess.R local alias-normalization pattern, adapted for Phase 13
normalize_team_key <- function(x) {
  x <- iconv(tolower(trimws(as.character(x))), to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("[[:space:]]+", " ", x))
}

resolve_team_identity <- function(source_team_id, display_name, identity_map) {
  direct <- identity_map[identity_map$uefa_source_team_id == source_team_id, , drop = FALSE]
  if (nrow(direct) == 1L) return(transform(direct, mapping_method = "source_id", mapping_warning = "none"))
  normalized <- normalize_team_key(display_name)
  alias <- identity_map[identity_map$normalized_alias == normalized, , drop = FALSE]
  if (nrow(alias) == 1L) return(transform(alias, mapping_method = "normalized_display_name", mapping_warning = "visible_review_required"))
  stop("Unresolved or ambiguous team identity", call. = FALSE)
}
```

### Anti-Patterns to Avoid
- **Rendered-HTML scraping:** Do not contract against the visible prose page body when the official page bootstrap is only a shell and the structured data lives in embedded JSON or backing services. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]`
- **Partial fallback mixing:** Do not let one accepted bundle contain some official artifacts and some manual fallback artifacts. `[VERIFIED: 13-CONTEXT.md]`
- **Silent fuzzy mapping:** Do not use unbounded fuzzy matching or silent alias replacement for unmapped UEFA teams. `[VERIFIED: 13-CONTEXT.md]`
- **Registry nulls for EURO pre-draw:** Do not represent EURO as “missing” when it is actually an explicit `pre_draw` edition with real source and output slots. `[VERIFIED: 13-CONTEXT.md][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SHA-256 hashing | Custom checksum concatenation | `digest::digest(..., algo = "sha256")` | The repo already uses it for row and file hashes, and CRAN documents direct SHA-256 support. `[VERIFIED: codebase grep][CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| JSON serialization | Manual string templating | `jsonlite::toJSON()`, `fromJSON()`, and `validate()` | Phase 13 needs compact manifests and auditable review metadata; manual JSON is error-prone. `[CITED: https://cran.r-project.org/web/packages/jsonlite/index.html][CITED: https://cran.r-project.org/web/packages/jsonlite/jsonlite.pdf]` |
| Atomic publication | Ad hoc overwrite writes | The staged write pattern already used in `R/release/release_bundle.R` | Fail-closed publication is already solved locally. `[VERIFIED: codebase grep]` |
| Identity fallback | Per-source alias logic scattered across scripts | One checked `team_identity.csv` plus one resolver function | The repo already shows alias drift risk when normalization is duplicated. `[VERIFIED: codebase grep]` |
| Lifecycle control | Free-form strings with no validator | One registry validator with allowed transitions and blocked overlay | Forward-only lifecycle plus explicit blocked state is a locked decision and must be testable. `[VERIFIED: 13-CONTEXT.md]` |

**Key insight:** Phase 13 is mostly about freezing contracts that prevent later logic from becoming unreplayable or ambiguous; custom “quick” solutions here create downstream rewrite risk immediately. `[VERIFIED: codebase grep][VERIFIED: 13-CONTEXT.md]`

## Common Pitfalls

### Pitfall 1: Treating normalized display-name fallback as silent convenience
**What goes wrong:** An unmapped UEFA team flows through with a guessed `team_id`, and later phases cannot tell whether identity was authoritative or a fallback guess. `[VERIFIED: 13-CONTEXT.md]`
**Why it happens:** Existing normalization helpers are convenient, so it is tempting to reuse them without recording method, warning, or ambiguity state. `[VERIFIED: codebase grep]`
**How to avoid:** Restrict fallback to deterministic normalized exact-match alias lookup, record `mapping_method`, `mapping_warning`, `source_display_name`, and `alias_review_state`, and fail on ambiguous matches. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`
**Warning signs:** Rows appear with `team_id` but no source ID, no FIFA code, and no visible warning fields. `[VERIFIED: 13-CONTEXT.md]`

### Pitfall 2: Letting parser identity drift away from Git commit SHA
**What goes wrong:** Accepted bundles become unreplayable because parser identity is a version string, branch name, or dirty-worktree token instead of one immutable commit. `[VERIFIED: 13-CONTEXT.md]`
**Why it happens:** Release code often records human-friendly labels, but the user explicitly locked parser identity to Git commit only. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`
**How to avoid:** Resolve parser identity with `git rev-parse HEAD`, store that exact SHA on bundle and artifact rows, and reject acceptance if it is missing. `[VERIFIED: 13-CONTEXT.md][VERIFIED: local probe]`
**Warning signs:** Manifest fields like `parser_version = v1` or `parser_version = main-dirty` appear anywhere in accepted artifacts. `[VERIFIED: 13-CONTEXT.md]`

### Pitfall 3: Pulling Phase 14 responsibilities into the Phase 13 snapshot contract
**What goes wrong:** The plan starts computing official standings semantics, recent-form windows, or forecast states inside the capture layer. `[VERIFIED: 13-CONTEXT.md][VERIFIED: ROADMAP.md]`
**Why it happens:** Fixtures, standings, and results are adjacent to later competition logic, so it is easy to over-normalize now. `[VERIFIED: ROADMAP.md]`
**How to avoid:** Limit accepted outputs to source-shaped normalized snapshot tables plus identity and registry contracts; defer all competition logic to later phases. `[VERIFIED: 13-CONTEXT.md][VERIFIED: ROADMAP.md]`
**Warning signs:** Planned files mention tie-breakers, official rankings logic, match-state semantics, or forecast columns beyond raw source status. `[VERIFIED: ROADMAP.md]`

### Pitfall 4: Publishing raw bytes or mixed candidate debris into Git
**What goes wrong:** Repository history bloats, and accepted artifacts no longer clearly separate durable manifests from local raw capture state. `[VERIFIED: 13-CONTEXT.md][VERIFIED: AGENTS.md]`
**Why it happens:** The easiest first implementation is to commit everything produced during capture. `[VERIFIED: codebase grep]`
**How to avoid:** Keep exact raw bytes in an ignored local store, commit only accepted normalized artifacts plus manifests, and stage writes under trusted project-relative roots. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`
**Warning signs:** Large raw JSON bodies, response dumps, or candidate staging directories appear in `git status` as tracked outputs. `[VERIFIED: AGENTS.md]`

### Pitfall 5: Modeling EURO as “missing data” instead of an explicit pre-draw edition
**What goes wrong:** Later phases cannot distinguish “awaiting official draw” from “source acquisition failed,” and planners start fabricating groups or null registry slots. `[VERIFIED: 13-CONTEXT.md]`
**Why it happens:** The official fixtures and standings surfaces are not live yet, so omission looks simpler than explicit state. `[VERIFIED: local probe]`
**How to avoid:** Register `uefa_euro_2028_qualifying` immediately with `lifecycle_state = pre_draw`, explicit source metadata, explicit output target, and no invented fixture/group rows. `[VERIFIED: 13-CONTEXT.md][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]`
**Warning signs:** Registry fields are null, or dummy group rows appear before December 6, 2026. `[VERIFIED: 13-CONTEXT.md][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]`

## Code Examples

Verified patterns from current repository code:

### Canonical Row Hash Validation
```r
# Source: R/benchmark/contracts.R
benchmark_contract_row_hash <- function(data, hash_col) {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(i) {
    digest::digest(paste(vapply(data[i, fields, drop = FALSE], as.character, character(1)), collapse = "|"),
      algo = "sha256", serialize = FALSE)
  }, character(1))
}
```

### Staged Compact JSON Publication
```r
# Source: R/release/release_bundle.R
phase12_release_write_json <- function(value, path) {
  phase12_release_write_text(
    jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "string", digits = 17),
    path
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Scrape rendered competition pages | Use page bootstrap metadata plus structured backing payloads or embedded JSON, and retain exact bytes locally | Current official UEFA page architecture observed on 2026-08-13 | Captures the actual machine-readable contract and reduces breakage from layout-only changes. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/][CITED: https://www.uefa.com/uefanationsleague/match/2048003--netherlands-vs-germany/]` |
| Treat fallback as per-row patching | Treat fallback as a reviewed edition-wide replacement bundle | Locked in Phase 13 context on 2026-08-13 | Prevents silent provenance mixing and keeps bundle lineage auditable. `[VERIFIED: 13-CONTEXT.md]` |
| Leave pre-draw EURO unregistered | Register explicit `pre_draw` edition with source/output contract | Required by current official EURO status on 2026-08-13 | Preserves truthful state without inventing groups or null release slots. `[VERIFIED: 13-CONTEXT.md][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]` |

**Deprecated/outdated:**
- Parsing only visible page text for competition structure is outdated for the current UEFA pages inspected because the fixtures and standings pages are client shells with component bootstrap metadata rather than stable rendered tables. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The quickest Phase 13 focused test split will use two new files named `tests/testthat/test_phase13_source_contracts.R` and `tests/testthat/test_phase13_competition_registry.R`. `[ASSUMED]` | Validation Architecture | Low; filenames can change without changing the contract surface. |
| A2 | The per-task quick commands in Validation Architecture will point directly at those two new files with `testthat::test_file(...)`. `[ASSUMED]` | Validation Architecture | Low; the planner can swap in a different focused command shape. |

## Open Questions (RESOLVED)

1. **Nations League structured response paths:** Phase 13 does not freeze undocumented UEFA endpoint path strings as a long-lived API contract. The bounded acquisition task derives the structured service URLs from official page bootstrap metadata or accepts explicitly operator-supplied structured URLs, captures one fixtures payload and one standings payload, records the resolved URLs in `source_artifacts`, and freezes schema assertions from compact fixtures. A missing, changed, HTML, or schema-incompatible response fails closed and leaves the prior accepted bundle active. This resolves the path uncertainty without building a broad scraper. `[VERIFIED: 13-CONTEXT.md][VERIFIED: 13-02-PLAN.md][CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/uefanationsleague/standings/]`

2. **Competition status source:** `status` is a required normalized artifact class, but it does not require a separate undocumented network endpoint. The capture contract accepts status fields from an official structured edition-status response when discovered; otherwise it derives a structured status record only from status-bearing fields in the accepted official structured resource set, with `source_artifact_id` links to the exact contributing raw artifacts. EURO pre-draw status comes from the official structured pre-draw metadata fixture and is registered explicitly with no fabricated groups, fixtures, standings, or probabilities. Rendered prose and PDFs remain rejected. `[VERIFIED: 13-CONTEXT.md][VERIFIED: 13-02-PLAN.md][CITED: https://www.uefa.com/uefanationsleague/match/2048003--netherlands-vs-germany/][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]`

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `Rscript` | All contract builders and validators | ✓ | 4.6.1 `[VERIFIED: local probe]` | — |
| `git` | Parser identity (`git rev-parse HEAD`) and compact publication guardrails | ✓ | 2.55.0 `[VERIFIED: local probe]` | None for accepted-bundle parser identity. `[VERIFIED: 13-CONTEXT.md]` |
| `curl` | Source-surface probing and optional structured capture tooling | ✓ | 8.21.0 `[VERIFIED: local probe]` | Base R download helpers are possible, but `curl` is already present. `[VERIFIED: local probe]` |
| `digest` | SHA-256 row/file hashing | ✓ | 0.6.39 `[VERIFIED: local probe]` | None recommended; do not hand-roll. `[CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| `jsonlite` | Compact JSON manifests and parser fixtures | ✓ | 2.0.0 `[VERIFIED: local probe]` | None recommended; do not hand-roll. `[CITED: https://cran.r-project.org/web/packages/jsonlite/index.html]` |

**Missing dependencies with no fallback:**
- None for planning. `[VERIFIED: local probe]`

**Missing dependencies with fallback:**
- None identified. `[VERIFIED: local probe]`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 `[VERIFIED: local probe]` |
| Config file | none; source-style test loading in `tests/testthat/` `[VERIFIED: codebase grep]` |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` `[ASSUMED]` |
| Full suite command | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` `[VERIFIED: AGENTS.md]` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | Candidate bundle must require the five resource classes and reject incomplete/missing resource sets | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` `[ASSUMED]` | ❌ Wave 0 |
| DATA-02 | Every artifact row and bundle manifest must expose source URL, retrieval time, byte count, raw SHA-256, parser commit SHA, and fallback status | unit | same as above `[ASSUMED]` | ❌ Wave 0 |
| DATA-03 | Normalized outputs must preserve source display name, stable `team_id`, and edition ID; ambiguous mapping must fail or warn visibly | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` `[ASSUMED]` | ❌ Wave 0 |
| DATA-04 | Manual fallback must require source, retrieval date, reason, operator note, checksum, and explicit review state; mixed official/fallback bundles must fail | unit | same as above `[ASSUMED]` | ❌ Wave 0 |
| COMP-01 | Registry rows must enforce forward lifecycle, blocked overlay, pinned model release, explicit source bundle, and explicit EURO pre-draw output target | unit/integration | same as above `[ASSUMED]` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` `[ASSUMED]`
- **Per wave merge (superseded for this Phase 13 plan set):** Use the task-level focused commands; the prior repository-wide `testthat::test_dir("tests/testthat")` wording is retained as historical research context only and is not an intermediate wave gate. `[SUPERSEDED: 13-VALIDATION.md]`
- **Authoritative Wave 10 phase gate:** Only after Plan 13-06 in Wave 10, run the full suite, deterministic replay of one official candidate and one reviewed fallback candidate, and the final human backstop before `$gsd-verify-work`. `[VERIFIED: 13-VALIDATION.md][VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`

### Wave 0 Gaps
- [ ] `tests/testthat/test_phase13_source_contracts.R` — bundle/artifact schema, hash, required-resource, and mixed-fallback rejection checks. `[VERIFIED: codebase grep]`
- [ ] `tests/testthat/test_phase13_competition_registry.R` — lifecycle transitions, blocked overlay, explicit pre-draw EURO row, and pinned model-release invariants. `[VERIFIED: 13-CONTEXT.md]`
- [ ] `tests/fixtures/phase13/` committed compact structured fixtures — one Nations League official sample, one EURO pre-draw metadata sample, one reviewed fallback sample. `[CITED: https://www.uefa.com/uefanationsleague/fixtures-results/][CITED: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/]`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface is introduced in this phase. `[VERIFIED: codebase grep]` |
| V3 Session Management | no | No session surface is introduced in this phase. `[VERIFIED: codebase grep]` |
| V4 Access Control | yes | Trusted project-relative roots and path containment checks modeled on existing registry/release helpers. `[VERIFIED: codebase grep]` |
| V5 Input Validation | yes | Required-column validators, enum validators, explicit ambiguity rejection, and schema checks on every candidate bundle. `[VERIFIED: codebase grep][VERIFIED: 13-CONTEXT.md]` |
| V6 Cryptography | yes | Use `digest` SHA-256 only; never hand-roll hashing or checksum logic. `[CITED: https://cran.r-project.org/web/packages/digest/index.html]` |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Candidate bundle path escapes trusted root | Tampering / Information Disclosure | Normalize paths, reject `..`, and enforce approved project-relative roots before acceptance or publication. `[VERIFIED: codebase grep]` |
| Raw artifact or manifest tampering after capture | Tampering / Repudiation | Record byte count and SHA-256 for every raw artifact plus accepted manifest self-hash, then verify before promotion. `[VERIFIED: codebase grep][CITED: https://cran.r-project.org/web/packages/digest/index.html]` |
| Silent ambiguous identity mapping | Spoofing / Integrity | Fail ambiguous mappings and make normalized-display fallback visible in committed metadata. `[VERIFIED: 13-CONTEXT.md]` |
| Unreviewed manual fallback entering publication | Tampering | Require explicit review state and reject mixed bundles or missing fallback audit fields. `[VERIFIED: 13-CONTEXT.md]` |
| Schema drift causing partial publication | Denial of Service / Integrity | Validate required artifact set and reject candidate bundles while retaining the last accepted bundle. `[VERIFIED: 13-CONTEXT.md]` |

## Sources

### Primary (HIGH confidence)
- Local repository patterns: `R/benchmark/registry.R`, `R/benchmark/contracts.R`, `R/release/release_contract.R`, `R/release/release_bundle.R`, `R/elo/preprocess.R`, `R/evaluation/worldcup_ledger.R`, `scripts/update_worldcup_dashboard.R`, and `scripts/auto_update_worldcup_dashboard.sh`. `[VERIFIED: codebase grep]`
- `AGENTS.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, and `.planning/phases/13-source-contracts-and-competition-registry/13-CONTEXT.md`. `[VERIFIED: codebase grep]`
- Local runtime probes for `Rscript`, `git`, `curl`, `digest`, `jsonlite`, `testthat`, and `targets`. `[VERIFIED: local probe]`

### Secondary (MEDIUM confidence)
- UEFA Nations League fixtures page source: https://www.uefa.com/uefanationsleague/fixtures-results/
- UEFA Nations League standings page source: https://www.uefa.com/uefanationsleague/standings/
- UEFA Nations League match page source: https://www.uefa.com/uefanationsleague/match/2048003--netherlands-vs-germany/
- UEFA EURO 2028 draw announcement: https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/
- UEFA EURO 2028 qualification system announcement: https://www.uefa.com/news-media/news/0299-1dcf36ade17c-099c9d4b7d85-1000--uefa-uefaeuro2028-qualification-system-approved/
- UEFA EURO 2028 about page: https://www.uefa.com/euro2028/about/
- CRAN `digest`: https://cran.r-project.org/web/packages/digest/index.html
- CRAN `jsonlite`: https://cran.r-project.org/web/packages/jsonlite/index.html
- CRAN `jsonlite` reference manual: https://cran.r-project.org/web/packages/jsonlite/jsonlite.pdf

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing local packages and runtime versions are directly observable, and the relevant CRAN docs are current official sources. `[VERIFIED: local probe][CITED: https://cran.r-project.org/web/packages/digest/index.html][CITED: https://cran.r-project.org/web/packages/jsonlite/index.html]`
- Architecture: MEDIUM - the internal contract pattern is clear, but the exact undocumented UEFA service response paths still need one bounded capture task before implementation locks schema details. `[VERIFIED: codebase grep][CITED: https://www.uefa.com/uefanationsleague/fixtures-results/]`
- Pitfalls: HIGH - the main failure modes are directly implied by locked decisions and strongly reinforced by existing repo publication/validation patterns. `[VERIFIED: 13-CONTEXT.md][VERIFIED: codebase grep]`

**Research date:** 2026-08-13
**Valid until:** 2026-08-20
