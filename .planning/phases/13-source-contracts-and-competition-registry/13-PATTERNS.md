# Phase 13: Source Contracts and Competition Registry - Pattern Map

**Mapped:** 2026-08-13
**Files analyzed:** 13 grouped targets
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/competition/source_contracts.R` | utility | file-I/O | `R/release/release_bundle.R` | role-match |
| `R/competition/team_identity.R` | utility | transform | `R/elo/preprocess.R` | role-match |
| `R/competition/edition_registry.R` | store | CRUD | `R/benchmark/registry.R` | exact |
| `scripts/acquire_uefa_snapshot.R` | utility | file-I/O | `scripts/update_worldcup_dashboard.R` | role-match |
| `.gitignore` | config | file-I/O | `.gitignore` | exact |
| `data/competition/registries/source_bundles.csv` | store | CRUD | `R/release/release_bundle.R` | role-match |
| `data/competition/registries/source_artifacts.csv` | store | CRUD | `R/release/release_bundle.R` | role-match |
| `data/competition/registries/team_identity.csv` | store | CRUD | `data/benchmark/phase09/teams.csv` | exact |
| `data/competition/registries/competition_editions.csv` | store | CRUD | `data/benchmark/phase09/tournaments.csv` + `R/benchmark/registry.R` | role-match |
| `data/competition/accepted/<edition_id>/{source_bundle_manifest,fixtures,groups,standings,results,status}.csv` | store | transform | `R/visualization/worldcup_dashboard.R` | role-match |
| `tests/testthat/test_phase13_source_contracts.R` | test | file-I/O | `tests/testthat/test_phase12_release.R` + `tests/testthat/test_benchmark_contracts.R` | role-match |
| `tests/testthat/test_phase13_competition_registry.R` | test | CRUD | `tests/testthat/test_benchmark_registry.R` | exact |
| `tests/fixtures/phase13/{uefa_nations_league_sample,euro2028_predraw_sample,reviewed_fallback_bundle}.{json,csv}` | store | file-I/O | `data/raw/worldcup_2026_groups.csv` + `tests/testthat/test_worldcup_dashboard.R` | role-match |

## Pattern Assignments

### `R/competition/source_contracts.R` (utility, file-I/O)

**Primary analogs:** `R/release/release_bundle.R`, `R/release/release_contract.R`, `R/benchmark/registry.R`

**Path/root guard pattern** (`R/release/release_bundle.R:29-42`, `R/release/release_bundle.R:111-130`, `R/benchmark/registry.R:19-57`):
```r
phase12_release_resolve_path <- function(path, project_root = ".", must_work = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 12 release path must be one non-empty value", call. = FALSE)
  }
  root <- phase12_release_project_root(project_root)
  value <- if (grepl("^/", path)) path else file.path(root, path)
  normalizePath(value, winslash = "/", mustWork = must_work)
}

phase12_release_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) || grepl("^/", path) || grepl("(^|/)\\.\\.?(/|$)", path)) {
    stop("Phase 12 release artifact path is unsafe: ", path, call. = FALSE)
  }
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (identical(normalized, ".") || grepl("^/", normalized) || !identical(normalized, path)) {
    stop("Phase 12 release artifact path is not a trusted relative path: ", path, call. = FALSE)
  }
  path
}

