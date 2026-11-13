# Synthetic Phase 13 publication context. Never copy the live competition
# schedule: its lifecycle, source schema and results change between test runs.
phase13_fixture_load_acquire <- function(project_root) {
  api <- new.env(parent = globalenv())
  previous <- setwd(project_root)
  on.exit(setwd(previous), add = TRUE)
  sys.source(file.path(project_root, "scripts/acquire_uefa_snapshot.R"), envir = api)
  api$phase13_acquire_now_utc <- function() "2026-08-14T12:00:00Z"
  api
}

phase13_fixture_inventory <- function(root) {
  paths <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  paths <- paths[!file.info(paths)$isdir]
  setNames(vapply(paths, function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE),
    character(1)), substring(paths, nchar(normalizePath(root, winslash = "/")) + 2L))
}

phase13_fixture_sandbox <- function(project_root, publish = TRUE) {
  api <- phase13_fixture_load_acquire(project_root)
  # The real CLI validates that explicit accepted/raw roots remain under its
  # project. Use an owned disposable sibling of tests/, never production data/.
  root <- tempfile("phase13-synthetic-", tmpdir = project_root)
  success <- FALSE
  on.exit(if (!success) unlink(root, recursive = TRUE), add = TRUE)
  registry_root <- file.path(root, "data/competition/registries")
  accepted_root <- file.path(root, "data/competition/accepted")
  raw_root <- file.path(root, "data/competition/local_raw")
  dir.create(registry_root, recursive = TRUE)
  fixture_dir <- file.path(project_root, "tests/fixtures/phase13")
  editions <- phase13_competition_edition_ids()
  candidates <- setNames(lapply(editions, function(id) api$phase13_acquire_candidate(
    list(`fixture-dir` = fixture_dir, `fixture-file` = NULL, `fallback-file` = NULL, `bundle-id` = NULL),
    id, project_root = project_root)), editions)
  for (candidate in candidates) api$phase13_acquire_update_registries(candidate, registry_root,
    accepted_root = accepted_root)

  fixture <- jsonlite::fromJSON(file.path(fixture_dir, "uefa_nations_league_sample.json"), simplifyVector = FALSE)
  identity <- do.call(rbind, lapply(fixture$teams, function(team)
    as.data.frame(team[phase13_team_identity_required_columns()], stringsAsFactors = FALSE)))
  identity <- phase13_prepare_team_identity_map(identity)
  identity$source_bundle_id <- candidates[[editions[[1L]]]]$bundle$bundle_id[[1L]]
  identity$row_sha256 <- ""
  identity <- identity[, phase13_team_identity_registry_required_columns()]
  identity$row_sha256 <- phase13_identity_row_hash(identity)
  phase13_source_write_csv(identity, file.path(registry_root, "team_identity.csv"))

  # CLI integration retains genuine release-pin validation. Only the source
  # fixtures are synthetic; this helper does not grant model authority.
  selector <- utils::read.csv(file.path(project_root, "outputs/releases/approved_release.csv"), stringsAsFactors = FALSE)
  catalog <- phase13_competition_edition_catalog()
  rows <- lapply(seq_along(editions), function(i) phase13_build_competition_edition_row(
    edition_id = editions[[i]], competition_id = catalog$competition_id[[i]],
    display_name = catalog$display_name[[i]], lifecycle_state = c("scheduled", "pre_draw")[[i]],
    ruleset_version = c("uefa-nations-league-2026-27-v1", uefa_euro_ruleset_version())[[i]],
    source_bundle_id = candidates[[i]]$bundle$bundle_id[[1L]], model_release_id = selector$release_id[[1L]],
    output_bundle_target = file.path("outputs/competition", editions[[i]]),
    operator = "synthetic-test", audit_at_utc = "2026-08-14T12:00:00Z"))
  phase13_source_write_csv(do.call(rbind, rows), file.path(registry_root, "competition_editions.csv"))

  if (isTRUE(publish)) {
    for (id in editions) {
      candidate <- candidates[[id]]
      api$phase13_acquire_write_raw_store(candidate, raw_root, id, candidate$bundle$bundle_id[[1L]])
      candidate <- api$phase13_acquire_publish_accepted(candidate, output_root = accepted_root,
        edition_id = id, raw_root = raw_root, registry_root = registry_root, registry_context_root = registry_root)
      api$phase13_acquire_update_registries(candidate, registry_root, accepted_root = accepted_root)
      candidates[[id]] <- candidate
    }
    artifacts <- utils::read.csv(file.path(registry_root, "source_artifacts.csv"), stringsAsFactors = FALSE,
      check.names = FALSE, na.strings = "")
    canonical <- phase13_refresh_canonical_table_hashes(root, source_artifacts = artifacts)
    phase13_refresh_accepted_manifest_hashes(root, canonical_refresh = canonical)
  }
  success <- TRUE
  list(root = root, accepted_root = accepted_root, registry_root = registry_root, raw_root = raw_root,
    api = api, editions = editions)
}
