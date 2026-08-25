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
  expect_error(api$phase17_load_fixture_bundle(root, "forged-edition"), "Unknown")
  expect_error(api$phase17_resolve_path(root, "../escape"), "traversal")
})

test_that("canonical bytes and raw snapshots are stable and preserve incumbent identity", {
  api <- phase17_test_load_contract()
  first <- api$phase17_canonical_bytes(list(b = 2, a = "text"))
  second <- api$phase17_canonical_bytes(list(b = 2, a = "text"))
  expect_identical(first, second)
  expect_length(api$phase17_sha256_raw(first), 1L)
  expect_equal(nchar(api$phase17_sha256_raw(first)), 64L)
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
  exact <- phase17_test_write_bytes(file.path(root, "exact.bin"), raw(api$phase17_max_public_file_bytes))
  expect_silent(api$phase17_validate_byte_limits(exact))
  over_file <- phase17_test_write_bytes(file.path(root, "over.bin"), raw(api$phase17_max_public_file_bytes + 1L))
  expect_error(api$phase17_validate_byte_limits(over_file), "file exceeds")
  batch <- vapply(seq_len(4L), function(i) phase17_test_write_bytes(
    file.path(root, paste0("batch-", i, ".bin")), raw(api$phase17_max_public_file_bytes)
  ), character(1))
  expect_equal(api$phase17_validate_byte_limits(batch, max_file_bytes = api$phase17_max_batch_bytes)$total_bytes,
               api$phase17_max_batch_bytes)
  fifth <- phase17_test_write_bytes(file.path(root, "batch-over.bin"), raw(1L))
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
  prohibition_text <- tolower(paste(c("No raw source publication", "No score distribution publication",
                                      "No refresh history publication", "No invented probabilities"), collapse = " "))
  expect_true(all(vapply(c("raw source", "score distribution", "refresh history", "invented"),
                         grepl, logical(1), x = prohibition_text, fixed = TRUE)))
})