validate_benchmark_registry_paths <- function(paths, project_root = ".") {
  project_root <- benchmark_find_project_root(project_root)
  approved_root <- normalizePath(file.path(project_root, "data/benchmark/phase09"), mustWork = FALSE)
  ...
  if (any(!vapply(resolved, benchmark_path_within, logical(1), root = approved_root))) {
    stop("Benchmark registry path must stay inside the registered project-relative root data/benchmark/phase09", call. = FALSE)
  }
}
```

**Atomic staged write pattern** (`R/release/release_bundle.R:69-101`):
```r
phase12_release_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 12 release CSV: ", path, call. = FALSE)
  invisible(path)
}
```

**Manifest row/build pattern** (`R/release/release_bundle.R:203-260`):
```r
phase12_release_artifact_rows <- function(staged_root, metadata) {
  paths <- phase12_release_required_artifacts()
  paths <- setdiff(paths, "release_manifest.csv")
  rows <- lapply(paths, function(relative_path) {
    path <- phase12_release_path_under_root(staged_root, relative_path, must_work = TRUE)
    row_count <- if (grepl("\\.csv$", relative_path)) nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)) else NA_integer_
    hash <- phase12_release_file_sha256(path)
    data.frame(
      schema_version = "phase12-release-manifest-v1",
      ...
      artifact = relative_path, relative_path = relative_path,
      artifact_role = if (grepl("^model/", relative_path)) "model" else if (grepl("^manifests/", relative_path)) "manifest" else if (grepl("^reports/", relative_path)) "report" else "contract",
      sha256 = hash, canonical_content_sha256 = hash,
      rows = as.character(row_count), bytes = as.character(file.info(path)$size),
      ...
    )
  })
  do.call(rbind, rows)
}
```

**Fail-closed validator pattern** (`R/release/release_bundle.R:333-431`, `R/release/release_contract.R:45-72`):
```r
if (anyDuplicated(manifest$artifact) || anyDuplicated(manifest$relative_path)) stop("Phase 12 release manifest contains duplicate artifacts or paths", call. = FALSE)
if (!identical(phase12_release_manifest_body_hash(manifest), tolower(as.character(manifest$manifest_self_sha256[manifest$artifact == "release_manifest.csv"])))) stop("Phase 12 release manifest self-hash mismatch", call. = FALSE)
...
if (relative_path != "release_manifest.csv") {
  if (!identical(tolower(as.character(row$sha256[[1L]])), phase12_release_file_sha256(path))) stop("Phase 12 release artifact hash mismatch: ", relative_path, call. = FALSE)
}

if (any(vapply(dirs, phase12_release_contract_is_symlink, logical(1)))) {
  stop("Phase 12 immediate-child release directory must not be a symlink", call. = FALSE)
}
```

**Phase 13 adaptation**
- Copy the staged-write and manifest pattern directly for `source_bundles.csv`, `source_artifacts.csv`, and per-edition accepted manifests.
- Copy the trusted-relative-path/root-containment checks directly for raw-byte stores and committed accepted outputs.
- Extend the validator with required resource classes `fixtures/groups/standings/results/status`, whole-bundle fallback exclusivity, parser Git SHA presence, and raw-byte SHA-256 checks.

---

### `R/competition/team_identity.R` (utility, transform)

**Primary analogs:** `R/elo/preprocess.R`, `R/visualization/worldcup_dashboard.R`, `R/benchmark/registry.R`

**Alias normalization pattern** (`R/elo/preprocess.R:22-57`):
```r
xgelo_score_fallback_aliases <- function(team_map_path = "data/raw/team_name_map.csv") {
  normalize <- function(x) {
    x <- trimws(as.character(x))
    x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
    tolower(x)
  }
  ...
  if ("alt_names" %in% names(team_map) && !is.na(team_map$alt_names[[i]]) && nzchar(team_map$alt_names[[i]])) {
    names_i <- c(names_i, strsplit(team_map$alt_names[[i]], "\\|")[[1]])
  }
  keys <- normalize(names_i[nzchar(names_i)])
  aliases[keys] <- canonical
}

xgelo_canonicalize_fallback_team <- function(team, aliases = character(0)) {
  ...
  key <- normalize(team)
  matched <- aliases[key]
  out <- ifelse(!is.na(matched), unname(matched), as.character(team))
  out[is.na(team)] <- NA_character_
  out
}
```

**Required-column gate before mapping** (`R/elo/preprocess.R:72-79`):
```r
required <- c("date", "home_team", "away_team", "home_score", "away_score")
missing_cols <- setdiff(required, names(fallback_results))
if (length(missing_cols) > 0) {
  stop(
    paste("Fallback results missing required columns:", paste(missing_cols, collapse = ", ")),
    call. = FALSE
  )
}
```

**Keep canonical and display values separate** (`R/visualization/worldcup_dashboard.R:69-120`):
```r
display_lookup <- setNames(groups$display_team, groups$team)
group_lookup <- setNames(groups$group, groups$team)
...
fixtures$home_display <- unname(display_lookup[fixtures$home_team])
fixtures$away_display <- unname(display_lookup[fixtures$away_team])
fixtures$home_group <- unname(group_lookup[fixtures$home_team])
fixtures$away_group <- unname(group_lookup[fixtures$away_team])
```

**Team registry schema pattern** (`R/benchmark/registry.R:195,213`; `data/benchmark/phase09/teams.csv:1`; `data/raw/team_name_map.csv:1`):
```text
schema_version,team_id,fifa_code,canonical_name,aliases,...,source_artifact_sha256,row_sha256
source_name,canonical_name,fifa_code,alt_names
```

**Phase 13 adaptation**
- Keep `team_id` stable and separate from UEFA display names.
- Reuse the alias normalization exactly; add explicit Phase 13 fields such as `uefa_source_team_id`, `uefa_display_name_current`, `normalized_alias`, `mapping_method`, `mapping_warning`, and `alias_review_state`.
- Unlike current Elo fallback behavior, unresolved or ambiguous matches must `stop()`; only a deterministic normalized-name exact match may survive, and it must emit a visible warning row.

---

### `R/competition/edition_registry.R` (store, CRUD)

**Primary analogs:** `R/benchmark/registry.R`, `R/release/release_contract.R`

**Registry schema + enum validation style** (`R/benchmark/registry.R:193-257`):
```r
benchmark_require_columns(t, c("schema_version", "edition_id", "competition_id", "edition_year", "played_year", "opener_date", "final_date", "format_id", "headline_weight", "expected_fixture_count", "source_url", "source_license", "source_sha256", "row_sha256"), "Tournament")
...
allowed_status <- c("completed", "resumed", "replayed", "awarded", "abandoned")
if (any(!f$status %in% allowed_status)) stop("Fixture registry contains invalid status values", call. = FALSE)
...
if (any(!f$edition_id %in% t$edition_id)) stop("Fixture registry contains unknown edition keys", call. = FALSE)
```

**Canonical row/table hash pattern** (`R/benchmark/registry.R:75-131`):
```r
benchmark_row_sha256 <- function(data, hash_col = "row_sha256") {
  ...
  digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
}

