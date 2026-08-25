library(testthat)

phase17_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase17_test_load_contract <- function() {
  environment <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_contract.R"), environment)
  environment
}

phase17_test_write_bytes <- function(path, bytes) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(bytes, path)
  path
}

test_that("phase17_wave0", {
  api <- phase17_test_load_contract()
  inventory <- api$phase17_expected_public_inventory()
  expect_length(inventory, 10L)
  expect_equal(anyDuplicated(inventory), 0L)
  expect_identical(inventory[1:4], c(
    "docs/competitions/nations-league/index.html",
    "docs/competitions/nations-league/payload.json",
    "docs/competitions/nations-league/route-manifest.json",
    "docs/competitions/nations-league/current.json"
  ))
  expect_identical(inventory[5:8], c(
    "docs/competitions/euro-qualifying/index.html",
    "docs/competitions/euro-qualifying/payload.json",
    "docs/competitions/euro-qualifying/route-manifest.json",
    "docs/competitions/euro-qualifying/current.json"
  ))
  expect_identical(tail(inventory, 2), c(
    "docs/competitions/phase17-batch-manifest.json", "docs/competitions/current.json"
  ))
  allowlist <- api$phase17_expected_git_allowlist()
  expect_true(all(inventory %in% allowlist))
  expect_true(all(c(
    "R/dashboard/payload_contract.R", "R/dashboard/renderer.R",
    "R/dashboard/publication.R", "scripts/refresh_competition_dashboards.R"
  ) %in% allowlist))
  expect_false(any(grepl("data/competition/(raw|refresh_batches)|score_distributions|logs/", allowlist)))
})

