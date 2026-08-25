# Phase 17: Shared Dashboards and Atomic Refresh Operations - Pattern Map

**Mapped:** 2026-08-25
**Files analyzed:** 10 proposed/modified files
**Analogs found:** 10 / 10 (role-match analogs; no exact Phase 17 implementation exists)

The phase has no `17-CONTEXT.md`. The locked scope below comes from `17-RESEARCH.md`, the supplied requirements, and the repository state: one edition-neutral dashboard contract, separate Nations League/EURO adapters and routes, truthful EURO `pre_draw`, one staged batch envelope, fail-closed validation, launchd scheduling, and post-validation Git publication.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/dashboard/payload_contract.R` | utility / contract | transform, request-response | `R/competition/publication_hashes.R` and `R/competition/publication_manifests.R` | role-match |
| `R/dashboard/payload_nations_league.R` | adapter / service | file-I/O, transform | `R/competition/uefa_nations_league_outcomes.R` | role-match |
| `R/dashboard/payload_euro.R` | adapter / service | file-I/O, transform | `scripts/build_euro_qualifying_outcomes.R` | role-match |
| `R/dashboard/renderer.R` | component / renderer | transform, file-I/O | `R/visualization/worldcup_dashboard.R` | role-match |
| `R/dashboard/publication.R` | service / transaction | file-I/O, request-response | `R/competition/publication_transaction.R` | role-match |
| `scripts/refresh_competition_dashboards.R` | CLI / orchestrator | batch, file-I/O, request-response | `scripts/update_worldcup_dashboard.R` and `scripts/build_euro_qualifying_outcomes.R` | role-match |
| `scripts/com.xgelo.competition-dashboards.plist` | config | scheduled request-response | `scripts/com.xgelo.dashboard-update.plist` | role-match |
| `tests/testthat/test_phase17_dashboards.R` | test | transform, file-I/O, request-response | `tests/testthat/test_phase13_publication_transaction.R`, `test_phase13_publication_integration.R`, `test_phase16_euro_qualifying.R` | role-match |
| `docs/competitions/nations-league/index.html` | generated component | file-I/O / static response | `docs/wc2026/index.html` and `publish_worldcup_dashboard_pages()` | role-match |
| `docs/competitions/euro-qualifying/index.html` | generated component | file-I/O / static response | `docs/wc2026/index.html` and `publish_worldcup_dashboard_pages()` | role-match |

The exact output route names remain a planning decision; preserve the shared renderer and separate edition directories even if the final public paths differ.

## Pattern Assignments

### `R/dashboard/payload_contract.R` (utility / contract, transform)

**Analog:** `R/competition/publication_hashes.R` (lines 8-29, 64-155) and `R/competition/publication_manifests.R` (lines 98-170).

Use explicit registered dimensions and strict scalar/path/schema validation. The existing publication layer rejects duplicate or missing edition/resource keys and resolves paths inside trusted roots; the dashboard contract should apply the same discipline to section IDs, lifecycle statuses, metadata, and filter dimensions.

**Registry and scalar pattern** (`R/competition/publication_hashes.R:8-29`):

```r
phase13_publication_editions <- function() {
  c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
}