canonical_benchmark_sha256 <- function(data, key = NULL) {
  ...
  payload <- paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}
```

**Manifest/projection pattern** (`R/benchmark/registry.R:265-281`, `R/release/release_contract.R:280-296`):
```r
manifest <- do.call(rbind, lapply(names(keys), function(name) data.frame(
  artifact = paste0(name, ".csv"),
  rows = nrow(registries[[name]]),
  canonical_sha256 = canonical_benchmark_sha256(registries[[name]], keys[[name]]),
  schema_version = paste(sort(unique(registries[[name]]$schema_version)), collapse = "|"),
  sealed = TRUE,
  stringsAsFactors = FALSE
)))

phase12_release_metadata <- function(release = NULL, trusted_root = "outputs/releases") {
  ...
  list(
    release_id = as.character(contract$release_id), status = as.character(contract$status),
    selected_model_id = as.character(contract$selected_model_id),
    ...
  )
}
```

**Authority/fail-closed linkage pattern** (`R/release/release_contract.R:156-188`, `R/release/release_contract.R:192-220`):
```r
if (!identical(as.character(contract$status), status) || !identical(contract_selected, selected_id) || !identical(contract_incumbent, incumbent_id)) stop("Phase 12 release candidate identity disagrees with the model contract", call. = FALSE)
...
if (!exact_hash && !legacy_retained) stop("Phase 12 embedded promotion decision identity mismatch", call. = FALSE)
...
if (length(candidates) != 1L) stop("Phase 12 release resolution is ambiguous or missing", call. = FALSE)
```

**Phase 13 adaptation**
- Model `competition_editions.csv` like a checked registry, not an ad hoc config file.
- Enforce explicit `edition_id`, lifecycle state, blocked overlay, ruleset version, source bundle ID, model release ID, output bundle target, revision/audit fields, and row SHA columns.
- Use enum checks in the same style as Phase 09, but with Phase 13 lifecycle states: `pre_draw`, `scheduled`, `in_progress`, `complete`, plus explicit blocked metadata rather than a free-form state string.

---

### `scripts/acquire_uefa_snapshot.R` (utility, file-I/O)

**Primary analogs:** `scripts/update_worldcup_dashboard.R`, `scripts/auto_update_worldcup_dashboard.sh`

**Small script helper pattern** (`scripts/update_worldcup_dashboard.R:5-27`, `scripts/update_worldcup_dashboard.R:74-101`):
```r
read_env_int <- function(name, default) { ... }
read_env_flag <- function(name, default = FALSE) { ... }
read_env_path <- function(name, default) { ... }

