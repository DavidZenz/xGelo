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
                           "No rows match the selected filters", "overflow-wrap:anywhere", "data-filter-group",
                           "data-filter-team", "data-filter-matchday", "data-filter-status", "===", "teams.includes"),
                         grepl, logical(1), x = html, fixed = TRUE)))
  expect_true(grepl("All sections", html, fixed = TRUE))
  expect_true(grepl("All teams", html, fixed = TRUE))
  expect_true(grepl("All matchdays", html, fixed = TRUE))
  expect_true(grepl("All statuses", html, fixed = TRUE))
  expect_identical(filtered$metadata, payload$metadata)
  expect_identical(filtered$sections$standings, payload$sections$standings)
  long <- payload
  long$metadata$source_bundle_id <- paste(rep("long-source-id", 30L), collapse = "-")
  long$metadata$warnings <- paste(rep("long warning reason", 40L), collapse = " ")
  long_html <- api$render_phase17_dashboard(long)
  expect_true(grepl("long-source-id", long_html, fixed = TRUE))
  expect_true(grepl("overflow-wrap:anywhere", long_html, fixed = TRUE))
})

test_that("atomic batch|inventory|hash|size|rollback|idempotency", {
  api <- phase17_test_load_contract()
  sys.source(file.path(phase17_test_project_root, "R/dashboard/publication.R"), api)
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  root <- tempfile("phase17-transaction-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  candidate_parent <- file.path(root, "staging")
  dir.create(candidate_parent, recursive = TRUE)
  candidate <- file.path(candidate_parent, "candidate")
  bundles <- setNames(lapply(api$phase17_editions(), api$phase17_fixture_bundle), api$phase17_editions())
  batch_id <- api$phase17_batch_identity(bundles = bundles)
  materialized <- script$phase17_materialize_routes(bundles, candidate, batch_id)
  script$phase17_write_batch_envelope(materialized$batch_root, materialized$payloads,
                                      materialized$routes, batch_id)
  expect_length(api$phase17_expected_public_inventory(), 10L)
  expect_silent(api$phase17_validate_batch_envelope(materialized$batch_root, expected_batch_id = batch_id))
  expect_identical(api$phase17_json_read(file.path(materialized$batch_root, "nations-league/current.json"))$batch_id,
                   api$phase17_json_read(file.path(materialized$batch_root, "euro-qualifying/current.json"))$batch_id)
  extra <- file.path(materialized$batch_root, "logs/refresh.log")
  dir.create(dirname(extra), recursive = TRUE)
  writeLines("forbidden", extra)
  expect_error(api$phase17_validate_batch_envelope(materialized$batch_root), "prohibited|inventory")
  unlink(dirname(extra), recursive = TRUE, force = TRUE)

  public <- file.path(candidate_parent, "public")
  dir.create(public, recursive = TRUE)
  incumbent_path <- file.path(public, "incumbent.txt")
  writeBin(charToRaw("incumbent bytes"), incumbent_path)
  incumbent <- api$phase17_snapshot_bytes(incumbent_path, root = public)
  expect_error(api$phase17_promote_batch(materialized$batch_root, public, injectors = list(promotion = function() stop("Injected"))), "Injected")
  expect_true(api$phase17_snapshot_equal(incumbent, api$phase17_snapshot_bytes(incumbent_path, root = public)))
  dir.create(file.path(root, ".phase17-batch.lock"))
  expect_error(api$phase17_with_batch_lock(root, TRUE), "lock collision")
  unlink(file.path(root, ".phase17-batch.lock"), recursive = TRUE, force = TRUE)
})

test_that("exact gate order|dry run|fail closed|prior phase contracts", {
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  callback_names <- character()
  callbacks <- list(
    phase13_validate_source_bundle = function(arguments) callback_names <<- c(callback_names, "source"),
    phase14_resolve_approved_release = function(arguments) callback_names <<- c(callback_names, "release"),
    phase17_validate_probability_inputs = function(arguments) callback_names <<- c(callback_names, "probability")
  )
  result <- script$phase17_refresh_main(c("--dry-run", "--fixture-root", phase17_test_project_root, "--skip-git"))
  result_with_callbacks <- script$phase17_refresh_main(c("--dry-run", "--fixture-root", phase17_test_project_root, "--skip-git"), callbacks = callbacks)
  labels <- vapply(result$trace, `[[`, character(1), "label")
  expect_identical(labels, c(
    "phase17_git_preflight", "phase13_source", "phase13_snapshot", "phase13_registry",
    "phase14_shared_preflight", "phase14_state_candidate", "phase14_fixture_forecasts",
    "phase12_approved_selector", "phase15_nl_builder", "phase15_nl_validator",
    "phase16_euro_source", "phase16_euro_activation", "phase16_euro_builder",
    "phase16_euro_validator", "phase17_probability", "phase17_freshness", "phase15_replay",
    "phase16_replay", "phase16_euro_replay_child", "phase17_run_browser_gate",
    "phase17_run_regression_gate", "envelope"
  ))
  expect_true(result$dry_run)
  expect_true(all(c("source", "release", "probability") %in% callback_names))
  expect_true(result_with_callbacks$dry_run)
  expect_length(result$inventory, 10L)
  for (failure in c("source", "rules", "probability", "replay", "browser", "manifest", "hash")) {
    expect_error(script$phase17_refresh_main(c("--dry-run", "--fixture-root", phase17_test_project_root,
                                               "--skip-git", "--gate-failure", failure)),
                 paste0("Injected Phase 17 ", failure))
  }
  expect_identical(script$phase17_run_regression_gate(execute = FALSE)$commands[[1L]],
                   "scripts/build_euro_qualifying_outcomes.R --replay-check")
  expect_identical(script$phase17_run_regression_gate(execute = FALSE)$environment$PHASE17_IN_REGRESSION_GATE, "1")
})

test_that("route rendering|shared renderer|route manifests|current pointers", {
  api <- phase17_test_load_contract()
  sys.source(file.path(phase17_test_project_root, "R/dashboard/publication.R"), api)
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  root <- tempfile("phase17-routes-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  bundles <- setNames(lapply(api$phase17_editions(), api$phase17_fixture_bundle), api$phase17_editions())
  materialized <- script$phase17_materialize_routes(bundles, root, script$phase17_batch_identity(bundles = bundles))
  expect_true(file.exists(file.path(materialized$batch_root, "nations-league/index.html")))
  expect_true(file.exists(file.path(materialized$batch_root, "euro-qualifying/payload.json")))
  expect_silent(script$phase17_write_batch_envelope(materialized$batch_root, materialized$payloads,
                                                    materialized$routes, script$phase17_batch_identity(bundles = bundles)))
  expect_silent(api$phase17_validate_batch_envelope(materialized$batch_root))
  payload_bytes <- readBin(file.path(materialized$batch_root, "euro-qualifying/payload.json"), what = "raw", n = file.info(file.path(materialized$batch_root, "euro-qualifying/payload.json"))$size)
  expect_true(grepl("pre_draw", rawToChar(payload_bytes), fixed = TRUE))
})

test_that("launchd|Safari policy|browser smoke|scheduler conflict", {
  api <- phase17_test_load_contract()
  new_plist <- api$phase17_validate_plist(file.path(phase17_test_project_root, "scripts/com.xgelo.competition-dashboards.plist"))
  old_plist <- api$phase17_validate_plist(file.path(phase17_test_project_root, "scripts/com.xgelo.dashboard-update.plist"))
  expect_true(new_plist$valid && old_plist$valid)
  expect_identical(new_plist$label, "com.xgelo.competition-dashboards")
  expect_true(all(c("/opt/homebrew/bin/Rscript", "--vanilla", "/Users/davidzenz/R/xGelo/scripts/refresh_competition_dashboards.R") %in% unlist(new_plist$arguments)))
  expect_identical(old_plist$label, "com.xgelo.dashboard-update")
  expect_true(grepl("Disabled", paste(readLines(file.path(phase17_test_project_root, "scripts/com.xgelo.dashboard-update.plist")), collapse = " "), fixed = TRUE))
})

test_that("Safari policy", {
  api <- phase17_test_load_contract()
  ready <- api$phase17_probe_safari_capability(version_output = "Included with Safari 26.5.2")
  expect_true(ready$available && ready$automated_only)
  expect_identical(ready$runner, "safari-webdriver")
  expect_identical(ready$status, "ready")
  for (case in list(
    api$phase17_probe_safari_capability(enabled = FALSE),
    api$phase17_probe_safari_capability(version_output = "SafariDriver 25.0.0"),
    api$phase17_probe_safari_capability(driver = "/usr/bin/safaridriver")
  )) expect_false(case$available)
  expect_false(grepl("install|enable|manual", tolower(paste(readLines(file.path(phase17_test_project_root, "scripts/auto_update_competition_dashboards.sh")), collapse = " "))))
})

test_that("browser smoke", {
  api <- phase17_test_load_contract()
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_nations_league.R"), script)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/payload_euro.R"), script)
  sys.source(file.path(phase17_test_project_root, "R/dashboard/renderer.R"), script)
  root <- tempfile("phase17-browser-"); dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  bundles <- setNames(lapply(api$phase17_editions(), api$phase17_fixture_bundle), api$phase17_editions())
  materialized <- script$phase17_materialize_routes(bundles, root, "phase17-browser-batch")
  capability <- api$phase17_probe_safari_capability(version_output = "SafariDriver 26.5.2")
  result <- script$phase17_run_browser_gate(materialized$batch_root, capability = capability)
  expect_true(result$valid && result$automated_only)
  expect_identical(result$status, "passed")
  expect_identical(result$viewports$desktop, c(1440L, 900L))
  expect_identical(result$viewports$mobile, c(390L, 844L))
  expect_error(script$phase17_run_browser_gate(materialized$batch_root, capability = capability, viewports = list(desktop = c(1L, 1L), mobile = c(2L, 2L))), "viewport")
})

