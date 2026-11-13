library(testthat)

nl_workspace_test_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)

nl_workspace_fixture <- function() {
  api <- new.env(parent = globalenv())
  sys.source(file.path(nl_workspace_test_root, "scripts/refresh_nations_league_state.R"), envir = api)
  api$phase14_refresh_nl_root <- nl_workspace_test_root
  backend <- api$phase14_refresh_nl_load()
  parent <- tempfile("nl-parent-checkout-")
  child <- file.path(parent, "logs/competition-refresh/workspaces/test/project")
  dir.create(file.path(parent, ".git"), recursive = TRUE)
  for (root in c(parent, child)) {
    dir.create(file.path(root, "R/competition"), recursive = TRUE)
    dir.create(file.path(root, "scripts"), recursive = TRUE)
  }
  old_hash <- strrep("a", 64L)
  new_hash <- strrep("b", 64L)
  for (root in c(parent, child)) {
    accepted <- file.path("data/competition/accepted", backend$phase14_uefa_nl_edition_id())
    capture_path <- file.path(accepted, "stage_capture.csv")
    raw_path <- file.path("data/competition/local_raw", backend$phase14_uefa_nl_edition_id(),
      backend$phase15_uefa_nl_stage_capture_id(), "stage_capture.json")
    dir.create(file.path(root, accepted), recursive = TRUE)
    dir.create(dirname(file.path(root, raw_path)), recursive = TRUE)
    dir.create(file.path(root, "data/competition/registries"), recursive = TRUE)
    capture <- as.data.frame(setNames(lapply(backend$phase15_uefa_nl_stage_capture_schema(),
      function(x) character()), backend$phase15_uefa_nl_stage_capture_schema()))
    backend$phase13_publication_write_csv(capture, file.path(root, capture_path))
    writeBin(charToRaw("[]"), file.path(root, raw_path))
    hash_file <- function(relative) digest::digest(file = file.path(root, relative), algo = "sha256", serialize = FALSE)
    manifest <- data.frame(capture_id = backend$phase15_uefa_nl_stage_capture_id(),
      edition_id = backend$phase14_uefa_nl_edition_id(), capture_relative_path = capture_path,
      raw_relative_path = raw_path, capture_status = "empty", capture_row_count = 0L,
      capture_content_sha256 = hash_file(capture_path), raw_sha256 = hash_file(raw_path),
      source_bundle_id = backend$phase14_uefa_nl_bundle_id(), source_bundle_sha256 = old_hash,
      source_url = "https://www.uefa.com/uefanationsleague/fixtures-results/",
      retrieved_at_utc = "2026-11-01T00:00:00Z", parser_commit_sha = strrep("c", 40L),
      validation_status = "valid", manifest_sha256 = "", row_sha256 = "")
    manifest$manifest_sha256 <- backend$phase15_uefa_nl_manifest_self_sha256(manifest)
    manifest$row_sha256 <- backend$phase15_uefa_nl_capture_row_hash(manifest)
    backend$phase13_publication_write_csv(manifest, file.path(root, accepted, "stage_capture_manifest.csv"))
    backend$phase13_publication_write_csv(manifest, file.path(root, "data/competition/registries/stage_captures.csv"))
    backend$phase13_publication_write_csv(data.frame(bundle_id = backend$phase14_uefa_nl_bundle_id(),
      edition_id = backend$phase14_uefa_nl_edition_id(),
      source_bundle_sha256 = if (identical(root, child)) new_hash else old_hash),
      file.path(root, "data/competition/registries/source_bundles.csv"))
  }
  api$phase14_refresh_nl_root <- child
  list(api = api, backend = backend, parent = normalizePath(parent), child = normalizePath(child),
    new_hash = new_hash)
}

test_that("NL readers stay in a nested private code root without its own Git checkout", {
  x <- nl_workspace_fixture()
  on.exit(unlink(x$parent, recursive = TRUE), add = TRUE)
  resolvers <- c("phase13_source_find_project_root", "phase14_forecast_project_root",
    "phase14_state_bundle_project_root", "phase14_form_find_project_root",
    "uefa_nl_rules_project_root", "phase15_uefa_nl_adapter_project_root")
  for (name in resolvers) {
    expect_identical(x$backend[[name]](x$child), x$child, info = name)
    expect_identical(x$backend[[name]](file.path(x$child, "R/competition")), x$child, info = name)
    expect_identical(x$backend[[name]](x$parent), x$parent, info = name)
  }
  previous <- setwd(file.path(x$child, "R/competition"))
  on.exit(setwd(previous), add = TRUE)
  for (name in resolvers) expect_identical(x$backend[[name]](), x$child, info = name)
})

test_that("empty capture repinning uses the fresh private source and preserves parent bytes", {
  x <- nl_workspace_fixture()
  on.exit(unlink(x$parent, recursive = TRUE), add = TRUE)
  parent_paths <- list.files(file.path(x$parent, "data"), recursive = TRUE, full.names = TRUE)
  parent_hashes <- tools::md5sum(parent_paths)
  expect_error(x$backend$phase15_uefa_nl_read_stage_capture(x$child), "unexpected Phase 13 source bundle hash")
  bundle <- x$api$phase14_refresh_nl_read_source_bundle(x$backend)
  repin <- x$api$phase14_refresh_nl_repin_stage_capture(x$backend, bundle)
  expect_identical(repin$paths$project_root, x$child)
  expect_identical(repin$manifest$source_bundle_sha256, x$new_hash)
  expect_identical(tools::md5sum(parent_paths), parent_hashes)
  x$api$phase14_refresh_nl_write_stage_capture(x$backend, repin)
  capture <- x$backend$phase15_uefa_nl_read_stage_capture(x$child)
  expect_identical(capture$manifest$source_bundle_sha256, x$new_hash)
  expect_identical(capture$capture_status, "empty")
  expect_identical(tools::md5sum(parent_paths), parent_hashes)
  writeBin(charToRaw('["tampered"]'), capture$paths$raw_path)
  expect_error(x$backend$phase15_uefa_nl_read_stage_capture(x$child), "raw hash mismatch")
})