require_paths <- function(paths, label) {
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop(
      sprintf(
        "Missing %s:\n%s\nRun the targets pipeline before publishing the dashboard.",
        label,
        paste(sprintf("- %s", missing_paths), collapse = "\n")
      ),
      call. = FALSE
    )
  }
}
```

**Main-entrypoint orchestration pattern** (`scripts/update_worldcup_dashboard.R:318-450`):
```r
main <- function() {
  source_dashboard_code()
  ...
  approved_release <- resolve_phase12_approved_release(release_root)
  ...
  require_paths(c(forecast_features_path, matches_path), "approved-release dashboard inputs")
  ...
  dashboard <- build_worldcup_dashboard(...)
  ...
  invisible(list(
    dashboard = dashboard,
    published_path = published_path,
    elapsed_seconds = elapsed
  ))
}

main()
```

**Fail-closed batch shell pattern** (`scripts/auto_update_worldcup_dashboard.sh:41-55`, `scripts/auto_update_worldcup_dashboard.sh:83-92`, `scripts/auto_update_worldcup_dashboard.sh:125-149`):
```bash
if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
  echo "Refusing to auto-update with existing tracked changes. Commit or stash them first." >&2
  exit 1
fi
...
if [[ "$AUTO_FORCE" != "true" ]] &&
  git diff --quiet --exit-code -- data/raw/martj42 &&
  [[ "$ELORATINGS_CHANGED" != "true" ]] &&
  [[ "$ESPN_CHANGED" != "true" ]]; then
  ...
  exit 0
fi
...
Rscript --vanilla scripts/update_worldcup_dashboard.R
Rscript --vanilla scripts/check_dashboard_result_freshness.R
Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'
```

**Phase 13 adaptation**
- Keep a single `main()` entrypoint with small env/path helpers.
- Fail closed on missing structured resources, dirty worktrees, or invalid candidate bundles.
- There is no exact in-repo HTTP acquisition analog yet; use the dashboard update script structure, not its dashboard-specific semantics.

---

### `data/competition/registries/source_bundles.csv` and `data/competition/registries/source_artifacts.csv` (store, CRUD)

**Primary analog:** `R/release/release_bundle.R`

**Artifact manifest column pattern** (`R/release/release_bundle.R:210-225`, `R/release/release_bundle.R:230-260`):
```r
data.frame(
  schema_version = "phase12-release-manifest-v1",
  release_id = metadata$release_id, status = metadata$status,
  ...
  artifact = relative_path, relative_path = relative_path,
  artifact_role = ...,
  sha256 = hash, canonical_content_sha256 = hash,
  rows = as.character(row_count), bytes = as.character(file.info(path)$size),
  ...
)
```

**Phase 13 adaptation**
- `source_bundles.csv` should look like a compact manifest table: one row per accepted or candidate bundle, keyed by `bundle_id`, carrying edition ID, bundle status, fallback status, parser Git SHA, acceptance/review state, and canonical hash fields.
- `source_artifacts.csv` should follow the same manifest discipline at artifact level: `artifact_id`, `bundle_id`, `artifact_type`, `source_url`, `retrieved_at_utc`, `bytes`, `raw_sha256`, `parser_commit_sha`, `fallback_status`, `review_state`, `relative_local_raw_path`, `row_sha256`.

---

### `data/competition/registries/team_identity.csv` and `data/competition/registries/competition_editions.csv` (store, CRUD)

**Primary analogs:** `data/benchmark/phase09/teams.csv`, `R/benchmark/registry.R`

**Team registry header shape** (`data/benchmark/phase09/teams.csv:1`):
```csv
schema_version,team_id,fifa_code,canonical_name,aliases,historical_entity_id,source_title,source_url,source_license,source_artifact_sha256,row_sha256
```

**Existing alias-map header** (`data/raw/team_name_map.csv:1`):
```csv
source_name,canonical_name,fifa_code,alt_names
```

**Tournament/registry validation style** (`R/benchmark/registry.R:193-199`, `R/benchmark/registry.R:213-257`):
```r
benchmark_require_columns(tm, c("schema_version", "team_id", "fifa_code", "canonical_name", "aliases", "source_url", "source_license", "source_artifact_sha256", "row_sha256"), "Team")
...
if (any(is.na(tm$fifa_code) | !nzchar(tm$fifa_code))) stop("Team registry contains missing FIFA codes", call. = FALSE)
```

**Phase 13 adaptation**
- `team_identity.csv` should extend the Phase 09 `teams.csv` discipline, not replace it: keep `team_id`, `fifa_code`, alias/history columns, then add UEFA-specific mapping and warning fields.
- `competition_editions.csv` should reuse the checked-registry style from `tournaments.csv`/`boundaries.csv`, with explicit internal edition IDs and lifecycle metadata instead of loose settings.

---

### `data/competition/accepted/<edition_id>/{source_bundle_manifest,fixtures,groups,standings,results,status}.csv` (store, transform)

**Primary analogs:** `R/visualization/worldcup_dashboard.R`, `R/release/release_bundle.R`

**Compact CSV validation pattern** (`R/visualization/worldcup_dashboard.R:10-24`, `R/visualization/worldcup_dashboard.R:32-120`):
```r
required_cols <- c("group", "position", "team", "display_team", "fifa_code")
missing_cols <- setdiff(required_cols, names(groups))
if (length(missing_cols) > 0) {
  stop(paste("World Cup groups missing required columns:", paste(missing_cols, collapse = ", ")))
}
...
required_cols <- c(
  "match_id", "group", "matchday", "home_team", "away_team",
  "date", "kickoff_local", "venue_name", "host_city", "host_country"
)
...
fixtures$home_display <- unname(display_lookup[fixtures$home_team])
fixtures$away_display <- unname(display_lookup[fixtures$away_team])
```

**Per-file manifest/hash pattern** (`R/release/release_bundle.R:203-260`):
```r
row_count <- if (grepl("\\.csv$", relative_path)) nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)) else NA_integer_
hash <- phase12_release_file_sha256(path)
```

**Phase 13 adaptation**
- Keep accepted outputs compact, CSV-first, and source-shaped.
- Preserve both canonical IDs and current UEFA display names on accepted rows.
- Use one edition-local manifest plus sibling compact CSVs; do not commit raw bytes.
- For EURO pre-draw, planner should still use the same accepted bundle layout, but keep non-published resource tables empty or explicitly status-scoped rather than inventing fixtures/groups.

---

### `tests/testthat/test_phase13_source_contracts.R` (test, file-I/O)

**Primary analogs:** `tests/testthat/test_phase12_release.R`, `tests/testthat/test_benchmark_contracts.R`, `tests/testthat/test_worldcup_dashboard.R`

**Small helper + API seam pattern** (`tests/testthat/test_phase12_release.R:32-42`, `tests/testthat/test_phase12_release.R:92-105`):
```r
phase12_release_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0("Wave 0 RED contract awaits Phase 12 ", owner, " API: ",
             paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
}
```

**Hash-refresh tamper test pattern** (`tests/testthat/test_phase12_release.R:124-156`, `tests/testthat/test_phase12_release.R:186-205`, `tests/testthat/test_phase12_release.R:282-306`):
```r
phase12_test_refresh_release_hashes <- function(release_root) {
  ...
  hash <- phase12_release_file_sha256(path)
  manifest$sha256[[index]] <- hash
  manifest$canonical_content_sha256[[index]] <- hash
  ...
}