test_that("phase17_tracer", {
  api <- phase17_test_load_contract()
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_nations_league.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_euro.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/renderer.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/publication.R"), api)
  nl <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  euro <- api$phase17_fixture_bundle("uefa_euro_2028_qualifying")
  nl_payload <- api$phase17_payload_nations_league(nl)
  euro_payload <- api$phase17_payload_euro(euro)
  expect_identical(names(nl_payload$sections), api$phase17_section_ids())
  expect_identical(names(euro_payload$sections), api$phase17_section_ids())
  expect_identical(api$phase17_payload_nations_league(nl), nl_payload)
  expect_identical(euro_payload$metadata$lifecycle_state, "pre_draw")
  expect_true(all(vapply(euro_payload$sections[names(euro_payload$sections) != "overview"],
                         function(section) section$status == "pre_draw", logical(1))))
  nl_payload$sections$overview$rows <- list(list(name = "<script>alert('x')</script>"))
  rendered <- api$render_phase17_dashboard(nl_payload)
  expect_true(grepl("\\u003cscript\\u003e", rendered, fixed = TRUE))
  expect_false(grepl("<script>alert", rendered, fixed = TRUE))
  expect_true(all(vapply(c("Overview", "Structure", "Standings", "Fixtures", "Results", "Form",
                           "Match forecasts", "Projected outcomes"),
                    grepl, logical(1), x = rendered, fixed = TRUE)))
  root <- tempfile("phase17-route-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  route <- api$phase17_render_route(nl_payload, root)
  expect_length(route$files, 4L)
  api$phase17_validate_published_route(nl_payload, file.path(root, "docs/competitions/nations-league"))
  expect_identical(names(api$phase17_public_route_targets(root)), api$phase17_expected_public_inventory()[1:8])
})

test_that("payload sections|metadata|pre_draw|blocked|credits", {
  api <- phase17_test_load_contract()
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_nations_league.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_euro.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/renderer.R"), api)
  nl <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  nl$artifacts$structure <- data.frame(league = "League A", stringsAsFactors = FALSE)
  nl$artifacts$standings <- data.frame(group_id = "A", team = "Alpha", points = 3L, stringsAsFactors = FALSE)
  nl$artifacts$fixtures <- data.frame(group_id = "A", matchday = 1L, home_team = "Alpha", away_team = "Beta", status = "scheduled", stringsAsFactors = FALSE)
  nl$artifacts$results <- data.frame(group_id = "A", home_team = "Alpha", away_team = "Beta", status = "final", score = "2-1", stringsAsFactors = FALSE)
  nl$artifacts$form <- data.frame(team = "Alpha", form = "W", stringsAsFactors = FALSE)
  nl$artifacts$forecasts <- data.frame(home_team = "Alpha", away_team = "Beta", status = "available", home_probability = 0.5, stringsAsFactors = FALSE)
  nl$artifacts$projected_outcomes <- data.frame(team = "Alpha", outcome = "Title path", stringsAsFactors = FALSE)
  payload <- api$phase17_payload_nations_league(nl)
  html <- api$render_phase17_dashboard(payload)
  expect_identical(names(payload$sections), api$phase17_section_ids())
  expect_true(all(vapply(api$phase17_section_ids(), grepl, logical(1), x = html, fixed = TRUE)))
  expect_true(all(vapply(c("dashboard-data", "dashboard-status", "source-lineage", "data-credits",
                           "filter-section", "filter-league-group", "filter-team", "filter-matchday",
                           "filter-status", "clear-filters", "filter-result-count"),
                         grepl, logical(1), x = html, fixed = TRUE)))
  expect_true(all(vapply(c("Batch", "Last accepted refresh", "Source confidence", "Model release",
                           "Simulation seed", "Simulation count", "Data credits"),
                         grepl, logical(1), x = html, fixed = TRUE)))
  hostile <- payload
  hostile$sections$overview$rows <- list(list(note = "<script>alert('x')</script>"))
  hostile$credits$source_url <- "https://example.test/?q=<bad>"
  hostile_html <- api$render_phase17_dashboard(hostile)
  expect_false(grepl("<script>alert", hostile_html, fixed = TRUE))
  expect_true(grepl("\\u003cscript\\u003e", hostile_html, fixed = TRUE))
  euro <- api$phase17_payload_euro(api$phase17_fixture_bundle("uefa_euro_2028_qualifying"))
  euro_html <- api$render_phase17_dashboard(euro)
  expect_true(grepl("Pre-draw", euro_html, fixed = TRUE))
  expect_false(grepl("fixture-001", euro_html, fixed = TRUE))
  blocked <- nl
  blocked$lifecycle_state <- "revision_blocked"
  blocked$warnings <- "Candidate rules failed validation."
  blocked$showing_last_accepted_snapshot <- TRUE
  blocked_payload <- api$phase17_payload_nations_league(blocked)
  blocked_html <- api$render_phase17_dashboard(blocked_payload)
  expect_true(grepl("Refresh blocked", blocked_html, fixed = TRUE))
  expect_true(grepl("Showing last accepted snapshot", blocked_html, fixed = TRUE))
  expect_true(grepl("Candidate rules failed validation", blocked_html, fixed = TRUE))
})

test_that("filters|responsive|accessibility|zero-one-many|long-text", {
  api <- phase17_test_load_contract()
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_nations_league.R"), api)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/renderer.R"), api)
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  bundle$artifacts$fixtures <- data.frame(
    group_id = c("A", "B"), matchday = c(1L, 2L), home_team = c("Alpha", "Beta"),
    away_team = c("Beta", "Gamma"), status = c("scheduled", "final"), stringsAsFactors = FALSE
  )
  payload <- api$phase17_payload_nations_league(bundle)
  filtered <- api$phase17_filter_payload(payload, list(league_or_group = "A", team = "Alpha",
                                                        matchday = "1", fixture_status = "scheduled"))
  expect_equal(length(filtered$sections$fixtures$rows), 1L)
  expect_equal(length(payload$sections$fixtures$rows), 2L)
  no_match <- api$phase17_filter_payload(payload, list(team = "Missing"))
  expect_equal(no_match$filter_result_count, 0L)
  html <- api$render_phase17_dashboard(payload)
  expect_true(all(vapply(c("<select", "aria-label=\"Dashboard filters\"", "aria-live=\"polite\"",
                           "focus-visible", "overflow-x:auto", "prefers-reduced-motion", "Clear filters",
                           "No rows match the selected filters", "overflow-wrap:anywhere"),
                         grepl, logical(1), x = html, fixed = TRUE)))
  expect_true(grepl("All sections", html, fixed = TRUE))
  expect_true(grepl("All teams", html, fixed = TRUE))
  expect_true(grepl("All matchdays", html, fixed = TRUE))
  expect_true(grepl("All statuses", html, fixed = TRUE))
  long <- payload
  long$metadata$source_bundle_id <- paste(rep("long-source-id", 30L), collapse = "-")
  long$metadata$warnings <- paste(rep("long warning reason", 40L), collapse = " ")
  long_html <- api$render_phase17_dashboard(long)
  expect_true(grepl("long-source-id", long_html, fixed = TRUE))
  expect_true(grepl("overflow-wrap:anywhere", long_html, fixed = TRUE))
})