phase13_publication_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 publication ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) stop("... must not be empty", call. = FALSE)
  value
}
```

**Exact-graph validation** (`R/competition/publication_hashes.R:64-155`): require both registered editions, reject duplicate keys, validate safe paths, and fail on missing required files. Copy this for `phase17_dashboard_sections()`, lifecycle enums (`available`, `pre_draw`, `unavailable`, `unresolved`, `suppressed`, `blocked`), and the neutral schema version `phase17-dashboard-v1`.

**Payload serialization pattern** (`17-RESEARCH.md:281-292`, based on `R/visualization/worldcup_dashboard.R:3445-3447`): serialize with pinned `pretty = TRUE`, `auto_unbox = TRUE`, `digits = 10`; validate JSON after writing; hash exact bytes for replay/publication identity.

### `R/dashboard/payload_nations_league.R` (adapter / service, file-I/O + transform)

**Analog:** `R/competition/uefa_nations_league_outcomes.R` (lines 19-121, 576-620, 1060-1133, 1222-1280).

Read the accepted state/outcomes bundle through its validators, preserve the exact nine-file outcomes inventory, and map accepted fields into the neutral sections. Do not let the adapter recalculate rules or simulation values.

**Manifest/inventory pattern:** the research identifies the canonical NL files as topology, slots, projected standings/rankings, transition outcomes, team paths, fixture forecast/form, simulation metadata, and outcomes manifest (`R/competition/uefa_nations_league_outcomes.R:19-121`). Treat missing or extra files as a contract error before payload construction.

**Forecast/form boundary:** use `fixture_forecast_form.csv` as the canonical fixture forecast/form join (`R/competition/uefa_nations_league_outcomes.R:87-100`, `1070-1133`). Carry model/release lineage, feature/model cutoffs, competition and international form, source bundle, parent state hashes, and parent forecast hashes into rows or metadata.

**Manifest lineage:** copy, do not invent, source bundle ID/hash, model release and release-manifest hash, model/calibrator hashes, cutoffs, ruleset/draw policy, seed/count, projection run, warnings, failure reason, generated time, and self-hash (`R/competition/uefa_nations_league_outcomes.R:102-121`, `1222-1280`). Reject conflicting multi-row metadata rather than blindly selecting row one.

### `R/dashboard/payload_euro.R` (adapter / service, file-I/O + transform)

**Analog:** `scripts/build_euro_qualifying_outcomes.R` (lines 429-481, 512-543, 777-807, 813-930).

Reuse the Phase 16 loader/validator shape: read the accepted manifest and status, derive lifecycle and forecast status, attach source/model lineage, and preserve explicit suppression. The adapter must represent `pre_draw` as an intentional typed state with schema-valid empty sections, never as a failed parse or inferred active competition.

**Typed status pattern** (`scripts/build_euro_qualifying_outcomes.R:429-481`): the loader derives `lifecycle_state`, `activation_status`, `forecast_status`, `source_confidence`, and manifest lineage from accepted files. Carry those values into `metadata` and each affected section's `{status, reason, rows}` object.

**Candidate suppression pattern** (`scripts/build_euro_qualifying_outcomes.R:813-930`): validate the exact nine-file EURO sibling inventory; refresh manifest warnings/failure reason; suppress structural/probability rows for `pre_draw`, `unavailable`, `unresolved`, `unsupported_topology`, or `revision_blocked`; retain control metadata. The renderer should show the status and reason, not fabricate groups, fixtures, standings, or probabilities.

### `R/dashboard/renderer.R` (component / renderer, transform + file-I/O)

**Analog:** `R/visualization/worldcup_dashboard.R` (lines 3445-3518, 3955-4012, 4559-4580, 4583-4605).

Keep the renderer pure with respect to competition logic: accept one normalized payload and edition configuration, emit deterministic static HTML, and never open competition CSVs. Edition differences belong in adapters and labels/status data.

**HTML/payload injection** (`R/visualization/worldcup_dashboard.R:3464-3518`): build a single template, inject serialized JSON into `<script id="dashboard-data" type="application/json">`, then parse it client-side. Preserve escaping (`esc()`), stable DOM IDs, native buttons/tables/details, and responsive CSS patterns from the existing template.

**Filter and status interaction** (`R/visualization/worldcup_dashboard.R:3955-4012`, `4559-4577`): centralize filter predicates, split completed/upcoming rows, render a stable empty result, wire tab/filter events, and render once after binding listeners. Generalize dimensions to section, league/group, team, matchday, and fixture status; add a concise live status region for result counts.

**Render wrapper** (`R/visualization/worldcup_dashboard.R:4583-4605`): read the staged JSON, call the template, create only the destination directory, and write the HTML. Add metadata/warnings/credits disclosures and typed unavailable/pre-draw sections while retaining the existing compact static-site layout.

### `R/dashboard/publication.R` (service / transaction, file-I/O + request-response)

**Analog:** `R/competition/publication_transaction.R` (lines 1-8, 38-73, 141-223, 264-307, 311-320) and its tests in `tests/testthat/test_phase13_publication_transaction.R:145-191`.

Treat the complete batch as the transaction envelope: both payloads, both HTML routes, batch manifest, hashes, and compact sidecars are staged under one same-filesystem root. Keep `refresh_batches` history outside the trusted replacement scope.

**Trusted-root and scope pattern** (`R/competition/publication_transaction.R:38-59`): validate sibling roots, reject symlinks/overlap, reject `refresh_batches`, and keep all targets within declared roots. Define an exact Phase 17 inventory rather than discovering files dynamically.

**Byte snapshot/hash pattern** (`R/competition/publication_transaction.R:141-223`): read raw bytes, compute SHA-256 with `digest`, record existence/byte count/hash, and restore missing/changed/new targets exactly on failure. Reuse this for incumbent batch snapshots and post-promotion read-back.

**Promotion/rollback pattern** (`R/competition/publication_transaction.R:264-307`): promote in deterministic order with same-filesystem `file.rename()`, retain backup, inject/test failures after each promotion boundary, clean only owned stage/backup/lock artifacts, and restore the incumbent on any error. Prefer one final `current` pointer/root swap so the public site cannot observe mixed editions.

### `scripts/refresh_competition_dashboards.R` (CLI / orchestrator, batch + file-I/O)

**Analogs:** `scripts/update_worldcup_dashboard.R:1-78,318-427`, `scripts/build_euro_qualifying_outcomes.R:1-104`, and `scripts/auto_update_worldcup_dashboard.sh:41-56,94-145`.

Use a repository-root-aware Rscript entry point with explicit environment/config parsing, bounded `--dry-run`, ordered gates, nonzero failure status, and no domain logic in the plist.

**Input/config parsing:** copy `read_env_int()`, `read_env_flag()`, and `read_env_path()` from `scripts/update_worldcup_dashboard.R:5-27`; reject invalid values rather than silently coercing them. Source dependencies using absolute project-root paths, as the EURO CLI does (`scripts/build_euro_qualifying_outcomes.R:14-30,90-104`).

**Gate order:** preflight clean/upstream/environment; acquire/validate both edition bundles; build state/outcomes; verify source/rules/probability/freshness/replay/browser/regression gates; normalize payloads; render both routes; validate exact inventory/hashes/sizes; promote/read back; only then perform compact Git commit/push.

**Git preflight pattern** (`scripts/auto_update_worldcup_dashboard.sh:41-56`): reject tracked/staged changes, fetch upstream when configured, compare local and upstream heads, and fail closed on divergence. Move `git add`/commit/push after all publication gates and restrict paths to approved code/manifests/dashboard-ready payloads.

### `scripts/com.xgelo.competition-dashboards.plist` (config, scheduled request-response)

**Analog:** `scripts/com.xgelo.dashboard-update.plist:5-29`.

Retain the declarative launchd shape: stable `Label`, absolute `WorkingDirectory`, hourly `StartInterval` 3600, `RunAtLoad` if desired, and explicit stdout/stderr paths. Replace the shell wrapper with an absolute `Rscript` executable plus `scripts/refresh_competition_dashboards.R` in `ProgramArguments`, or use an absolute wrapper if the final plan needs shell-level environment setup. Do not rely on interactive shell PATH.

```xml
<key>WorkingDirectory</key>
<string>/Users/davidzenz/R/xGelo</string>
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/Rscript</string>
  <string>/Users/davidzenz/R/xGelo/scripts/refresh_competition_dashboards.R</string>
