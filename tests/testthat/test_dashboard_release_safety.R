# These tests use an isolated shell harness. No live acquisition, publication,
# Git commit, WebDriver session, or network access is permitted here.
release_safety_root <- local({
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(root, "scripts/auto_update_nations_league_dashboard.sh"))) {
    parent <- dirname(root)
    if (identical(parent, root)) stop("Cannot find dashboard project root")
    root <- parent
  }
  root
})

release_safety_api <- function() {
  api <- new.env(parent = globalenv())
  sys.source(file.path(release_safety_root, "scripts/refresh_competition_dashboards.R"), api)
  api
}

release_safety_harness <- function() {
  root <- tempfile("dashboard-updater-")
  dir.create(file.path(root, "scripts"), recursive = TRUE)
  dir.create(file.path(root, "bin"))
  dir.create(file.path(root, "docs", "competitions"), recursive = TRUE)
  file.copy(file.path(release_safety_root, "scripts/auto_update_nations_league_dashboard.sh"), file.path(root, "scripts"))
  writeLines("incumbent accepted publication", file.path(root, "docs", "competitions", "sentinel"))
  dir.create(file.path(root, "outputs/benchmarks/nations_league_scale"), recursive = TRUE)
  writeLines("mock receipt", file.path(root, "outputs/benchmarks/nations_league_scale/measurement-100000.csv"))
  writeLines(c("#!/usr/bin/env bash", 'printf "%s\\n" "$*" >> "$HARNESS_ROOT/r-calls"',
    'case "$*" in',
    '  *acquire_uefa_snapshot.R*--dry-run*)',
    paste0('    echo "source_bundle_sha256=', strrep("a", 64L), ' accepted_content_signature=', strrep("b", 64L), '" ;;'),
    paste0('  *phase13_source_required_resource_types*) printf "', strrep("b", 64L), '" ;;'),
    '  *phase17_validate_scale_evidence*) test -f "$HARNESS_ROOT/outputs/benchmarks/nations_league_scale/measurement-100000.csv" || { echo "missing benchmark receipt" >&2; exit 23; } ;;',
    '  *phase17_refresh_main*) echo "injected browser or regression failure" >&2; exit 19 ;;',
    'esac'), file.path(root, "bin", "Rscript"))
  writeLines(c("#!/usr/bin/env bash", 'printf "%s\\n" "$*" >> "$HARNESS_ROOT/git-calls"',
    'case "$1" in rev-parse) echo same-head ;; esac'), file.path(root, "bin", "git"))
  Sys.chmod(file.path(root, "bin", c("Rscript", "git")), "0755")
  root
}

release_safety_run <- function(root, args = character()) {
  result <- suppressWarnings(system2("/bin/bash", c(shQuote(file.path(root, "scripts/auto_update_nations_league_dashboard.sh")), shQuote(args)),
    stdout = TRUE, stderr = TRUE,
    env = c(paste0("XGELO_RSCRIPT=", shQuote(file.path(root, "bin", "Rscript"))),
            paste0("HARNESS_ROOT=", shQuote(root)),
            paste0("PATH=", shQuote(paste(file.path(root, "bin"), Sys.getenv("PATH"), sep = ":"))))))
  list(status = if (is.null(attr(result, "status"))) 0L else attr(result, "status"), output = paste(result, collapse = "\n"))
}

