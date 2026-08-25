# Phase 17: Shared Dashboards and Atomic Refresh Operations - Research

**Researched:** 2026-08-25
**Domain:** R static dashboard rendering, UEFA competition output contracts, macOS launchd operations, atomic filesystem publication
**Confidence:** HIGH for repository architecture and publication contracts; MEDIUM for external R/browser guidance; LOW only where the future public-site hosting path is not present in the checkout

## User Constraints

No Phase 17 CONTEXT.md exists. The following constraints are locked by the project instructions and current milestone decisions:

- Reuse one shared static dashboard engine while keeping Nations League and EURO competition state, rules, and outputs separate. [VERIFIED: repository, `.planning/STATE.md:54-58`]
- Treat official UEFA competition data as the authority and support audited manual fallbacks instead of silent overrides. [VERIFIED: repository, `.planning/STATE.md:54-65`]
- Keep EURO 2028 qualifying in an explicit `pre_draw` state until an official UEFA draw snapshot exists after the 6 December 2026 draw. [VERIFIED: repository, `.planning/STATE.md:54-58`]
- Publish both competition bundles atomically as one hourly batch or not at all. [VERIFIED: repository, `.planning/STATE.md:54-58`]
- Keep Git publication compact by limiting committed outputs to code, manifests, and dashboard-ready payloads. [VERIFIED: repository, `.planning/STATE.md:54-58`]
- Automatic bookmaker, FotMob, or Transfermarkt scraping, paid data as a required dependency, a live event tracker, a server-backed public API, invented EURO qualifying groups, and large raw response or score-distribution artifacts in Git are out of scope. [VERIFIED: repository, `.planning/REQUIREMENTS.md:66-76`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SIM-03 | Every simulation records deterministic seeds, ruleset hashes, source bundle identity, model release identity, and replayable run metadata. | Consume and expose the existing `simulation_metadata.csv` and outcomes manifest lineage; add cross-edition payload and replay checks. |
| DASH-01 | Dedicated Nations League and EURO qualifying entry points use one shared rendering and payload engine. | Use edition adapters plus one normalized dashboard payload schema and renderer, with separate route/output directories. |
| DASH-02 | Dashboards show structure, groups/leagues, standings, fixtures, results, forecasts, form, and projected outcomes. | Map Phase 14 state artifacts and Phase 15/16 outcome artifacts into explicit payload sections; preserve empty/unavailable sections. |
| DASH-03 | Users filter by competition section, league/group, team, matchday, and fixture status in responsive desktop/mobile views. | Reuse the existing World Cup dashboard's client-side section/filter approach, generalized to typed competition dimensions. |
| DASH-04 | Dashboards show refresh status, source confidence, model release, warnings, and collapsed data credits without operational detail dominating. | Build a compact metadata/control panel from accepted manifests and status rows; keep warnings visible but secondary. |
| OPS-01 | macOS launchd refreshes both competition bundles hourly using the reproducible update pattern. | Extend `scripts/com.xgelo.dashboard-update.plist` and the existing update script pattern, with explicit working directory, absolute executables, logs, and a single batch entry point. |
| OPS-02 | Candidate snapshots/outputs are staged and validated before both dashboards atomically publish as one coherent batch. | Reuse Phase 13 lock/staging/backup/rename mechanics, but make the public bundle the transaction envelope for both editions and both dashboard routes. |
| OPS-03 | Refresh runs source, rules, probability, freshness, replay, browser smoke, and regression tests before publication. | Add a fail-closed validation runner with fast contract gates, subprocess replay, browser capability detection, and downstream regression commands. |
| OPS-04 | Compact changed code/manifests/outputs commit and push only from clean, upstream-aligned worktree. | Preserve the existing preflight in `scripts/auto_update_worldcup_dashboard.sh`; move commit/push after the complete publication and artifact-size gate. |
| OPS-05 | Refresh fails closed on incomplete sources, dirty/diverged repos, failed tests, invalid hashes, partial bundles, or oversized artifacts. | Use explicit preflight predicates, exact inventories, hash validation, same-filesystem promotion, rollback, and no-publication-on-error tests. |

## Summary

Phase 17 should be planned as a consumer-and-operations layer over the accepted competition artifacts, not as a second state or simulation implementation. The Nations League output is a populated edition bundle; the EURO output is currently truthful `pre_draw` control output with intentionally empty structural/projection tables. Both already carry edition, source, rules, model, cutoff, simulation, and hash lineage. [VERIFIED: repository, `R/competition/uefa_nations_league_outcomes.R:576-620`, `R/competition/uefa_nations_league_outcomes.R:860-1005`, `scripts/build_euro_qualifying_outcomes.R:813-930`]

The dashboard boundary should therefore normalize each edition into one dashboard-ready payload contract containing `metadata`, `sections`, `structure`, `standings`, `fixtures`, `results`, `forecasts`, `form`, `projected_outcomes`, and `credits`. The renderer owns presentation and interaction only. Edition adapters own file inventory, schema validation, status mapping, and field selection. This preserves the locked separation between competition rules/state and shared presentation. [VERIFIED: repository, `.planning/STATE.md:54-58`; [CITED: jsonlite manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html)]

Publication must be a transaction over a complete refresh envelope. A filesystem rename is atomic for one directory entry, but renaming several edition and route directories independently is not one multi-file atomic operation. Stage the entire candidate tree on the same filesystem, validate it, retain an incumbent backup, promote the envelope with one final public pointer/directory replacement, read back and validate, and restore the incumbent on any post-promotion failure. [CITED: POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html)

**Primary recommendation:** create one `phase17` batch CLI that loads validated Phase 15/16 bundles, produces two normalized payloads with shared renderer output, runs all gates in a temporary same-filesystem staging root, and promotes one public batch directory only after every gate passes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Edition bundle loading and exact inventory validation | Database / Storage | API / Backend | The accepted state/outcome roots and manifests are the trust boundary; consumers must not infer validity from display files. |
| Simulation lineage and replay metadata | API / Backend | Database / Storage | Seeds, ruleset hashes, source bundle identity, model release, and output hashes are producer contracts consumed by dashboards and gates. |
| Dashboard payload normalization | API / Backend | Database / Storage | Edition-specific schemas differ; normalize once before presentation so the renderer has no competition-specific file logic. |
| Static HTML rendering and filters | Browser / Client | CDN / Static | The project is static-site based; filtering and responsive layout happen in the generated HTML/JavaScript. |
| Refresh/status/warning presentation | Browser / Client | API / Backend | The browser displays accepted metadata; the batch creates the metadata and must never expose unaccepted candidates. |
| Candidate staging, validation, promotion, rollback | API / Backend | Database / Storage | A single batch coordinator owns cross-edition coherence, locks, exact inventories, and incumbent retention. |
| Hourly scheduling and logs | Frontend Server (SSR) | API / Backend | `launchd` invokes the batch entry point and captures logs; it must not contain domain logic. |
| Commit/push preflight | API / Backend | CDN / Static | Git state is an operational publication gate after content validation, not a dashboard data source. |

## Repository Findings and Existing Contracts

### Existing dashboard pattern

- The existing renderer is `R/visualization/worldcup_dashboard.R`. `build_worldcup_dashboard_data()` builds one JSON payload and writes CSV sidecars; `render_worldcup_dashboard()` injects JSON into a static HTML template; `publish_worldcup_dashboard()` writes the Pages copy. [VERIFIED: repository, `R/visualization/worldcup_dashboard.R:3145-3461`, `R/visualization/worldcup_dashboard.R:3464-3469`, `R/visualization/worldcup_dashboard.R:4586-4610`]
- The current client already has section tabs, team/search filters, group filtering, completed/upcoming match splitting, and responsive CSS. Generalize those mechanisms rather than creating a second UI architecture. [VERIFIED: repository, `R/visualization/worldcup_dashboard.R:3500-3514`, `R/visualization/worldcup_dashboard.R:3955-4010`, `R/visualization/worldcup_dashboard.R:4560-4580`]
- The current World Cup payload is too domain-specific to become the Phase 17 contract directly: it names World Cup groups/bracket fields and embeds renderer assumptions. Phase 17 should introduce an edition-neutral envelope and keep World Cup compatibility separate unless the plan explicitly broadens it. [VERIFIED: repository, `R/visualization/worldcup_dashboard.R:3391-3443`]
- `scripts/update_worldcup_dashboard.R` sources dashboard code, validates required local paths, builds output, and optionally syncs current outputs and Pages files. Its path-copy behavior is file-by-file and is not sufficient as the cross-edition atomic publication boundary. [VERIFIED: repository, `scripts/update_worldcup_dashboard.R:29-72`, `scripts/update_worldcup_dashboard.R:318-427`]

### Existing competition contracts

- Nations League outcomes have an exact nine-file inventory including topology, slots, projected standings/rankings, transition outcomes, team paths, fixture forecast/form, simulation metadata, and manifest. [VERIFIED: repository, `R/competition/uefa_nations_league_outcomes.R:19-121`]
- EURO outcomes have an exact nine-file sibling inventory with `qualification_ledger.csv` in place of Nations League transition outcomes, and blocked/pre-draw candidates suppress structural/probability rows while retaining control metadata. [VERIFIED: repository, `scripts/build_euro_qualifying_outcomes.R:813-930`; `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-05-SUMMARY.md`]
- The outcomes manifests already carry source bundle, source hash, model release, release manifest/selector, model and calibrator hashes, model cutoff, feature cutoff, ruleset, draw policy, seed, count, projection run, warnings, failure reason, generated time, and manifest self-hash. [VERIFIED: repository, `R/competition/uefa_nations_league_outcomes.R:112-121`, `R/competition/uefa_nations_league_outcomes.R:1222-1280`]
- `fixture_forecast_form.csv` is the canonical forecast/form join boundary for the outcomes bundle and carries calibrated probability view, model/release lineage, model/feature cutoffs, competition form, all-international form, source bundle, parent state hashes, and parent forecast hashes. [VERIFIED: repository, `R/competition/uefa_nations_league_outcomes.R:87-100`, `R/competition/uefa_nations_league_outcomes.R:1070-1133`]
- Phase 16 explicitly requires active EURO simulation to receive a validated active envelope and suppresses probabilities when activation or handoff evidence is absent. The dashboard must display that status, not manufacture empty-looking active projections. [VERIFIED: repository, `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-06-SUMMARY.md`]

### Existing publication transaction

- `R/competition/publication_transaction.R` creates a publication lock, same-root staging and backup roots, snapshots existing targets, promotes staged targets with `file.rename()`, and restores the snapshot on failure. [VERIFIED: repository, `R/competition/publication_transaction.R:136-225`, `R/competition/publication_transaction.R:264-306`]
- The Phase 13 transaction intentionally excludes `refresh_batches` from the trusted accepted-root replacement scope. Refresh history is a separate audit boundary and must not be overwritten by a dashboard publication transaction. [VERIFIED: repository, `R/competition/publication_transaction.R:38-57`, `.planning/STATE.md:139-148`]
- Phase 16 adds incumbent-safe rollback after post-promotion read-back validation. Phase 17 should reuse the pattern at a higher envelope level rather than bypassing it with direct copies. [VERIFIED: repository, `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-06-SUMMARY.md`]

## Standard Stack

### Core

| Library/tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| R | 4.6.1 installed | Payload adapters, validation, batch CLI, rendering orchestration | Project primary language and current runtime on this machine. [VERIFIED: local command, `Rscript --version`] |
| `jsonlite` | 2.0.0 installed | Dashboard payload serialization and parsing | Already used by the renderer and `_targets.R`; official manual documents `read_json()`, `write_json()`, `validate()`, `auto_unbox`, and `digits`. [VERIFIED: local package query; [CITED: jsonlite manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html)] |
| `digest` | 0.6.39 installed | SHA-256 content and replay fingerprints | Already used by publication/outcome contracts. [VERIFIED: local package query; repository grep in `R/competition`] |
| `testthat` | 3.3.2 installed | Contract, failure-injection, subprocess, and regression tests | Existing test framework with Phase 13–16 focused suites. [VERIFIED: local package query; repository tests] |
| macOS `launchd` / `launchctl` | system tool | Hourly user-agent scheduling and logs | Existing plist and update pattern; Apple documents LaunchAgents, calendar intervals, working directory, and stdout/stderr paths. [VERIFIED: local `launchctl`; [CITED: Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatinglaunchdJobs.html)] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `git` | installed | Clean/upstream-aligned preflight and compact commit/push | Only after all candidate and publication gates pass. [VERIFIED: local command; `scripts/auto_update_worldcup_dashboard.sh:41-56`] |
| `/usr/bin/safaridriver` | not probed as available in this session | Browser smoke on macOS without adding a Node dependency | Use only if enabled and available; Apple documents `safaridriver --enable` and W3C WebDriver testing. [CITED: Apple Safari WebDriver](https://developer.apple.com/documentation/webkit/testing-with-webdriver-in-safari) |
| Playwright | not installed | Optional deterministic browser smoke and screenshot/ARIA snapshots | Do not install implicitly. If selected, gate installation and browser binaries explicitly; Playwright documents web-first assertions and screenshot snapshots. [CITED: Playwright assertions](https://playwright.dev/docs/test-assertions), [CITED: Playwright screenshots](https://playwright.dev/docs/next/test-snapshots) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared static HTML renderer with local payloads | Shiny/server-backed dashboard | Violates the static public-site and no-server constraint; adds runtime/service availability. [VERIFIED: repository, `.planning/REQUIREMENTS.md:72-76`] |
| One staged public batch directory | File-by-file copy into two live routes | Allows mixed revisions if interrupted; cannot satisfy OPS-02/OPS-05. [INFERRED from POSIX rename semantics and repository copy code; [CITED: POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html)] |
| Existing `testthat` plus subprocess checks | New JavaScript test framework | Adds package/runtime/browser provenance and splits validation ownership; only choose if browser automation is explicitly accepted. [VERIFIED: repository test layout; [CITED: testthat `test_file()`](https://testthat.r-lib.org/reference/test_file.html)] |

**Installation:** No new package installation is required by the recommended baseline. Existing R packages are reused. Browser automation is an environment-gated optional dependency, not an assumed install.

## Architecture Patterns

### System Architecture Diagram

```text
launchd hourly Agent
        |
        v
phase17_refresh CLI
  |-- clean/upstream/size/environment preflight
  |-- acquire candidate source snapshots or reviewed fallbacks
  |-- build/validate NL state + outcomes ----\
  |-- build/validate EURO state + outcomes ---+--> staging batch root
  |-- deterministic replay + freshness gates /
  |-- normalize edition bundles -> shared dashboard payloads
  |-- render NL route + EURO route from same renderer
  |-- exact inventory/hash/browser/regression gates
        |
        +-- any failure --> retain incumbent public batch, record blocked result, exit nonzero
        |
        +-- all pass --> same-filesystem promote one public batch pointer/directory
                           -> read back both routes and manifests
                           -> compact commit/push (only if still clean/upstream-aligned)
```

### Recommended Project Structure

```text
R/dashboard/
├── payload_contract.R       # edition-neutral schema and status mapping
├── payload_nations_league.R # adapter over validated NL state/outcomes
├── payload_euro.R            # adapter over validated EURO state/outcomes
├── renderer.R                # one HTML/CSS/JS template and interaction model
└── publication.R             # dashboard envelope staging, hashes, read-back
scripts/
└── refresh_competition_dashboards.R # one batch CLI and validation orchestration
tests/testthat/
└── test_phase17_dashboards.R         # payload, renderer, publication, replay, failure tests
docs/competitions/
├── nations-league/index.html
└── euro-qualifying/index.html
```

The exact paths are recommendations; preserve established `R/competition` and `scripts/` ownership if the implementation discovers a better local location. The important boundaries are adapter, contract, renderer, transaction, and orchestration. [ASSUMED]

### Pattern 1: Adapter-to-neutral-payload

**What:** Each edition reader first validates its registered state/outcomes bundle, then maps only accepted fields into a common payload schema. The renderer receives one payload shape and an edition label; it never opens CSVs, resolves rules, or decides whether `pre_draw` is active. [VERIFIED: repository contracts; recommended architecture]

**When to use:** Always for the two Phase 17 dashboards. Add fields to the neutral contract only when both the field meaning and unavailable-state semantics are defined.

**Example:**

```r
build_dashboard_payload <- function(edition_bundle, edition_id) {
  validate_registered_bundle(edition_bundle)
  list(
    schema_version = "phase17-dashboard-v1",
    metadata = build_dashboard_metadata(edition_bundle, edition_id),
    sections = list(
      structure = adapt_structure(edition_bundle),
      standings = adapt_standings(edition_bundle),
      fixtures = adapt_fixtures(edition_bundle),
      results = adapt_results(edition_bundle),
      forecasts = adapt_forecasts(edition_bundle),
      form = adapt_form(edition_bundle),
      projected_outcomes = adapt_outcomes(edition_bundle)
    )
  )
}
```

The field names above are a planning contract, not a claim that these functions already exist. [ASSUMED]

### Pattern 2: Proof-carrying dashboard metadata

**What:** Copy lineage values into the payload metadata from validated manifests rather than recomputing or accepting free-text values. At minimum include `batch_id`, `generated_at_utc`, `last_refresh_at_utc`, `source_confidence`, `source_bundle_id`, `source_bundle_sha256`, `model_release_id`, `release_manifest_sha256`, `ruleset_version`, `ruleset_sha256`, `simulation_seed`, `simulation_count`, `projection_run_id`, `warnings`, `forecast_status`, and `credits`.

**Why:** The existing outcomes contracts already provide these fields, and the dashboard must make them inspectable without promoting operational detail above the content. [VERIFIED: repository, `R/competition/uefa_nations_league_outcomes.R:102-121`, `scripts/build_euro_qualifying_outcomes.R:826-846`]

### Pattern 3: Explicit unavailable and empty states

**What:** Keep `pre_draw`, `unavailable`, `unresolved`, `unsupported_topology`, and `revision_blocked` as typed state values. Render a section-level status and reason; do not render fabricated groups, fixtures, probabilities, or projections. Empty tables are valid only when the bundle status and reason explain them. [VERIFIED: repository, `.planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-05-SUMMARY.md`, `16-06-SUMMARY.md`]

### Pattern 4: Pure renderer plus deterministic payload bytes

**What:** Serialize each payload with pinned `jsonlite` options, write to staging, hash the exact bytes, and render the same payload into HTML. Avoid embedding volatile local absolute paths or current time in client-visible fields except the explicit generated/refresh timestamps. `jsonlite` supports `write_json()` and `validate()`; `auto_unbox` and numeric `digits` alter the contract and must be deliberate. [CITED: jsonlite manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html)

### Pattern 5: Batch envelope promotion

**What:** Stage both payloads, both HTML routes, manifests, and a batch manifest under one root. Validate exact inventory and hashes, then promote the root or a single stable `current` pointer using same-filesystem rename. Keep the prior root until read-back validation succeeds. POSIX `rename()` is atomic for the directory-entry operation; this makes the final pointer swap atomic, not the internal construction of the candidate. [CITED: POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html)

### Pattern 6: Reproducible launchd entry point

**What:** Keep the plist declarative and the batch logic in a repository script. Use an absolute `ProgramArguments` executable, `WorkingDirectory`, `StartCalendarInterval` or `StartInterval`, `StandardOutPath`, `StandardErrorPath`, and an explicit environment/PATH strategy. Apple documents user LaunchAgents, periodic keys, working directory, and stdout/stderr paths. [CITED: Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatinglaunchdJobs.html)

### Anti-Patterns to Avoid

- **Edition-specific renderer branches:** They make DASH-01 false in practice and cause schema drift. Keep edition differences in adapters and status-aware data, not duplicated HTML templates. [VERIFIED: project decision in `.planning/STATE.md:54-58`]
- **Reading accepted CSVs after publication one file at a time:** A user can observe mixed revisions. Read from a batch root or stable pointer and validate a batch manifest before serving. [INFERRED; [CITED: POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html)]
- **Using `generated_at` as source freshness:** Generation time does not prove source retrieval time. Display both `last_refresh_at_utc`/source retrieval and `generated_at_utc`. [VERIFIED: repository, source and outcomes metadata fields]
- **Treating empty EURO tables as missing data:** `pre_draw` is an intentional truthful state. Render the control message and reason instead. [VERIFIED: Phase 16 summaries and tests]
- **Committing before validation:** A failed or oversized candidate must remain unpublished and uncommitted. [VERIFIED: OPS requirements and existing auto-update preflight]
- **Relying on launchd's environment implicitly:** launchd jobs do not inherit an interactive shell setup reliably; use absolute paths and explicit working directory/PATH. [CITED: Apple launchd guide]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Competition validity | A dashboard-side CSV heuristic or inferred status | Phase 14 state readers and Phase 15/16 outcome validators | Existing contracts enforce exact schema, edition identity, hashes, activation, and suppression. [VERIFIED: repository] |
| Hashing and lineage | Ad hoc hashes of selected display fields | Existing `publication_hashes`, outcome manifest helpers, and complete artifact hashes | Partial hashes can miss parent/source changes and break replay evidence. [VERIFIED: repository, `R/competition/publication_hashes.R`, outcome modules] |
| Atomic publication | A sequence of `file.copy()` calls into live routes | Existing lock/stage/backup/rename transaction, extended to one dashboard batch envelope | Copies can leave partial or mixed public state. [VERIFIED: repository; [CITED: POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html)] |
| JSON serialization | Manual string concatenation or custom escaping | `jsonlite::write_json()` with a pinned schema/options and `jsonlite::validate()` | JSON scalar/array, NA, Date, and numeric precision behavior have edge cases. [CITED: jsonlite manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html) |
| Browser waiting/screenshot comparison | Sleeps and pixel checks with no browser state assertions | Playwright web-first assertions or Safari WebDriver if explicitly provisioned | Browser assertions should wait on page state; screenshot baselines are environment-sensitive. [CITED: Playwright assertions](https://playwright.dev/docs/test-assertions), [CITED: Playwright screenshots](https://playwright.dev/docs/next/test-snapshots) |
| Scheduling | New cron loop or a long-running watcher as the production scheduler | Existing macOS `launchd` user agent | Apple recommends launchd for timed jobs and documents sleep/wake behavior. [CITED: Apple scheduled jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html) |

**Key insight:** Phase 17's hard problems are trust-boundary composition and multi-root publication, not HTML generation. Existing validators and manifests should remain the authority; new code should adapt and transact them.

## Common Pitfalls

### Pitfall 1: Payload contract silently drops provenance

**What goes wrong:** The page looks correct but cannot explain which source bundle, model release, ruleset, or simulation produced it.
**Why it happens:** Adapters select only display columns and ignore manifest/simulation metadata.
**How to avoid:** Make metadata required by the neutral payload schema and assert non-empty hashes/IDs for accepted states; allow explicit empty values only for documented unavailable fields.
**Warning signs:** HTML has a refresh time but no source bundle hash, ruleset hash, seed, or model release.
[VERIFIED: repository contracts; requirement SIM-03/DASH-04]

### Pitfall 2: EURO `pre_draw` appears as a broken dashboard

**What goes wrong:** Empty groups or probabilities are presented as loading/error, or fabricated structures are added to make the page look populated.
**Why it happens:** The renderer assumes every competition has the same active structures.
**How to avoid:** Render typed lifecycle/status banners and section-level unavailable states. Test the current pre-draw bundle and a future active-after-draw fixture separately.
**Warning signs:** Non-empty EURO groups before an official draw, probabilities with no accepted fixture bundle, or no visible reason for empty tables.
[VERIFIED: Phase 16 activation/output contracts]

### Pitfall 3: Mixed-edition or mixed-revision public content

**What goes wrong:** Nations League HTML updates while EURO HTML remains incumbent, or HTML and JSON disagree.
**Why it happens:** Existing file-by-file sync functions are reused as the final publication mechanism.
**How to avoid:** Stage all routes and payloads under one batch root, validate a cross-edition batch manifest, and swap one public pointer/root.
**Warning signs:** Different `batch_id` values in the two pages, different generated timestamps, or a manifest parent hash that does not match the payload bytes.
[INFERRED from repository transaction and POSIX rename semantics]

### Pitfall 4: Freshness is measured from the wrong clock

**What goes wrong:** A newly generated page claims fresh data even though the source snapshot is stale, or a source retrieval time is mistaken for publication time.

**How to avoid:** Carry separate `source_retrieved_at_utc`, `last_refresh_at_utc`, `generated_at_utc`, and optional freshness age/status. Gate configured freshness thresholds before publication and render the warning if an audited fallback is used.

### Pitfall 5: Determinism depends on process order or worker count

**What goes wrong:** Replay hashes differ between normal, reversed, repeated, or fresh-process runs.

**How to avoid:** Reuse existing seed/RNG contracts, canonicalize input ordering before simulation/payload construction, compare complete artifact bytes/hashes, and test both in-process and child-process replay. Existing Phase 16 tests already use this shape. [VERIFIED: `tests/testthat/test_phase16_euro_qualifying.R:1534-1676`, `2402-2426`]

### Pitfall 6: launchd works manually but fails hourly

**What goes wrong:** The job cannot find R, the repository root, environment variables, or writable logs under launchd.

**How to avoid:** Use absolute paths, `WorkingDirectory`, explicit log paths, a wrapper that records start/end/exit status, and a local `launchctl` load/bootstrap/status smoke test. Apple documents these plist fields and the sleep/wake behavior. [CITED: Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatinglaunchdJobs.html)

### Pitfall 7: Browser gate is required but no browser exists

**What goes wrong:** OPS-03 is declared green while only HTML text checks ran, or an unapproved package install happens during the hourly job.

**How to avoid:** Make browser capability an explicit preflight. If the project requires browser smoke for publication, missing Safari WebDriver/Playwright must block publication; if the plan permits a development fallback, separate static contract checks from manual browser verification and record the downgraded gate.

## Code Examples

### Shared payload serialization

```r
write_dashboard_payload <- function(payload, path) {
  stopifnot(identical(payload$schema_version, "phase17-dashboard-v1"))
  jsonlite::write_json(
    payload,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    digits = 10
  )
  jsonlite::validate(paste(readLines(path, warn = FALSE), collapse = "\n"))
  invisible(path)
}
```

This follows the existing renderer's `write_json(..., pretty = TRUE, auto_unbox = TRUE, digits = 10)` shape; the plan should add schema and byte/hash assertions around it. [VERIFIED: repository, `R/visualization/worldcup_dashboard.R:3445-3447`; [CITED: jsonlite manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html)]

### Typed metadata mapping

```r
dashboard_metadata <- list(
  batch_id = batch_id,
  generated_at_utc = manifest$generated_at_utc[[1L]],
  last_refresh_at_utc = source$retrieved_at_utc[[1L]],
  source_confidence = source$source_confidence[[1L]],
  source_bundle_id = manifest$source_bundle_id[[1L]],
  source_bundle_sha256 = manifest$source_bundle_sha256[[1L]],
  model_release_id = manifest$model_release_id[[1L]],
  ruleset_version = manifest$ruleset_version[[1L]],
  ruleset_sha256 = manifest$ruleset_sha256[[1L]],
  simulation_seed = manifest$simulation_seed[[1L]],
  simulation_count = manifest$simulation_count[[1L]],
  projection_run_id = manifest$projection_run_id[[1L]],
  warnings = manifest$warnings[[1L]]
)
```

The exact implementation should use the project's scalar/typed helper functions and reject conflicting rows rather than blindly taking row one. The field set is derived from existing manifest schemas. [VERIFIED: repository, outcome manifest schemas]

### launchd shape

```xml
<key>Label</key>
<string>com.xgelo.competition-dashboards</string>
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/Rscript</string>
  <string>/Users/davidzenz/R/xGelo/scripts/refresh_competition_dashboards.R</string>
</array>
<key>WorkingDirectory</key>
<string>/Users/davidzenz/R/xGelo</string>
<key>StartInterval</key>
<integer>3600</integer>
<key>StandardOutPath</key>
<string>/Users/davidzenz/R/xGelo/logs/competition-dashboard-update.out</string>
<key>StandardErrorPath</key>
<string>/Users/davidzenz/R/xGelo/logs/competition-dashboard-update.err</string>
```

Use the repository's actual Rscript path discovered at installation time, and decide whether `StartInterval=3600` or a calendar-aligned `StartCalendarInterval` better matches the existing operational pattern. Apple documents both periodic forms and log paths. [CITED: Apple launchd guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatinglaunchdJobs.html)

### Focused test command shape

```bash
Rscript --vanilla -e \
  'testthat::test_file("tests/testthat/test_phase17_dashboards.R", stop_on_failure = TRUE, reporter = "summary")'
```

Use exact `desc=` selection where supported by installed testthat for fast loops, then run the complete file for the gate. `testthat::test_file()` is the official single-file entry point. [CITED: testthat `test_file()`](https://testthat.r-lib.org/reference/test_file.html)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| World Cup-only renderer with local file sync | One edition-neutral payload contract and shared renderer | Phase 17 target; current repository has only the former. [VERIFIED: repository] | Enables two routes without duplicating competition logic. |
| Direct live-directory file copies | Candidate batch, exact validation, one public promotion, read-back/rollback | Phase 13–16 established transaction pieces; Phase 17 composes them. [VERIFIED: repository] | Prevents partial or mixed revisions. |
| Single generated timestamp | Separate source retrieval/freshness, generated time, and provenance hashes | Phase 13–16 source/outcome contracts | Users can distinguish stale inputs from recent publication. |
| Implicit manual browser inspection | Explicit browser capability gate plus DOM/ARIA/screenshot assertions where provisioned | Current browser testing practice; Playwright and Safari WebDriver docs | Prevents OPS-03 from passing on an untested browser surface. |

**Deprecated/outdated:** cron is supported by macOS but Apple identifies launchd as the preferred timed-job mechanism; do not add a cron scheduler. [CITED: Apple scheduled jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html)

## Recommended Plan Task Boundaries

1. **Contract and adapters:** Define the neutral payload schema, metadata/freshness/status semantics, exact field mappings, and fixture-backed readers for both edition bundles. Cover SIM-03 and the data half of DASH-01/02/04.
2. **Shared renderer and entry points:** Generalize the existing static renderer into one implementation, add competition route configuration, responsive filters, empty/pre-draw/blocked states, and collapsed credits. Cover DASH-01 through DASH-04.
3. **Batch envelope and atomic publication:** Create staging layout, batch manifest, exact inventory/hash checks, incumbent retention, pointer/root promotion, read-back, rollback, and oversized artifact gate. Cover OPS-02 and OPS-05.
4. **Refresh orchestration and launchd:** Wire source acquisition, state/outcome builders, payload/render stages, validation ordering, logs, lock collision behavior, exit statuses, and plist installation/status commands. Cover OPS-01, OPS-03, OPS-05.
5. **Git publication gate:** Reuse clean/upstream-aligned checks, restrict staged paths to compact artifacts, commit only after promotion, push only after commit and final status checks, and test dirty/diverged/push-failure paths. Cover OPS-04/05.
6. **Regression/browser verification:** Add fast R contract tests, fresh-process replay tests, failure injection at each promotion boundary, fixture-based browser smoke, responsive desktop/mobile checks, and a documented missing-browser disposition. Cover all requirements as the phase gate.

Keep the renderer and transaction tasks separate: the renderer can be verified from staged fixtures, while the transaction must prove that renderer failures leave the incumbent public batch byte-identical.

## Runtime State Inventory

This is a new shared dashboard/operations phase, not a rename/refactor phase. No rename-triggered runtime state migration is required. Existing runtime state that must be respected by the plan:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Accepted competition roots, output state/outcomes, and separate `refresh_batches` history. [VERIFIED: repository] | Read through registered validators; do not rewrite refresh history as part of dashboard promotion. |
| Live service config | No active xGelo launch agent was listed by `launchctl` in this session. [VERIFIED: local command] | Plan install/bootstrap and post-install status verification; do not assume the plist is loaded. |
| OS-registered state | No active xGelo dashboard launch agent found. [VERIFIED: local command] | Register the Phase 17 plist under the logged-in user's `~/Library/LaunchAgents`. |
| Secrets/env vars | No Phase 17 secret dependency identified; existing scripts use `XGELO_*` environment variables for local tuning. [VERIFIED: repository grep] | Keep operational parameters explicit and non-secret; avoid putting mutable paths only in launchd's implicit environment. |
| Build artifacts / installed packages | Existing static World Cup outputs and competition bundles are present; no browser runner is installed. [VERIFIED: filesystem/tool probes] | Treat generated outputs as candidates; add an explicit browser availability gate. |

## Common Data Contract Requirements

The planner should lock these fields before implementation:

| Contract | Required fields/behavior |
|----------|--------------------------|
| Batch identity | One `batch_id`, generated time, candidate/publication status, and cross-edition parent hashes. |
| Source confidence | Official/fallback status, source bundle ID/hash, source URLs/artifact IDs, retrieval time, fallback reason/operator note where applicable. |
| Freshness | Source retrieval time, derived last-refresh time, freshness age/status, configured threshold result, and warning text. |
| Model | Approved release ID, release manifest/selector hash, model/calibrator hash, model data cutoff, feature cutoff, probability view. |
| Simulation | Seed, count, projection run ID, ruleset version/hash, draw-policy ID/hash, output hash, replay verification status. |
| Lifecycle | `pre_draw`, `scheduled`, `active`, `unavailable`, `unresolved`, `unsupported_topology`, `revision_blocked` as typed values; no implicit fallback to active. |
| UI sections | Stable section IDs, display labels, row arrays, filter dimensions, availability/status, and reason/warning fields. |
| Credits | Collapsed data-credit block containing source names/URLs/licenses and manual fallback attribution without raw response bodies. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Rscript | Batch, tests, renderer | Yes | R 4.6.1 | None needed. |
| `jsonlite` | Payload JSON | Yes | 2.0.0 | None; existing renderer already depends on it. |
| `digest` | SHA-256 | Yes | 0.6.39 | None; existing publication code uses it. |
| `testthat` | Contract/regression tests | Yes | 3.3.2 | None; existing suite uses it. |
| `launchctl` | OPS-01 install/status checks | Yes | macOS system tool | Manual plist inspection only, insufficient for final operational sign-off. |
| Safari WebDriver / `safaridriver` | Browser smoke | Not confirmed in this session | — | Probe `/usr/bin/safaridriver`; if absent/disabled, install/enable or block publication according to the locked plan decision. |
| Playwright/Chromium | Optional browser smoke | No (`playwright`, `chromium`, `google-chrome` not found) | — | Safari WebDriver or manual browser verification; do not silently install. |
| `curl` | Source capture/update paths | Yes | Homebrew curl | Existing source acquisition path. |

**Missing dependencies with no fallback:** None for R-side contract and publication work. Browser automation is a publication blocker if OPS-03 requires automated browser smoke and neither Safari WebDriver nor an approved browser runner is provisioned.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `testthat` 3.3.2 [VERIFIED: local package query] |
| Config file | None detected; existing tests are direct `tests/testthat/test_*.R` files. [VERIFIED: filesystem scan] |
| Quick run command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase17_dashboards.R", desc="phase17_smoke", stop_on_failure=TRUE, reporter="summary")'` |
| Full phase command | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase17_dashboards.R", stop_on_failure=TRUE, reporter="summary")'` |
| Existing regression commands | Phase 13 publication/integration, Phase 14 state/forecast, Phase 15 Nations League, and Phase 16 EURO focused files. [VERIFIED: prior phase summaries and test files] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SIM-03 | Both payloads expose seed/rules/source/model/projection lineage and same-run replay hashes. | integration/replay | `test_file(..., desc="simulation lineage")` plus fresh `Rscript` child replay | ❌ Wave 0 |
| DASH-01 | Two entry points use the same renderer and schema version. | unit/integration | `test_file(..., desc="shared renderer")` | ❌ Wave 0 |
| DASH-02 | Required sections exist; pre-draw/blocked sections are typed and truthful. | contract | `test_file(..., desc="payload sections")` | ❌ Wave 0 |
| DASH-03 | Section, league/group, team, matchday, status filters work at desktop/mobile viewport fixtures. | browser smoke | Safari WebDriver/Playwright command, or explicit blocked/manual gate | ❌ Wave 0 |
| DASH-04 | Metadata, warning, confidence, release, refresh, and collapsed credits render without operational panel dominance. | DOM/ARIA + snapshot | browser command plus payload assertions | ❌ Wave 0 |
| OPS-01 | launchd plist parses, points to the batch CLI, logs, and runs one bounded refresh. | shell/integration | `plutil -lint scripts/com.xgelo.competition-dashboards.plist` and bounded CLI smoke | ❌ Wave 0 |
| OPS-02 | Candidate staging contains both editions/routes before one promotion; no mixed batch. | integration/failure injection | `test_file(..., desc="atomic batch")` | ❌ Wave 0 |
| OPS-03 | Source/rules/probability/freshness/replay/browser/regression gates run in order and block publication on failure. | orchestration | bounded batch command with injected gate failures | ❌ Wave 0 |
| OPS-04 | Dirty/diverged repository blocks; compact approved paths commit/push only after validation. | shell/integration | sandbox git repository fixture | ❌ Wave 0 |
| OPS-05 | Invalid hashes, incomplete bundles, partial outputs, oversized files, and rollback retain incumbent bytes. | failure injection | `test_file(..., desc="fail closed")` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** quick payload/schema contract command under 30 seconds.
- **Per wave merge:** full Phase 17 test file plus relevant Phase 13–16 focused regressions.
- **Phase gate:** full Phase 17 suite, fresh-process replay, launchd/plist lint, bounded browser smoke on an available browser, and complete pre-publication batch dry run before `$gsd-verify-work`.

### Wave 0 Gaps

- [ ] `tests/testthat/test_phase17_dashboards.R` with repository-root-aware loaders and deterministic NL/EURO fixture bundles.
- [ ] Neutral payload schema validator and exact expected section/filter dimensions.
- [ ] Batch envelope fixture with incumbent/candidate trees and byte snapshot helper.
- [ ] Failure injectors for source, rules, probability, freshness, replay, browser, manifest/hash, promotion, read-back, and git preflight gates.
- [ ] Browser smoke harness or explicit Safari WebDriver provisioning decision; no browser runner exists in the current environment.
- [ ] Plist lint/status helper and bounded `--dry-run` refresh command.

`testthat` snapshot testing can be useful for stable metadata/ARIA or HTML fragments, but volatile timestamps and hashes must be transformed or asserted structurally. The testthat documentation notes that snapshots capture output/messages/errors and must be reviewed when changed. [CITED: testthat snapshots](https://testthat.r-lib.org/reference/expect_snapshot.html)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No for the public static site; yes for any local operator/push credential boundary | Keep operator credentials outside payloads and launchd plist; use existing Git/OS controls. [ASSUMED for public scope] |
| V3 Session Management | No for static public pages | No browser session or server cookie should be introduced. [VERIFIED: out-of-scope server-backed API] |
| V4 Access Control | Yes for local publication and Git push | Require clean/upstream-aligned repo, explicit operator identity, locked staging root, and no untrusted candidate promotion. [VERIFIED: OPS-04/05 and existing script] |
| V5 Input Validation | Yes | Validate source bundles, exact schemas/inventories, lifecycle/status enums, URLs/paths, hashes, sizes, and payload JSON before rendering. [VERIFIED: existing validators] |
| V6 Cryptography | Yes | Use existing SHA-256 helpers/manifests; do not hand-roll hashing or treat an unverified hash as proof. [VERIFIED: publication/outcome modules] |

### Known Threat Patterns for R/static publication

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Forged or mixed source lineage | Spoofing/Tampering | Registered bundle identity, exact source/artifact hashes, one edition-scoped provenance bundle, and manifest validation. |
| Partial public promotion | Tampering/Denial of service | Same-filesystem staging, lock, incumbent backup, one public swap, read-back, rollback. |
| Candidate data leakage | Information disclosure | Candidate roots remain outside public path until all gates pass; blocked/pre-draw outputs expose only typed control metadata. |
| Replay repudiation | Repudiation | Persist seed/count/run ID, source/rules/model lineage, output hashes, and fresh-process replay evidence. |
| Path traversal or arbitrary output writes | Tampering | Restrict output roots to project/public batch roots and reuse existing path-within-root checks. |
| Oversized generated artifacts | Availability | Exact file inventory, per-file and total size limits, compact-output allowlist, and fail closed before Git mutation. |
| Launchd environment/path confusion | Tampering/Availability | Absolute executable paths, explicit working directory, logs, bounded arguments, and plist lint/status checks. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended new modules can live under `R/dashboard/` and `scripts/refresh_competition_dashboards.R`; exact file placement is left to planning. | Recommended Project Structure | Low; implementation can use existing module locations if boundaries remain intact. |
| A2 | A stable public batch root or single `current` pointer can be introduced without violating the existing static hosting layout. | Pattern 5 / task boundaries | Medium; route layout and Pages deployment behavior must be confirmed before locking paths. |
| A3 | Automated browser smoke is a hard OPS-03 publication gate rather than a post-publication/manual check. | Environment/validation | High; allowing a manual fallback changes operational guarantees. User/planner should lock this explicitly. |
| A4 | Public dashboard content requires no authentication/session management. | Security Domain | Medium; adding an operator UI or protected admin route would change ASVS scope. |
| A5 | The current installed R package versions are the versions used by the launchd environment. | Standard Stack | Medium; launchd may resolve a different R/library path unless the plist pins it. |

## Open Questions

1. **What exact static public directory layout should Phase 17 promote?**
   - What we know: current World Cup uses `docs/wc2026/index.html`; competition bundles live under `outputs/competition/...`. [VERIFIED: repository]
   - What's unclear: whether Pages expects `docs/nations-league/`, `docs/euro-qualifying/`, or a generated site root with a selector.
   - Recommendation: lock route paths and whether the stable pointer is a directory or batch manifest before the renderer/publication plan.

2. **Is browser automation mandatory in the production refresh?**
   - What we know: OPS-03 names browser smoke; no Playwright/Chromium was found, while Safari WebDriver is a possible macOS-native route. [VERIFIED: local probes; [CITED: Apple Safari WebDriver](https://developer.apple.com/documentation/webkit/testing-with-webdriver-in-safari)]
   - What's unclear: whether the machine is permitted to enable Safari WebDriver or install Playwright/browser binaries.
   - Recommendation: make missing browser capability a named fail-closed condition unless the user explicitly accepts a manual release gate.

3. **Should the public payload include all fixture/form rows or only dashboard-ready compact projections?**
   - What we know: requirements require fixtures, results, forecasts, and form; out-of-scope rules prohibit large raw/score-distribution artifacts in Git. [VERIFIED: requirements]
   - What's unclear: the exact compact column subset and total artifact size budget.
   - Recommendation: define a field allowlist and byte budget in the batch manifest; never serialize raw RDS or raw source responses into the public bundle.

4. **How should hourly acquisition interact with a blocked edition?**
   - What we know: Phase 13/16 retain incumbents and expose blocked/revision warnings rather than silently replacing valid data. [VERIFIED: prior phase summaries]
   - What's unclear: whether a blocked candidate for one edition should leave the entire prior cross-edition batch visible or publish a new batch containing incumbent content plus a blocked warning.
   - Recommendation: preserve the last coherent public batch by default; record the blocked candidate in refresh history and publish only if the cross-edition batch policy explicitly allows incumbent-plus-warning composition.

## Sources

### Primary (HIGH confidence)

- Repository requirements/state/roadmap and Phase 13–16 artifacts: project-specific contracts, locked decisions, output schemas, transaction behavior, and prior validation evidence.
- [Apple: Creating launchd Jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatinglaunchdJobs.html) - LaunchAgent locations, plist fields, intervals, working directory, stdout/stderr paths.
- [Apple: Scheduling Timed Jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html) - launchd preference over cron and sleep/power behavior.
- [POSIX `rename()`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html) - atomic directory-entry rename semantics.

### Secondary (MEDIUM confidence)

- [jsonlite reference manual](https://jeroen.r-universe.dev/jsonlite/doc/manual.html) - JSON read/write/validation, scalar boxing, numeric serialization.
- [testthat `test_file()`](https://testthat.r-lib.org/reference/test_file.html) and [snapshot expectations](https://testthat.r-lib.org/reference/expect_snapshot.html) - focused test execution and reviewed snapshots.
- [Apple: Testing with WebDriver in Safari](https://developer.apple.com/documentation/webkit/testing-with-webdriver-in-safari) - macOS-native browser automation path.
- [Playwright assertions](https://playwright.dev/docs/test-assertions) and [visual comparisons](https://playwright.dev/docs/next/test-snapshots) - optional browser assertion/snapshot patterns.

### Tertiary (LOW confidence)

- None used for a locked implementation recommendation. The only unresolved low-confidence area is the future static hosting route, which requires project-owner confirmation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing runtime and packages were probed locally; no new package is required.
- Architecture: HIGH - directly grounded in existing Phase 13–16 manifests, validators, and transaction code.
- Pitfalls: HIGH for repository-specific failure modes; MEDIUM for browser/launchd operational details due to target-machine configuration.

**Research date:** 2026-08-25
**Valid until:** 2026-09-01 for launchd/browser/package details; stable repository findings remain valid until implementation changes the referenced contracts.