</array>
<key>StartInterval</key><integer>3600</integer>
<key>StandardOutPath</key><string>/Users/davidzenz/R/xGelo/logs/competition-dashboard-update.out</string>
<key>StandardErrorPath</key><string>/Users/davidzenz/R/xGelo/logs/competition-dashboard-update.err</string>
```

Validate with `plutil -lint`, and test that the plist points to exactly one bounded batch entry point.

### `tests/testthat/test_phase17_dashboards.R` (test, transform + file-I/O + request-response)

**Analogs:** `tests/testthat/test_phase13_publication_transaction.R:3-15,52-115,117-191`, `tests/testthat/test_phase13_publication_integration.R:7-49,126-220`, `tests/testthat/test_phase16_euro_qualifying.R:1534-1677,2402-2427`, and `tests/testthat/test_worldcup_dashboard.R:1-50`.

Use repository-root-aware loaders, temporary fixture sandboxes, raw-byte snapshots, and `testthat` focused descriptions. Keep deterministic NL and EURO fixture bundles small and synthetic; do not use live sources in unit tests.

**Sandbox/snapshot pattern** (`test_phase13_publication_integration.R:24-49`): recursively copy fixtures into a `tempfile()` root, snapshot every file as raw bytes plus SHA-256, and compare relative-path inventories after each operation.

**Rollback/failure injection** (`test_phase13_publication_transaction.R:145-191`): inject failures after every ordered promotion, assert the incumbent `exists`, hashes, and bytes are identical, and assert unrelated files/history survive.

**Replay pattern** (`test_phase16_euro_qualifying.R:1642-1651,2402-2427`): compare in-process repeated/reordered inputs and invoke a fresh `Rscript` child process; raise/assert a typed replay mismatch when lineage changes.

Cover SIM-03 lineage/replay, neutral schema and shared renderer identity, all required sections/filter dimensions, truthful EURO `pre_draw`, metadata/warnings/credits, plist lint, atomic batch promotion, each fail-closed gate, size/inventory/hash rejection, rollback, and dirty/diverged Git preflight.

### `docs/competitions/nations-league/index.html` and `docs/competitions/euro-qualifying/index.html` (generated components, static response)

**Analog:** `docs/wc2026/index.html` and `publish_worldcup_dashboard_pages()` (`R/visualization/worldcup_dashboard.R:4594-4605`).

These should be generated outputs, not hand-authored renderer logic. Preserve the existing static shell conventions: compact tabs/toolbars/tables, bounded table overflow, responsive media rules, native `<details>` disclosures, and injected dashboard JSON. Both files must be emitted by the same renderer from separate edition payloads and promoted together inside the batch envelope.

The EURO route must retain the stable section layout while showing typed `pre_draw`/unavailable messages and no guessed rows. The NL route should render populated structure, standings, fixtures/results, form, forecasts, and projected outcomes from its adapter.

## Shared Patterns

### Provenance and lineage

**Sources:** `R/competition/uefa_nations_league_outcomes.R:102-121,1222-1280`; `scripts/build_euro_qualifying_outcomes.R:512-543,652-690`.

Expose batch ID, source confidence and bundle/hash, retrieval/refresh and generated timestamps, model release/manifest/model/calibrator hashes, model and feature cutoffs, ruleset/draw-policy version/hash, simulation seed/count, projection run, output/replay hashes, warnings, and credits. Copy from validated manifests; never recompute display lineage from partial rows.

### Truthful unavailable states

**Sources:** `scripts/build_euro_qualifying_outcomes.R:813-930`; Phase 16 replay/suppression tests.

Every section has a typed status and human-readable reason. `pre_draw` is distinct from empty filter results; accepted incumbent content remains visible when a refresh is blocked; suppressed probabilities never render as zeros or fabricated values.

### Exact inventory and hashes

**Sources:** `R/competition/publication_hashes.R:97-155`; `R/competition/publication_transaction.R:155-223`.

Declare the target graph, reject extras/missing/duplicate paths, hash exact bytes, enforce compact artifact size limits, and verify hashes after promotion. Keep accepted source refresh history separate from the dashboard transaction.

### Static renderer ergonomics

**Sources:** `R/visualization/worldcup_dashboard.R:3502-3518,3955-4012,4559-4577`; `docs/wc2026/index.html`.

Use native controls, visible focus, stable section headings, responsive bounded tables, text equivalents for status/probability indicators, and collapsed lineage/credits disclosures. The browser owns filtering only; it must not resolve competition rules or source validity.

## No Exact Analog

No existing file implements the Phase 17 combination of two edition-neutral payloads, one public batch envelope, and post-promotion Git gating. The planner should combine the role-match patterns above rather than extending `worldcup_dashboard.R` into a second competition-specific branch.

## Metadata

**Analog search scope:** `R/visualization`, `R/competition`, `scripts`, `tests/testthat`, `docs/wc2026`, and Phase 13-16 planning artifacts.
**Files scanned:** 10 primary analogs plus supporting manifest/outcome modules.
**Pattern extraction date:** 2026-08-25