test_that("scheduler conflict", {
  api <- phase17_test_load_contract()
  capture <- api$phase17_captured_launchctl()
  capture$call("bootout", "gui/501/com.xgelo.dashboard-update")
  capture$call("disable", "gui/501/com.xgelo.dashboard-update")
  capture$call("bootstrap", "gui/501", "com.xgelo.competition-dashboards.plist")
  capture$call("print", "gui/501/com.xgelo.competition-dashboards")
  capture$call("print-disabled", "gui/501/com.xgelo.dashboard-update")
  expect_identical(capture$calls(), c(
    "bootout gui/501/com.xgelo.dashboard-update",
    "disable gui/501/com.xgelo.dashboard-update",
    "bootstrap gui/501 com.xgelo.competition-dashboards.plist",
    "print gui/501/com.xgelo.competition-dashboards",
    "print-disabled gui/501/com.xgelo.dashboard-update"
  ))
  expect_false(grepl("cron|watcher", tolower(paste(readLines(file.path(phase17_test_project_root, "scripts/com.xgelo.competition-dashboards.plist")), collapse = " "))))
})

test_that("regression|Git preflight|exact allowlist|push failure|no mutation", {
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  gate <- script$phase17_run_regression_gate(execute = FALSE)
  expect_true(gate$valid && identical(gate$status, "passed"))
  expect_identical(gate$environment$PHASE17_IN_REGRESSION_GATE, "1")
  expect_identical(gate$commands[[1L]], "scripts/build_euro_qualifying_outcomes.R --replay-check")
  expect_match(paste(gate$commands, collapse = "\n"), "test_phase17_dashboards")
})