test_that("deterministic accepted fixtures are root-aware and EURO stays pre_draw", {
  api <- phase17_test_load_contract()
  root <- tempfile("phase17-root-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  nl <- api$phase17_load_fixture_bundle(root, "uefa_nations_league_2026_27")
  euro <- api$phase17_load_fixture_bundle(root, "uefa_euro_2028_qualifying")
  expect_identical(nl$edition_id, "uefa_nations_league_2026_27")
  expect_identical(euro$lifecycle_state, "pre_draw")
  expect_identical(euro$forecast_status, "pre_draw")
  expect_equal(nrow(euro$artifacts$fixtures), 0L)
  expect_equal(nrow(euro$artifacts$projected_outcomes), 0L)
  expect_identical(api$phase17_fixture_bundle("uefa_euro_2028_qualifying"), euro[names(euro) != "fixture_root"])
  expect_error(api$phase17_load_fixture_bundle(root, "forged-edition"), "unknown")
  expect_error(api$phase17_resolve_path(root, "../escape"), "traversal")
})

test_that("canonical bytes and raw snapshots are stable and preserve incumbent identity", {
  api <- phase17_test_load_contract()
  first <- api$phase17_canonical_bytes(list(b = 2, a = "text"))
  second <- api$phase17_canonical_bytes(list(b = 2, a = "text"))
  expect_identical(first, second)
  expect_length(api$phase17_sha256_raw(first), 64L)
  root <- tempfile("phase17-snapshot-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  incumbent <- api$phase17_test_fixture_root(file.path(root, "incumbent"))
  path <- file.path(incumbent, "accepted/uefa_nations_league_2026_27/incumbent.json")
  api$phase17_write_json_bytes(list(batch_id = "incumbent"), path)
  before <- api$phase17_snapshot_bytes(path, root = incumbent)
  api$phase17_write_json_bytes(list(batch_id = "candidate"), path)
  candidate <- api$phase17_snapshot_bytes(path, root = incumbent)
  expect_false(api$phase17_snapshot_equal(before, candidate))
  api$phase17_write_json_bytes(list(batch_id = "incumbent"), path)
  expect_true(api$phase17_snapshot_equal(before, api$phase17_snapshot_bytes(path, root = incumbent)))
})

test_that("5 MiB and 20 MiB limits accept equality and reject excess", {
  api <- phase17_test_load_contract()
  root <- tempfile("phase17-limits-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  exact <- api$phase17_test_write_bytes(file.path(root, "exact.bin"), raw(api$phase17_max_public_file_bytes))
  expect_silent(api$phase17_validate_byte_limits(exact))
  over_file <- api$phase17_test_write_bytes(file.path(root, "over.bin"), raw(api$phase17_max_public_file_bytes + 1L))
  expect_error(api$phase17_validate_byte_limits(over_file), "file exceeds")
  batch <- vapply(seq_len(4L), function(i) api$phase17_test_write_bytes(
    file.path(root, paste0("batch-", i, ".bin")), raw(api$phase17_max_public_file_bytes)
  ), character(1))
  expect_equal(api$phase17_validate_byte_limits(batch, max_file_bytes = api$phase17_max_batch_bytes)$total_bytes,
               api$phase17_max_batch_bytes)
  fifth <- api$phase17_test_write_bytes(file.path(root, "batch-over.bin"), raw(1L))
  expect_error(api$phase17_validate_byte_limits(c(batch, fifth), max_file_bytes = api$phase17_max_batch_bytes), "batch exceeds")
})

test_that("all required failure injectors are deterministic and fail closed", {
  api <- phase17_test_load_contract()
  names <- c("source", "rules", "probability", "freshness", "replay", "browser",
             "regression", "manifest", "hash", "promotion", "read_back", "git_preflight")
  injectors <- api$phase17_failure_injectors()
  expect_identical(names(injectors), names)
  for (name in names) {
    expect_silent(injectors[[name]]())
    expect_error(api$phase17_failure_injector(name, fail = TRUE)(), "Injected Phase 17")
  }
})

test_that("Safari capability policy is exact, automated-only, and fail closed", {
  api <- phase17_test_load_contract()
  ready <- api$phase17_probe_safari_capability(version_output = "SafariDriver 26.5.2")
  expect_true(ready$available)
  expect_true(ready$automated_only)
  expect_identical(ready$driver, "/System/Cryptexes/App/usr/bin/safaridriver")
  expect_identical(ready$version, "26.5.2")
  expect_identical(api$phase17_probe_safari_capability(enabled = FALSE)$status, "disabled")
  expect_identical(api$phase17_probe_safari_capability(version_output = "SafariDriver 99.0.0")$status, "version_mismatch")
  expect_identical(api$phase17_probe_safari_capability(driver = "/usr/bin/safaridriver")$status, "path_mismatch")
})

test_that("plist, launchctl capture, and bounded dry-run helpers are non-mutating", {
  api <- phase17_test_load_contract()
  capture <- api$phase17_captured_launchctl()
  capture$call("bootout", "gui/501/com.xgelo.dashboard-update")
  capture$call("print", "gui/501/com.xgelo.competition-dashboards")
  expect_identical(capture$calls(), c(
    "bootout gui/501/com.xgelo.dashboard-update",
    "print gui/501/com.xgelo.competition-dashboards"
  ))
  dry <- api$phase17_bounded_dry_run(c("--dry-run", "--fixture-root", "/tmp/fixture"))
  expect_true(dry$valid && dry$dry_run && dry$bounded && !dry$mutation)
  expect_error(api$phase17_bounded_dry_run(""), "non-empty")
  expect_true(file.exists(file.path(phase17_test_project_root, "scripts/com.xgelo.dashboard-update.plist")))
})

test_that("the eight UI state categories and contract prohibitions are named", {
  api <- phase17_test_load_contract()
  expect_identical(api$phase17_ui_state_ids(), c(
    "empty_pre_draw", "loading_refresh_pending", "error_refresh_blocked", "populated",
    "partial", "overflow", "zero_one_many", "long_text"
  ))
  expect_length(api$phase17_section_ids(), 8L)
  expect_true(all(c("pre_draw", "unavailable", "unresolved", "revision_blocked") %in%
                    api$phase17_lifecycle_states()))
  expect_true(all(c("raw source", "score distribution", "refresh history", "invented") %in%
                    tolower(paste(c("No raw source publication", "No score distribution publication",
                                    "No refresh history publication", "No invented probabilities"), collapse = " "))))
})