test_that("nightly minimum is enforced before any source or publication work", {
  root <- release_safety_harness(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  result <- release_safety_run(root, "--simulations=100")
  expect_identical(result$status, 2L)
  expect_match(result$output, "at least 100000")
  expect_false(file.exists(file.path(root, "r-calls")))
  dry <- release_safety_run(root, c("--dry-run", "--simulations=100"))
  expect_identical(dry$status, 0L)
  expect_match(dry$output, "No Nations League source change")
})

test_that("nightly force rebuild reaches gates and preserves incumbent on rejection", {
  root <- release_safety_harness(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  sentinel <- file.path(root, "docs/competitions/sentinel")
  before <- readBin(sentinel, "raw", n = file.info(sentinel)$size)
  ordinary <- release_safety_run(root)
  expect_identical(ordinary$status, 0L)
  expect_false(file.exists(file.path(root, "git-calls")))
  forced <- release_safety_run(root, c("--force-rebuild", "--skip-push"))
  expect_identical(forced$status, 19L)
  expect_match(forced$output, "injected browser or regression failure")
  expect_identical(readBin(sentinel, "raw", n = file.info(sentinel)$size), before)
  calls <- readLines(file.path(root, "r-calls"))
  expect_true(any(grepl("--simulations 100000 --workers 4 --seed 15017", calls, fixed = TRUE)))
  expect_true(any(grepl("phase17_refresh_main(external_git_owner = TRUE", calls, fixed = TRUE)))
  expect_false(any(grepl("commit|push|add --", readLines(file.path(root, "git-calls")))))
  expect_false(dir.exists(file.path(root, ".nations-league-update.lock")))
})

test_that("updater lock rejects overlaps and never removes another owner's lock", {
  root <- release_safety_harness(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  lock <- file.path(root, ".nations-league-update.lock"); dir.create(lock)
  writeLines("another-process", file.path(lock, "pid"))
  result <- release_safety_run(root, "--dry-run")
  expect_identical(result$status, 1L)
  expect_match(result$output, "already running")
  expect_identical(readLines(file.path(lock, "pid")), "another-process")
  expect_false(file.exists(file.path(root, "r-calls")))
})

test_that("release regression suites are unfiltered and reject failures", {
  api <- release_safety_api()
  gate <- api$phase17_run_regression_gate(execute = FALSE)
  expect_false(any(grepl("desc =", gate$commands, fixed = TRUE)))
  expect_true(all(grepl("zero assertions", gate$commands[-1L], fixed = TRUE)))
  expect_match(paste(gate$commands, collapse = " "), "test_phase21_dashboard_publication")
  expect_error(api$phase17_run_regression_gate(execute = TRUE, runner = function(...) 7L), "regression gate failed")
  calls <- 0L
  expect_error(api$phase17_run_regression_gate(execute = TRUE, runner = function(...) {
    calls <<- calls + 1L
    if (calls == 2L) structure("Required dashboard suite failed or executed zero assertions", status = 1L) else character()
  }), "zero assertions")
  expect_identical(calls, 2L)
})

test_that("an actually empty required suite cannot pass the release gate", {
  api <- release_safety_api()
  root <- tempfile("empty-regression-")
  dir.create(file.path(root, "scripts"), recursive = TRUE)
  dir.create(file.path(root, "tests/testthat"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines('if (!nzchar(Sys.which("Rscript"))) stop("nested Rscript PATH unavailable")', file.path(root, "scripts/build_euro_qualifying_outcomes.R"))
  writeLines("# intentionally no test_that blocks", file.path(root, "tests/testthat/test_phase13_publication_hashes.R"))
  expect_error(api$phase17_run_regression_gate(project_root = root, execute = TRUE), "zero assertions")
})

test_that("browser unavailable or rejected DOM evidence fails the candidate gate", {
  api <- release_safety_api()
  expect_error(api$phase17_run_browser_gate(tempdir(), capability = list(available = FALSE)), "browser gate unavailable")
  stage <- tempfile("gate-stage-"); dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (route in c("nations-league", "euro-qualifying")) {
    dir.create(file.path(stage, route)); writeLines("<html></html>", file.path(stage, route, "index.html"))
  }
  capability <- list(available = TRUE, automated_only = TRUE, runner = "safari-webdriver", driver = api$phase17_safari_driver_path, version = api$phase17_safari_version)
  expect_error(api$phase17_run_browser_gate(stage, capability = capability,
    browser_runner = function(...) list(valid = FALSE, failure_reason = "viewport mismatch")), "DOM/ARIA")
})


test_that("missing scale certification blocks rebuild before accepted data mutation", {
  root <- release_safety_harness(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  unlink(file.path(root, "outputs/benchmarks/nations_league_scale/measurement-100000.csv"))
  expect_identical(release_safety_run(root)$status, 0L) # unchanged remains a no-op
  forced <- release_safety_run(root, "--force-rebuild")
  expect_identical(forced$status, 23L)
  expect_match(forced$output, "missing benchmark receipt")
  calls <- readLines(file.path(root, "r-calls"))
  expect_false(any(grepl("--publish-accepted|--write", calls)))
  expect_false(file.exists(file.path(root, "git-calls")))
  expect_false(dir.exists(file.path(root, ".nations-league-update.lock")))
})

test_that("scale certification binds measured count, validation, lineage and implementation", {
  api <- release_safety_api()
  receipt <- tempfile(fileext = ".csv"); on.exit(unlink(c(receipt, paste0(receipt, ".resources.json"))), add = TRUE)
  valid <- data.frame(simulations = 100000L, seed = 15017L, workers = 4L,
    source_bundle_id = "accepted-benchmark-source", state_manifest_sha256 = strrep("a", 64L),
    elapsed_seconds = 120, validated = TRUE,
    simulation_code_sha256 = digest::digest(file = file.path(release_safety_root, "R/competition/uefa_nations_league_simulation.R"), algo = "sha256"),
    execution_code_sha256 = digest::digest(file = file.path(release_safety_root, "R/common/simulation_execution.R"), algo = "sha256"),
    reducer_code_sha256 = digest::digest(file = file.path(release_safety_root, "R/competition/uefa_nations_league_streaming.R"), algo = "sha256"),
    implementation_sha256 = digest::digest(api$simulation_repository_identity(release_safety_root), algo = "sha256"))
  check <- function(value) {
    write.csv(value, receipt, row.names = FALSE)
    jsonlite::write_json(list(status = "passed", authority = "accepted_national", production_certified = TRUE,
      count = 100000, implementation_sha256 = valid$implementation_sha256,
      measurement_sha256 = digest::digest(file = receipt, algo = "sha256"),
      wall_seconds = 150, physical_memory_bytes = 16000000000, peak_process_tree_rss_bytes = 4000000000),
      paste0(receipt, ".resources.json"), auto_unbox = TRUE)
    api$phase17_validate_scale_evidence(receipt, 100000L, 4L, release_safety_root)
  }
  expect_true(check(valid)$valid)
  for (field in c("simulations", "seed", "workers", "elapsed_seconds", "validated", "source_bundle_id", "state_manifest_sha256", "simulation_code_sha256", "execution_code_sha256", "reducer_code_sha256", "implementation_sha256")) {
    bad <- valid
    bad[[field]] <- switch(field, simulations = 1000L, seed = 1L, workers = 1L,
      elapsed_seconds = 0, validated = FALSE, source_bundle_id = "", state_manifest_sha256 = "", simulation_code_sha256 = strrep("0", 64L), execution_code_sha256 = strrep("0", 64L), reducer_code_sha256 = strrep("0", 64L), implementation_sha256 = strrep("0", 64L))
    expect_error(check(bad), "scale validation required", info = field)
  }
  check(valid)
  resources <- jsonlite::fromJSON(paste0(receipt, ".resources.json"))
  for (field in c("wall_seconds", "peak_process_tree_rss_bytes", "measurement_sha256")) {
    bad <- resources
    bad[[field]] <- switch(field, wall_seconds = 7201, peak_process_tree_rss_bytes = 8000000000, measurement_sha256 = strrep("0", 64L))
    jsonlite::write_json(bad, paste0(receipt, ".resources.json"), auto_unbox = TRUE)
    expect_error(api$phase17_validate_scale_evidence(receipt, 100000L, 4L, release_safety_root), "scale validation required")
  }
  write.csv(valid, receipt, row.names = FALSE)
  expect_error(api$phase17_validate_scale_evidence(receipt, 200000L, 4L, release_safety_root), "scale validation required")
})