test_that("Git preflight", {
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  root <- tempfile("phase17-git-"); dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  system2("git", c("init", "-q", root))
  writeLines("clean", file.path(root, "README"))
  system2("git", c("-C", root, "add", "README"))
  system2("git", c("-C", root, "-c", "user.email=phase17@example.test", "-c", "user.name=Phase17", "commit", "-q", "-m", "fixture"))
  result <- script$phase17_git_preflight(root, fetch = FALSE)
  expect_true(result$valid && identical(result$status, "clean_upstream_aligned"))
  writeLines("dirty", file.path(root, "dirty.txt"))
  expect_error(script$phase17_git_preflight(root, fetch = FALSE), "clean worktree")
})

test_that("exact allowlist", {
  api <- phase17_test_load_contract()
  allowlist <- api$phase17_expected_git_allowlist()
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  expect_silent(script$phase17_validate_git_allowlist(allowlist, allowlist))
  expect_error(script$phase17_validate_git_allowlist(c(allowlist, "logs/refresh.log"), allowlist), "exact allowlist")
  expect_error(script$phase17_validate_git_allowlist(c(allowlist, "data/competition/raw/source.json"), allowlist), "exact allowlist")
  expect_false(any(grepl("raw|refresh_batches|score_distributions|logs", allowlist)))
  wrapper <- paste(readLines(file.path(phase17_test_project_root, "scripts/auto_update_competition_dashboards.sh")), collapse = "\n")
  expect_true(all(vapply(c("--emit-git-allowlist", "git add --", "git push", "--skip-push"), grepl, logical(1), x = wrapper, fixed = TRUE)))
})

test_that("push failure", {
  wrapper <- paste(readLines(file.path(phase17_test_project_root, "scripts/auto_update_competition_dashboards.sh")), collapse = "\n")
  expect_true(grepl("push failed", wrapper, fixed = TRUE))
  expect_false(grepl("git push --force|git push -f", wrapper))
  expect_true(grepl("no retry", wrapper, fixed = TRUE))
})

test_that("no mutation", {
  api <- phase17_test_load_contract()
  script <- new.env(parent = globalenv())
  sys.source(file.path(phase17_test_project_root, "scripts/refresh_competition_dashboards.R"), script)
  result <- script$phase17_refresh_main(c("--dry-run", "--fixture-root", phase17_test_project_root, "--skip-git"))
  expect_true(result$valid && result$dry_run)
  expect_true(all(vapply(result$trace, function(item) identical(item$status, "pass"), logical(1))))
  expect_identical(sort(result$inventory), sort(api$phase17_expected_git_allowlist()[api$phase17_expected_git_allowlist() %in% api$phase17_expected_public_inventory()]))
})