expect_error(preflight_phase12_approved_release(fixture$trusted_root), "hash|metadata")
...
expect_error(preflight_phase12_approved_release(fixture$trusted_root), "freeze or track link")
```

**Compact synthetic contract fixture pattern** (`tests/testthat/test_benchmark_contracts.R:9-68`, `tests/testthat/test_benchmark_contracts.R:261-303`):
```r
contract_grid <- function(id = "dist_1", support_max = 2L) { ... }
contract_fixture <- function() { ... }
contract_prediction <- function(grid = contract_grid()) { ... }
...
testthat::expect_error(validate_model_manifests(leaked), "strictly before")
```

**Compact committed-fixture usage pattern** (`tests/testthat/test_worldcup_dashboard.R:677-739`):
```r
groups <- load_worldcup_2026_groups(file.path(project_root, "data/raw/worldcup_2026_groups.csv"))
elo_ratings_path <- tempfile(fileext = ".csv")
output_dir <- tempfile("worldcup-dashboard-")
write.csv(..., elo_ratings_path, row.names = FALSE)
payload <- build_worldcup_dashboard(..., output_dir = output_dir, elo_ratings_path = elo_ratings_path, ...)
expect_true(file.exists(payload$paths$data_json))
```

**Phase 13 adaptation**
- Use small synthetic candidate/accepted bundle tables and temp dirs for validator tests.
- Keep fixture samples committed and compact.
- Prefer `expect_silent()` for happy-path contracts and `expect_error()` with narrow failure substrings for fail-closed cases: missing resource class, mixed fallback status, SHA mismatch, unsafe path, ambiguous mapping.

---

### `tests/testthat/test_phase13_competition_registry.R` (test, CRUD)

**Primary analog:** `tests/testthat/test_benchmark_registry.R`

**Registry test shape** (`tests/testthat/test_benchmark_registry.R:7-17`, `tests/testthat/test_benchmark_registry.R:41-49`, `tests/testthat/test_benchmark_registry.R:52-100`):
```r
test_that("canonical registry has the locked 12-edition and 630-fixture denominator", {
  registries <- load_benchmark_registries(file.path(project_root, "data/benchmark/phase09"))
  expect_silent(validate_benchmark_registries(registries))
  ...
})

