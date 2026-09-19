# Phase 18: Club and UCL Source Contracts - Pattern Map

**Mapped:** 2026-09-19  
**Files/responsibilities analyzed:** 20  
**Analogs found:** 17 / 20

## File Classification

| New/Modified File or Responsibility | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/competition/football_data_org_adapter.R` | service / adapter | request-response, transform | `scripts/acquire_uefa_snapshot.R` lines 728-871 | role + flow match |
| `R/competition/ucl_source_acceptance.R` | service / policy gate | request-response, batch validation | `R/competition/source_contracts.R` lines 397-788 | role-match; decision matrix is new |
| `R/club/identity.R` | service / model | transform, keyed lookup | `R/competition/team_identity.R` lines 138-174 and 1494-1648 | algorithm match; schema must be new |
| `R/club/history_contract.R` | service / model | batch, transform, file-I/O | `R/competition/team_identity.R` lines 1165-1713 | partial role + flow match |
| `scripts/accept_ucl_provider.R` | controller / CLI | request-response, file-I/O | `scripts/acquire_uefa_snapshot.R` lines 1-53, 138-217, 3318-3405 | exact CLI/lifecycle match |
| `scripts/build_club_history_corpus.R` | controller / CLI | batch, file-I/O | `scripts/acquire_uefa_snapshot.R` lines 1047-1250 and `R/competition/source_contracts.R` lines 801-833 | role + flow match |
| `data/club/registries/clubs.csv` | model / registry | CRUD, file-I/O | `data/competition/registries/team_identity.csv` plus `R/competition/team_identity.R` lines 49-98 | schema is intentionally not reusable |
| `data/club/registries/club_source_ids.csv` | model / registry | CRUD, keyed lookup | source-ID fields in `R/competition/team_identity.R` lines 49-98 | partial match |
| `data/club/registries/club_aliases.csv` | model / registry | CRUD, keyed lookup | alias expansion in `R/competition/team_identity.R` lines 100-174 | partial match |
| `data/club/history_sources.csv` | config / source inventory | file-I/O, batch | artifact provenance in `data/competition/registries/source_artifacts.csv` | role-match |
| `data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/*` | config / decision evidence | file-I/O, request-response | reviewed fallback metadata in `R/competition/source_contracts.R` lines 467-562 and 625-651 | partial; legal/terms review is new |
| `data/competition/accepted/uefa_champions_league_2026_27/*` | model / accepted bundle | file-I/O, transform | accepted snapshot tree validated by `R/competition/edition_registry.R` lines 721-939 and 1111-1205 | exact storage pattern |
| `data/club/accepted/<corpus_id>/*` | model / accepted corpus | file-I/O, batch | source bundle/manifest tables in `R/competition/source_contracts.R` lines 490-788 | role-match |
| `tests/testthat/test_phase18_source_acceptance.R` | test | request-response, policy validation | `tests/testthat/test_phase13_source_contracts.R` lines 97-220 | role-match; decision-state tests are new |
| `tests/testthat/test_phase18_football_data_adapter.R` | test | request-response | `tests/testthat/test_phase13_source_contracts.R` lines 493-559 | exact injected-transport pattern |
| `tests/testthat/test_phase18_source_bundle.R` | test | file-I/O, validation | `tests/testthat/test_phase13_source_contracts.R` lines 109-203 | exact contract pattern |
| `tests/testthat/test_phase18_refresh_failure.R` | test | event-driven failure, file-I/O | `tests/testthat/test_phase13_refresh_failure.R` lines 119-327 | exact LKG/rollback pattern |
| `tests/testthat/test_phase18_club_identity.R` | test | transform, keyed lookup | `tests/testthat/test_phase13_competition_registry.R` lines 945-1145 plus lines 184-253 | role-match |
| `tests/testthat/test_phase18_club_history_contract.R` | test | batch, transform | `tests/testthat/test_phase13_competition_registry.R` lines 945-1145 | partial; score/temporal audits are new |
| `tests/fixtures/phase18/**` and `.gitignore` | test fixture / config | file-I/O | `tests/fixtures/phase13/**`; `.gitignore` line 7 | exact layout match |

## Pattern Assignments

### `R/competition/football_data_org_adapter.R` (service/adapter, request-response + transform)

**Primary analog:** `scripts/acquire_uefa_snapshot.R`

**Bounded, injectable transport pattern** (lines 728-871):

```r
phase13_acquire_fetch_structured_url <- function(
    url,
    artifact_type,
    max_bytes = 5e6,
    max_attempts = 3L,
    timeout_seconds = 30,
    min_interval_seconds = 1,
    backoff_base_seconds = 1,
    request_fn = NULL,
    perform_fn = NULL,
    clock_fn = function() as.numeric(Sys.time()),
    sleep_fn = Sys.sleep,
    rate_limit_state = NULL,
    request_headers = NULL,
    validate_payload_fn = phase13_source_validate_resource_payload) {
  # ... HTTPS, bounds, content-type, raw-byte, JSON, and schema checks ...
  return(list(payload = payload, raw_bytes = raw_bytes, source_url = url))
}
```

Copy the dependency-injection seam (`request_fn`, `perform_fn`, clock/sleep) and the sequence **status -> content type -> byte bound -> exact raw bytes -> JSON parse -> schema validate**. Use a fixed host and fixed endpoint templates for `competitions/CL`, `teams`, `matches`, and `standings`; unlike the analog, do not accept arbitrary URLs.

**Retry/error pattern** (lines 728-730 and 851-870):

```r
phase13_acquire_retryable_statuses <- function() {
  c(408L, 425L, 429L, 500L, 502L, 503L, 504L)
}

if (!transient || attempt >= max_attempts) break
sleep_fn(min(8, backoff_base_seconds * (2 ^ (attempt - 1L))))
```

The Phase 18 adapter should prefer `httr2::req_retry()` and `req_throttle(capacity = 9, fill_time_s = 60)`, but retain injectable `perform_request` for deterministic tests. Classify failures into typed codes rather than exposing raw provider messages as the durable contract.

**Secret handling: no local exact analog.** Read `FOOTBALL_DATA_API_TOKEN` inside the live request function, attach it with `httr2::req_headers_redacted()`, and return only response bytes plus non-secret metadata. Never return or serialize the request object. Existing `request_headers` support at lines 805-810 is not sufficient for a credential-bearing request and should not be copied verbatim.

**Testing analog:** `tests/testthat/test_phase13_source_contracts.R` lines 493-559 injects a sequence of 503/200 responses, captures requests, suppresses real sleeps, caps retries, and rejects non-JSON bodies. Copy that structure for 429, `Retry-After`, network error, empty/null payload, unknown enums, and token non-leakage.

---

### `R/competition/ucl_source_acceptance.R` (service/policy gate, batch validation)

**Primary analog:** `R/competition/source_contracts.R`

**Artifact provenance constructor** (lines 397-466):

```r
phase13_build_source_artifact <- function(
    raw_bytes,
    artifact_id,
    bundle_id,
    edition_id,
    artifact_type,
    source_url,
    retrieved_at_utc,
    parser_commit_sha = NULL,
    fallback_status = "official",
    review_state = NULL,
    relative_local_raw_path = NULL,
    project_root = ".") {
  row <- data.frame(
    schema_version = "phase13-source-artifact-v1",
    artifact_id = artifact_id,
    bundle_id = bundle_id,
    edition_id = edition_id,
    artifact_type = artifact_type,
    source_url = source_url,
    retrieved_at_utc = retrieved_at_utc,
    bytes = as.integer(length(raw_bytes)),
    raw_sha256 = phase13_source_sha256(raw_bytes),
    parser_commit_sha = tolower(parser_commit_sha),
    fallback_status = fallback_status,
    review_state = review_state,
    relative_local_raw_path = relative_local_raw_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- phase13_row_sha256(row)
  row
}
```

Keep the one-row-per-resource construction, exact raw SHA-256, parser Git SHA, local raw path, and row hash. Extend the Phase 18 row with `provider_id`, `source_as_of_utc`, provider schema fingerprint, accepted provider-decision ID, and canonical content hash.

**Bundle gate** (lines 490-562 and 653-718):

```r
phase13_build_source_bundle <- function(
    bundle_id, edition_id, artifacts, bundle_status = "accepted", ...) {
  phase13_validate_source_artifacts(artifacts)
  # require one edition, one parser identity, one fallback state
  artifact_hash <- phase13_canonical_sha256(artifacts, key = "artifact_id")
  # ... manifest self-hash and row hash ...
}

phase13_validate_source_bundle <- function(bundle, artifacts) {
  # require exact resource graph and matching foreign keys/hashes
  if (!identical(as.character(bundle$bundle_status), "accepted")) {
    stop("Phase 13 source bundle is not accepted", call. = FALSE)
  }
}
```

Use the same build-then-validate split. For UCL, acceptance must additionally require all machine rows to pass and the owner terms review to be approved. Offline fixture success must never set `automation_enabled = TRUE`.

**New decision state machine (no exact analog):** define explicit `not_run`, `accepted`, `rejected`, and `manual_only` states, with typed reasons including `missing_credential`, `application_scope`, `terms`, `attribution`, `retention`, `quota`, `http`, `null`, `empty`, `stale`, `schema`, `coverage`, `identity`, and `secret_exposure`. The reviewed-fallback conjunction in `phase13_validate_fallback_review_metadata()` (lines 625-651) is the closest structural pattern, but it does not cover legal/business acceptance.

---

### `R/club/identity.R` and `data/club/registries/{clubs,club_source_ids,club_aliases}.csv`

**Primary analog:** `R/competition/team_identity.R`

**Resolution-order pattern** (lines 138-174):

```r
phase13_resolve_team_identity <- function(identity_map, source_team_id = NA_character_, display_name) {
  identity_map <- phase13_prepare_team_identity_map(identity_map)
  if (!is.na(source_team_id)) {
    direct <- identity_map[identity_map$uefa_source_team_id == source_team_id, , drop = FALSE]
    if (nrow(direct) > 1L) stop("... ambiguous ...", call. = FALSE)
    if (nrow(direct) == 1L) return(phase13_identity_result(...))
  }
  # fallback only when exactly one normalized alias matches
  if (nrow(matches) != 1L) stop("... unresolved or ambiguous ...", call. = FALSE)
}
```

Fork the algorithm only: exact `(source_system, source_club_id)` at event time first, then exactly one reviewed validity-compatible alias. Fail on overlap, ambiguity, pending review, expired mapping, or source-ID/name disagreement.

**Historical identity validation pattern** (lines 1494-1648):

```r
phase13_martj42_resolve_registry_identity <- function(registry, source_team_id, source_display_name) {
  # source ID first; require its normalized name to remain an accepted alias
  # alias fallback must resolve to exactly one registry row
}

phase13_validate_martj42_identity_coverage <- function(history, identity_map) {
  tokens <- phase13_martj42_history_identity_tokens(history)
  phase13_validate_martj42_identity_map(identity_map)
  missing <- setdiff(tokens$source_identity_key, identity_map$source_identity_key)
  extra <- setdiff(identity_map$source_identity_key, tokens$source_identity_key)
  if (length(missing) || length(extra)) stop("...", call. = FALSE)
}
```

Copy exact coverage and hash validation. Add interval-overlap checks and `entity_kind == "club"` checks before resolution.

**Boundary that must not be copied:** the national schema at lines 3-17 requires `team_id`, `fifa_code`, and UEFA national-team fields. Club registries must use a distinct `club_id` syntax/root and reject any `team_*` ID or FIFA-code-only resolution. Do not append club rows to `data/competition/registries/team_identity.csv`.

**Testing analogs:**

- `tests/testthat/test_phase13_competition_registry.R` lines 184-253: direct ID, visible alias fallback, accent normalization, and ambiguity rejection.
- The same file lines 1060-1145: missing provenance, duplicate source identity, conflicting mapping, unresolved identity, and ambiguous aliases all fail closed.

---

### `R/club/history_contract.R`, `data/club/history_sources.csv`, and `data/club/accepted/<corpus_id>/*`

**Primary analog:** historical boundary in `R/competition/team_identity.R`.

**Schema/provenance pattern** (lines 1165-1206):

```r
phase13_martj42_identity_map_required_columns <- function() {
  c(
    "identity_map_version", "source_dataset", "source_version",
    "source_input_sha256", "source_artifact_id", "source_identity_key",
    # ... canonical identity, mapping, review, table and row hashes ...
  )
}
```

Use explicit version, source input hash, source artifact ID, identity-map hash, and row hash on every normalized output. `history_sources.csv` should replace a mutable source version with repository URL + full commit SHA + committed time + path + license metadata + retrieval time + bytes + raw SHA-256.

**Input-shape and stable-ID pattern** (lines 1250-1347):

```r
phase13_martj42_history_match_ids <- function(history) {
  ids <- trimws(as.character(history[[phase13_martj42_history_match_id_column(history)]]))
  if (any(is.na(ids) | !nzchar(ids))) stop("... missing ...", call. = FALSE)
  if (anyDuplicated(ids)) stop("... duplicate ...", call. = FALSE)
  ids
}

phase13_martj42_validate_history_shape <- function(history) {
  # required columns, nonempty input, stable match IDs, dates, teams, tournament,
  # and nonnegative integer score checks
}
```

Copy stable source IDs and strict shape checks. Extend the normalized schema with split regulation/final/extra-time/shootout fields, `kickoff_precision`, `evidence_available_at_utc`, `counts_for_model`, and `exclusion_reason`. Unknown score meaning must stay present in audits but cannot enter active model rows.

**Corpus manifest pattern:** use `phase13_canonical_sha256()` / `phase13_row_sha256()` from `R/competition/source_contracts.R` lines 209-240 and the bundle/self-hash pattern at lines 467-562. The accepted corpus must be inventory-driven; never scan an arbitrary checkout at training time.

**New audit family (no single exact analog):** `coverage_audit.csv`, `identity_audit.csv`, `duplicate_audit.csv`, `score_semantics_audit.csv`, and `temporal_audit.csv` are new. Their common pattern is: deterministic schema, one explicit disposition per candidate, canonical ordering, row hashes, and one corpus-level gate that sets `accepted_for_training = TRUE` only when every required audit is clean.

**Testing analog:** `tests/testthat/test_phase13_competition_registry.R` lines 945-1058 proves normalized historical identity remains stable under append, reorder, and score-only changes while hashes change when content changes. Reuse this metamorphic-test style for pinned source order, future rows, date-only availability, corrections, and cross-source duplicates.

---

### `scripts/accept_ucl_provider.R` (controller/CLI, request-response + file-I/O)

**Primary analog:** `scripts/acquire_uefa_snapshot.R`

**Entrypoint/import pattern** (lines 1-53):

```r
#!/usr/bin/env Rscript

phase13_acquire_command_args <- commandArgs(trailingOnly = FALSE)
# resolve this script, derive project root, then source owned R modules
source(file.path(phase13_acquire_project_root, "R/competition/source_contracts.R"))
source(file.path(phase13_acquire_project_root, "R/competition/edition_registry.R"))
```

Copy self-location and explicit `source()` calls. Keep the Phase 18 CLI thin: parse options, call pure adapter/acceptance functions, write evidence, return nonzero on rejected/blocked live runs.

**Argument parser pattern** (lines 138-187): a fixed allowlist of value options, explicit boolean switches, `--` normalization, and rejection of unknown or valueless options. Add only provider/edition/review/evidence-root options; do not accept an arbitrary host.

**Main/error boundary** (lines 3318-3405):

```r
phase13_acquire_main <- function(args = commandArgs(trailingOnly = TRUE), ...) {
  options <- phase13_acquire_parse_args(args)
  tryCatch({
    candidate <- phase13_acquire_candidate(options, edition_id)
    # validate before any promotion
    invisible(candidate)
  }, error = function(error) {
    # write durable blocked metadata without replacing accepted state
    stop(sprintf("Phase 13 source capture blocked: %s", conditionMessage(error)), call. = FALSE)
  })
}
```

Missing credentials are a normal recorded `not_run_missing_credential` outcome, not an offline synthetic pass. The token must be read only below the live request boundary and must not be accepted as a CLI argument.

---

### `scripts/build_club_history_corpus.R` (controller/CLI, batch + file-I/O)

**Analogs:** `scripts/acquire_uefa_snapshot.R` lines 1047-1250 and `R/competition/source_contracts.R` lines 801-833.

Follow candidate-first orchestration: load a declared source inventory, verify every commit/path/license/hash, parse into candidate tables, run all audits, then write an accepted corpus only after validation. Use atomic writers:

```r
phase13_source_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 13 CSV: ", path, call. = FALSE)
}
```

Do not let this CLI choose the Phase 19 training panel. Its authority ends at `accepted_for_training` evidence for the audited corpus.

---

### Accepted current-state bundle and last-known-good transaction

**Accepted tree analog:** `R/competition/edition_registry.R` lines 721-939 and 1111-1205.

Copy the trusted-root/no-symlink checks, exact file inventory, manifest foreign keys, row hashes, canonical content hashes, and raw-byte provenance. Extend the exact resource graph to UCL tables (`competition`, `clubs`, `matches`, `standings`, plus lifecycle/metadata as planned); do not silently omit an empty required table.

**Blocked registry row analog** (`R/competition/edition_registry.R` lines 557-585):

```r
phase13_block_competition_edition <- function(row, failure_reason, failure_at_utc, ...) {
  if (phase13_registry_blank(row$active_output_bundle_id[[1L]])) {
    stop("Phase 13 blocked edition must retain an active output bundle", call. = FALSE)
  }
  row$blocked <- TRUE
  row$blocked_reason <- failure_reason
  row$last_accepted_output_bundle_id <- as.character(row$active_output_bundle_id[[1L]])
  row$row_sha256 <- phase13_registry_row_hash(row)
  row
}
```

**Atomic promotion analog** (`scripts/acquire_uefa_snapshot.R` lines 2320-2412):

```r
phase13_with_publication_lock(
  publication_root = publication_root,
  targets = targets,
  callback = function(transaction) {
    phase13_seed_publication_staging(transaction)
    # stage candidate and validate complete graph
    phase13_promote_publication_targets(transaction)
  }
)
```

**Blocked sidecar transaction analog** (`scripts/acquire_uefa_snapshot.R` lines 2587-2778): stage the edition row, history row, and `blocked_refresh.json`; validate the staged graph; back up incumbents; rename all targets; and roll back every promoted path on failure. Add a typed `reason_code` separate from a human-readable message.

---

### Phase 18 tests and synthetic fixtures

**Test loading convention:** source production modules into a fresh environment, as in `tests/testthat/test_phase13_refresh_failure.R` lines 3-18. This prevents CLI auto-execution while exposing its functions.

**Byte-snapshot failure proof** (`tests/testthat/test_phase13_refresh_failure.R` lines 67-76 and 119-205):

```r
phase13_refresh_test_file_snapshot <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE)
  hashes <- vapply(files, function(path) {
    digest::digest(readBin(path, "raw", file.info(path)$size),
                   algo = "sha256", serialize = FALSE)
  }, character(1))
  setNames(hashes, relative)
}

accepted_before <- phase13_refresh_test_file_snapshot(sandbox$accepted_root)
# run invalid candidate
expect_identical(phase13_refresh_test_file_snapshot(sandbox$accepted_root), accepted_before)
```

Use this for every UCL failure class: missing credential, terms gate, HTTP/rate limit, null, empty, stale, unknown enum, schema drift, incomplete coverage, identity failure, and injected sidecar/promotion failure.

**Synthetic fixture convention:** copy the small committed shapes under `tests/fixtures/phase13/`, not live provider bytes. Every Phase 18 fixture should be fictional and carry a visible `synthetic_contract_fixture` marker. Include success and negative variants for provider JSON, club aliases/validity, and OpenFootball-shaped score semantics.

**History metamorphic tests:** reuse `tests/testthat/test_phase13_competition_registry.R` lines 945-1145. Assert order stability, append stability, future-row isolation, hash sensitivity, exact identity coverage, and fail-closed ambiguity.

---

### `.gitignore` (config, file-I/O boundary)

**Analog:** `.gitignore` line 7:

```gitignore
data/competition/local_raw/
```

Add `data/club/local_raw/` and any provider HTTP-cache directory. Keep provider acceptance decisions, terms-review templates, normalized accepted tables, hashes, and audit manifests tracked. Never rely on ignore rules alone for secret hygiene; tests should scan generated evidence and the Git diff for the exact token.

## Shared Patterns

### Canonical hashes and self-verifying manifests

**Source:** `R/competition/source_contracts.R` lines 177-240 and 467-562.  
**Apply to:** provider decisions, source artifacts, current-state bundles, club registry rows, history source inventory, all audit tables, corpus manifest.

```r
phase13_source_sha256 <- function(value) {
  digest::digest(phase13_source_raw_bytes(value), algo = "sha256", serialize = FALSE)
}

phase13_row_sha256 <- function(data, hash_col = "row_sha256") {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(
      data[index, fields, drop = FALSE],
      phase13_source_canonical_scalar,
      character(1)
    )
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}
```

Always declare the canonical sort key. Keep raw-byte hash, canonical-table hash, manifest hash, and manifest self-hash distinct.

### Fail closed before promotion

**Sources:** `R/competition/source_contracts.R` lines 563-718; `R/competition/edition_registry.R` lines 1111-1205.  
**Apply to:** every candidate bundle and corpus.

The accepted artifact is the output of validation, never the input assumption. Reject unknown columns/enums where they affect meaning, missing required resources, empty/null semantic payloads, duplicate keys, incomplete foreign keys, unsafe paths, symlinks, and hash drift.

### Last-known-good is byte preservation, not fallback recomputation

**Sources:** `scripts/acquire_uefa_snapshot.R` lines 2587-2778; `tests/testthat/test_phase13_refresh_failure.R` lines 119-327.  
**Apply to:** current UCL refresh and provider-exit behavior.

Snapshot incumbent trees before the candidate run, publish blocked metadata separately, and prove accepted artifacts are byte-identical afterward. Provider exit is subject to the reviewed retention/termination decision; if continued display is not permitted, switch to an independently lawful snapshot or explicit unavailable state rather than retaining provider-derived bytes by default.

### Separate identity domains

**Source:** `R/competition/team_identity.R` lines 3-17 documents the national-only shape.  
**Apply to:** all club registries, adapters, history, and tests.

Use `club_id`/`entity_kind = club` and distinct roots. No club function may accept `team_*` IDs, infer identity from FIFA code, or join against `team_identity.csv` as authority.

### CLI error handling

**Source:** `scripts/acquire_uefa_snapshot.R` lines 3318-3405.  
**Apply to:** both Phase 18 scripts.

Pure functions raise specific `stop(..., call. = FALSE)` errors; the CLI boundary classifies them, writes one durable machine-readable outcome where permitted, and exits nonzero for rejected/blocked live operations. Never print a secret-bearing request or environment value.

### Test structure

**Sources:** `tests/testthat/test_phase13_source_contracts.R` lines 97-220 and 493-559; `tests/testthat/test_phase13_refresh_failure.R` lines 3-327.  
**Apply to:** all `test_phase18_*.R` files.

Each test file should own helpers prefixed `phase18_*_test_`, use temporary sandboxes, inject transport/clock/sleep/writers, and assert exact error semantics plus durable byte invariants. Default tests must not require network or a key.

## No Exact Analog Found

| File / Responsibility | Role | Data Flow | Reason / Planner Guidance |
|---|---|---|---|
| `provider_terms_review.csv` and provider decision state machine | config / policy gate | request-response, human approval | Existing fallback review metadata proves a conjunction pattern but does not model application scope, attribution, normalized display, retention, termination, or provider exit. Specify a reviewed schema and keep automation false unless owner and machine gates both pass. |
| Validity-aware three-table club identity registry | model / registry | CRUD, keyed lookup | Existing national identity is one-table, FIFA-oriented, and lacks validity intervals. Reuse resolution and hashing algorithms only; create a separate club namespace and overlap validators. |
| Club history coverage/duplicate/score-semantics/temporal audit family | service / audit model | batch, transform | Historical national normalization supplies stable identity/provenance patterns but no accepted-corpus audit suite. Define deterministic schemas, dispositions, hashes, and one corpus-level acceptance gate from research. |

## Planner Guardrails

1. Do not schedule UCL rules, standings recomputation, simulation, club model training, or dashboard work in Phase 18; this phase produces accepted inputs and evidence only.
2. Treat the live key plus owner terms review as an explicit checkpoint. The offline-complete state is valid with `automation_enabled = FALSE` and `not_run_missing_credential` or `manual_only`.
3. Do not modify or extend national `team_identity.csv` for clubs.
4. Keep all raw live provider bytes and HTTP caches in ignored local roots; commit only permitted normalized evidence, hashes, counts, schemas, and decisions.
5. Use synthetic fixtures for CI. A fixture pass proves parser behavior, never current 2026/27 completeness or legal acceptance.
6. Every failed candidate must leave accepted current state byte-identical and create a typed blocked-refresh record without overwriting the incumbent.

## Metadata

**Analog search scope:** `R/competition/`, `scripts/`, `tests/testthat/`, `tests/fixtures/phase13/`, `data/competition/registries/`, `.gitignore`  
**Primary analog files read:** 8  
**Pattern extraction date:** 2026-09-19