test_that("canonical registry hashes ignore harmless row order", {
  registries <- synthetic_benchmark_registries()
  original <- canonical_benchmark_sha256(registries$fixtures, key = "fixture_id")
  reordered <- canonical_benchmark_sha256(
    registries$fixtures[rev(seq_len(nrow(registries$fixtures))), ],
    key = "fixture_id"
  )
  expect_identical(original, reordered)
})

test_that("registry path validation rejects traversal and external absolute roots", {
  expect_error(validate_benchmark_registry_paths("../phase09"), "path|root|relative")
  expect_error(validate_benchmark_registry_paths(tempdir()), "path|root|relative")
  expect_silent(validate_benchmark_registry_paths("data/benchmark/phase09", project_root))
})
```

**Phase 13 adaptation**
- Mirror this structure for lifecycle transitions, blocked overlay behavior, pinned model release changes, EURO pre-draw row invariants, and row-order-stable hashes.
- Add explicit tests that rejected refreshes retain the last accepted bundle ID and surface blocked metadata instead of mutating accepted outputs.

## Shared Patterns

### Trusted Root And Fail-Closed Paths
**Source:** `R/benchmark/registry.R:19-57`, `R/release/release_bundle.R:111-130`, `R/release/release_contract.R:17-72`
**Apply to:** `R/competition/source_contracts.R`, `R/competition/edition_registry.R`, `scripts/acquire_uefa_snapshot.R`
```r
if (!startsWith(candidate, prefix)) stop("... path escapes the trusted root", call. = FALSE)
if (any(vapply(dirs, phase12_release_contract_is_symlink, logical(1)))) stop("... must not be a symlink", call. = FALSE)
```

### Canonical SHA-256 Everywhere
**Source:** `R/benchmark/registry.R:83-131`, `R/release/release_bundle.R:38-42`, `R/release/release_bundle.R:187-200`
**Apply to:** Bundle rows, artifact rows, registry rows, accepted manifests
```r
digest::digest(..., algo = "sha256", serialize = FALSE)
```

### Atomic Publication
**Source:** `R/release/release_bundle.R:69-101`
**Apply to:** All committed Phase 13 CSV/JSON/RDS outputs
```r
staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
...
if (!file.rename(staged, path)) stop("Could not publish ...", call. = FALSE)
```

### Separate Canonical IDs From Display Values
**Source:** `R/elo/preprocess.R:22-57`, `R/visualization/worldcup_dashboard.R:69-120`
**Apply to:** `team_identity.csv`, accepted fixture/group/result rows
```r
fixtures$home_display <- unname(display_lookup[fixtures$home_team])
fixtures$away_display <- unname(display_lookup[fixtures$away_team])
```

### Local-Only Raw Store
**Source:** `.gitignore:1-6`
**Apply to:** `data/competition/local_raw/`
```gitignore
data/raw/wcq_cache/
data/raw/eloratings/
data/raw/espn/
data/cache/
data/raw/transfermarkt/*.duckdb
data/raw/transfermarkt/*.duckdb.wal
```

### Focused `testthat` Style
**Source:** `tests/testthat/test_phase12_release.R:80-105`, `tests/testthat/test_benchmark_registry.R:52-100`, `tests/testthat/test_worldcup_dashboard.R:677-739`
**Apply to:** Both new Phase 13 test files
```r
expect_silent(...)
expect_error(..., "hash|path|status|review")
tempfile(...)
write.csv(...)
```

## No Analog Found

None. The repo has no exact UEFA structured-capture implementation yet, but every grouped Phase 13 target has a strong role-match analog.

## Metadata

**Analog search scope:** `R/benchmark/`, `R/release/`, `R/elo/`, `R/visualization/`, `scripts/`, `tests/testthat/`, `data/raw/`, `data/benchmark/`, `.gitignore`
**Files scanned:** 14 direct reads plus repo-wide `rg` over `R/`, `scripts/`, `tests/`, and `data/`
**Pattern extraction date:** 2026-08-13
