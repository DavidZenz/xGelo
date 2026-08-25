#!/usr/bin/env Rscript

# Bounded Phase 17 coordinator.  The child competition builders remain the
# authorities for source, rules, forecasts, and outcome lineage; this file
# only adapts their accepted contracts into one public transaction.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left
phase17_cli_file <- commandArgs(trailingOnly = FALSE)
phase17_cli_file <- phase17_cli_file[grepl("^--file=", phase17_cli_file)]
phase17_cli_file <- sub("^--file=", "", if (length(phase17_cli_file)) phase17_cli_file[[1L]] else "scripts/refresh_competition_dashboards.R")
phase17_cli_root <- normalizePath(file.path(dirname(phase17_cli_file), ".."), winslash = "/", mustWork = FALSE)
if (!file.exists(file.path(phase17_cli_root, "R/dashboard/payload_contract.R"))) {
  phase17_cli_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(phase17_cli_root, "R/dashboard/payload_contract.R"))) break
    parent <- dirname(phase17_cli_root)
    if (identical(parent, phase17_cli_root)) break
    phase17_cli_root <- parent
  }
}
if (!file.exists(file.path(phase17_cli_root, "R/dashboard/payload_contract.R"))) stop("Could not locate xGelo project root", call. = FALSE)
phase17_cli_env <- environment()

phase17_cli_source <- function(relative) {
  sys.source(file.path(phase17_cli_root, relative), phase17_cli_env)
}
phase17_cli_source("R/dashboard/payload_contract.R")
phase17_cli_source("R/dashboard/payload_nations_league.R")
phase17_cli_source("R/dashboard/payload_euro.R")
phase17_cli_source("R/dashboard/renderer.R")
phase17_cli_source("R/dashboard/publication.R")

phase17_cli_scalar <- function(value, option) {
  if (is.null(value) || length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    stop("Option ", option, " requires one non-empty value.", call. = FALSE)
  }
  as.character(value[[1L]])
}

phase17_parse_refresh_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(dry_run = FALSE, fixture_root = phase17_cli_root, public_root = file.path(phase17_cli_root, "docs/competitions"),
                  gate_failure = NULL, skip_git = FALSE, skip_push = FALSE, fixture_mode = FALSE,
                  emit_git_allowlist = FALSE, help = FALSE)
  index <- 1L
  while (index <= length(args)) {
    arg <- as.character(args[[index]])
    if (arg %in% c("--dry-run", "--skip-git", "--skip-push", "--fixture-mode", "--emit-git-allowlist", "--help", "-h")) {
      if (arg == "--dry-run") options$dry_run <- TRUE
      if (arg == "--skip-git") options$skip_git <- TRUE
      if (arg == "--skip-push") options$skip_push <- TRUE
      if (arg == "--fixture-mode") options$fixture_mode <- TRUE
      if (arg == "--emit-git-allowlist") options$emit_git_allowlist <- TRUE
      if (arg %in% c("--help", "-h")) options$help <- TRUE
      index <- index + 1L
      next
    }
    matched <- regexec("^--(fixture-root|public-root|gate-failure)=(.*)$", arg)
    pieces <- regmatches(arg, matched)[[1L]]
    if (length(pieces) == 3L) {
      field <- switch(pieces[[2L]], `fixture-root` = "fixture_root", `public-root` = "public_root", `gate-failure` = "gate_failure")
      options[[field]] <- phase17_cli_scalar(pieces[[3L]], paste0("--", pieces[[2L]]))
      index <- index + 1L
      next
    }
    if (arg %in% c("--fixture-root", "--public-root", "--gate-failure")) {
      if (index == length(args)) stop("Option ", arg, " requires a value.", call. = FALSE)
      field <- switch(arg, `--fixture-root` = "fixture_root", `--public-root` = "public_root", `--gate-failure` = "gate_failure")
      index <- index + 1L
      options[[field]] <- phase17_cli_scalar(args[[index]], arg)
      index <- index + 1L
      next
    }
    stop("Unsupported option: ", arg, call. = FALSE)
  }
  if (isTRUE(options$skip_git) && !isTRUE(options$dry_run)) stop("--skip-git is only valid with --dry-run", call. = FALSE)
  if (isTRUE(options$skip_push) && !isTRUE(options$dry_run)) stop("--skip-push is only valid with --dry-run", call. = FALSE)
  if (isTRUE(options$fixture_mode) && !isTRUE(options$dry_run)) stop("--fixture-mode is test-only and requires --dry-run", call. = FALSE)
  options
}

phase17_validate_competition_freshness <- function(bundle, cutoff = Sys.time(), thresholds = list()) {
  retrieved <- phase17_bundle_scalar(bundle, "source_retrieved_at_utc", "")
  threshold <- as.numeric(thresholds$max_age_seconds %||% Inf)
  age <- if (!nzchar(retrieved)) Inf else as.numeric(as.POSIXct(cutoff, tz = "UTC") - as.POSIXct(retrieved, tz = "UTC"))
  valid <- is.finite(age) && age >= 0 && age <= threshold
  list(valid = valid, failure_reason = if (valid) NULL else "source freshness threshold failed",
       gate_trace = list(gate = "phase17_freshness", age_seconds = age, threshold_seconds = threshold))
}

phase17_validate_probability_inputs <- function(bundle, approved_release = NULL) {
  required <- c("simulation_seed", "simulation_count", "forecast_status")
  valid <- is.list(bundle) && all(required %in% names(bundle)) &&
    is.finite(as.numeric(bundle$simulation_seed[[1L]])) && as.numeric(bundle$simulation_count[[1L]]) > 0
  if (!is.null(approved_release)) valid <- valid && is.list(approved_release)
  list(valid = valid, failure_reason = if (valid) NULL else "probability inputs are incomplete",
       gate_trace = list(gate = "phase17_probability", required = required))
}

phase17_detect_browser_capability <- function() {
  phase17_probe_safari_capability()
}

phase17_run_browser_gate <- function(public_root, capability = phase17_detect_browser_capability(), viewports = list(desktop = c(1440L, 900L), mobile = c(390L, 844L)), injector = NULL, browser_runner = NULL) {
  if (is.function(injector)) injector()
  if (!isTRUE(capability$automated_only) || !isTRUE(capability$available) ||
      !identical(capability$runner, "safari-webdriver") ||
      !identical(capability$driver, phase17_safari_driver_path) ||
      !identical(capability$version, phase17_safari_version)) {
    stop("Phase 17 browser gate unavailable: ", capability$failure_reason %||% capability$status, call. = FALSE)
  }
  if (!identical(names(viewports), c("desktop", "mobile")) ||
      !identical(as.integer(viewports$desktop), c(1440L, 900L)) ||
      !identical(as.integer(viewports$mobile), c(390L, 844L))) {
    stop("Phase 17 browser viewport smoke failed", call. = FALSE)
  }
  if (!is.function(browser_runner)) stop("Phase 17 browser gate unavailable: no WebDriver runner", call. = FALSE)
  routes <- c("nations-league", "euro-qualifying")
  checks <- unlist(lapply(routes, function(route) {
    path <- file.path(public_root, route, "index.html")
    if (!file.exists(path)) stop("Phase 17 browser route is missing", call. = FALSE)
    vapply(viewports, function(size) {
      result <- tryCatch(browser_runner(path, as.integer(size[[1L]]), as.integer(size[[2L]])),
                         error = function(error) stop("Phase 17 browser DOM/ARIA smoke failed: ", conditionMessage(error), call. = FALSE))
      if (!is.list(result) || length(result$valid) != 1L || !isTRUE(result$valid)) {
        stop("Phase 17 browser DOM/ARIA smoke failed", call. = FALSE)
      }
      TRUE
    }, logical(1))
  }))
  if (!all(checks)) stop("Phase 17 browser DOM/ARIA smoke failed", call. = FALSE)
  list(valid = TRUE, runner = capability$runner, driver = capability$driver,
       version = capability$version, status = "passed", automated_only = TRUE,
       routes = routes, viewports = viewports)
}

phase17_run_regression_gate <- function(project_root = phase17_cli_root, execute = FALSE, env = Sys.getenv(), injector = NULL, runner = NULL) {
  if (is.function(injector)) injector()
  commands <- c(
    "scripts/build_euro_qualifying_outcomes.R --replay-check",
    "testthat::test_file(\"tests/testthat/test_phase13_publication_hashes.R\", desc = \"phase13 publication hashes\")",
    "testthat::test_file(\"tests/testthat/test_phase13_publication_manifests.R\", desc = \"phase13 publication manifests\")",
    "testthat::test_file(\"tests/testthat/test_phase13_publication_transaction.R\", desc = \"phase13 publication transaction\")",
    "testthat::test_file(\"tests/testthat/test_phase13_publication_integration.R\", desc = \"phase13 publication integration\")",
    "testthat::test_file(\"tests/testthat/test_phase13_refresh_failure.R\", desc = \"phase13 refresh failure\")",
    "testthat::test_file(\"tests/testthat/test_phase15_nations_league.R\", desc = \"phase15 nations league\")",
    "testthat::test_file(\"tests/testthat/test_uefa_nations_league_production.R\", desc = \"UEFA nations league production\")",
    "testthat::test_file(\"tests/testthat/test_phase16_euro_qualifying.R\", desc = \"phase16 euro qualifying\")",
    "testthat::test_file(\"tests/testthat/test_phase17_dashboards.R\", desc = \"phase17 regression\")"
  )
  if (isTRUE(execute)) {
    runner <- runner %||% function(command, args, ...) system2(command, args, ...)
    child_args <- c("--vanilla", "scripts/build_euro_qualifying_outcomes.R", "--edition-id", "uefa_euro_2028_qualifying", "--replay-check")
    for (i in seq_along(commands)) {
      args <- if (i == 1L) child_args else c("--vanilla", "-e", commands[[i]])
      status <- runner("Rscript", args, stdout = TRUE, stderr = TRUE,
                       env = if (i == length(commands)) c(env, PHASE17_IN_REGRESSION_GATE = "1") else env)
      if (!identical(attr(status, "status") %||% 0L, 0L)) stop("Phase 17 regression gate failed: ", commands[[i]], call. = FALSE)
    }
  }
  list(valid = TRUE, status = "passed", commands = commands,
       environment = list(PHASE17_IN_REGRESSION_GATE = "1"))
}

phase17_git_run <- function(args, project_root, capture = TRUE) {
  status <- NULL
  previous <- getwd()
  setwd(project_root)
  on.exit(setwd(previous), add = TRUE)
  output <- system2("git", args, stdout = if (capture) TRUE else "", stderr = if (capture) TRUE else "")
  status <- attr(output, "status") %||% 0L
  list(status = as.integer(status), output = as.character(output))
}

phase17_git_preflight <- function(project_root = phase17_cli_root, fetch = FALSE, require_clean = TRUE) {
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  if (isTRUE(fetch)) {
    fetched <- phase17_git_run(c("fetch", "--quiet"), root)
    if (!identical(fetched$status, 0L)) stop("Phase 17 Git fetch failed", call. = FALSE)
  }
  status <- phase17_git_run(c("status", "--porcelain=v1", "--untracked-files=all"), root)
  if (isTRUE(require_clean) && (status$status != 0L || length(status$output) > 0L)) {
    stop("Phase 17 Git preflight requires a clean worktree", call. = FALSE)
  }
  upstream <- phase17_git_run(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"), root)
  local <- phase17_git_run(c("rev-parse", "@"), root)
  if (local$status != 0L) stop("Phase 17 Git local HEAD is unavailable", call. = FALSE)
  upstream_head <- NA_character_
  upstream_name <- if (length(upstream$output)) trimws(upstream$output[[1L]]) else ""
  if (upstream$status == 0L && nzchar(upstream_name)) {
    remote <- phase17_git_run(c("rev-parse", "@{u}"), root)
    if (remote$status != 0L) stop("Phase 17 Git upstream HEAD is unavailable", call. = FALSE)
    upstream_head <- if (length(remote$output)) trimws(remote$output[[1L]]) else ""
    if (!identical(trimws(local$output[[1L]]), upstream_head)) stop("Phase 17 Git branch is diverged from upstream", call. = FALSE)
  }
  list(valid = TRUE, status = "clean_upstream_aligned", local_head = trimws(local$output[[1L]]),
       upstream = upstream_name, upstream_head = upstream_head, status_lines = character())
}

phase17_git_staged_inventory <- function(project_root = phase17_cli_root) {
  result <- phase17_git_run(c("diff", "--cached", "--name-only", "--diff-filter=ACMRT"), project_root)
  if (result$status != 0L) stop("Phase 17 Git staged inventory could not be read", call. = FALSE)
  sort(unique(trimws(result$output[nzchar(trimws(result$output))])))
}

phase17_validate_git_allowlist <- function(paths, allowlist = phase17_expected_git_allowlist()) {
  actual <- sort(unique(gsub("\\\\", "/", as.character(paths))))
  expected <- sort(unique(as.character(allowlist)))
  if (!identical(actual, expected)) stop("Phase 17 Git staged inventory is not the exact allowlist", call. = FALSE)
  invisible(list(valid = TRUE, allowlist = expected))
}

phase17_materialize_routes <- function(bundles, stage_root, batch_id) {
  if (!identical(sort(names(bundles)), sort(phase17_editions()))) stop("Phase 17 requires both editions", call. = FALSE)
  stage_root <- phase17_project_root(stage_root, create = TRUE)
  payloads <- list(
    uefa_nations_league_2026_27 = phase17_payload_nations_league(bundles[["uefa_nations_league_2026_27"]], batch_id),
    uefa_euro_2028_qualifying = phase17_payload_euro(bundles[["uefa_euro_2028_qualifying"]], batch_id)
  )
  routes <- lapply(payloads, function(payload) phase17_render_route(payload, stage_root, batch_id, route_root = stage_root))
  names(routes) <- names(payloads)
  batch_root <- stage_root
  files <- phase17_batch_files(batch_root)
  list(payloads = payloads, routes = routes, files = files, batch_root = batch_root)
}

phase17_write_batch_envelope <- function(stage_root, payloads, routes, batch_id, generated_at_utc = "2026-08-25T00:00:00Z") {
  route_hashes <- lapply(routes, function(route) route$route_manifest)
  manifest <- list(schema_version = phase17_dashboard_schema_version, batch_id = batch_id,
                   generated_at_utc = generated_at_utc, routes = c("nations-league", "euro-qualifying"),
                   inventory = phase17_expected_public_inventory(), route_manifests = route_hashes,
                   statuses = vapply(payloads, function(payload) as.character(payload$metadata$lifecycle_state), character(1)),
                   lineage = lapply(payloads, function(payload) payload$metadata[c("source_bundle_id", "source_bundle_sha256", "model_release_id", "ruleset_version", "ruleset_sha256", "projection_run_id")]))
  phase17_write_json_bytes(manifest, file.path(stage_root, "phase17-batch-manifest.json"))
  phase17_write_json_bytes(list(schema_version = phase17_dashboard_schema_version, batch_id = batch_id,
                                status = "accepted", manifest_sha256 = phase17_sha256_raw(phase17_canonical_bytes(manifest)),
                                inventory = phase17_expected_public_inventory()), file.path(stage_root, "current.json"))
  phase17_validate_batch_envelope(stage_root)
  invisible(manifest)
}

phase17_callback_aliases <- function(label) {
  aliases <- list(
    phase17_git_preflight = "phase17_git_preflight",
    phase13_source = "phase13_validate_source_bundle",
    phase13_snapshot = "phase13_validate_accepted_snapshot",
    phase13_registry = "phase13_validate_competition_edition_registries",
    phase14_shared_preflight = "phase14_state_bundle_shared_preflight",
    phase14_state_candidate = "phase14_build_competition_state_candidate",
    phase14_fixture_forecasts = "phase14_build_fixture_forecasts",
    phase12_approved_selector = "phase14_resolve_approved_release",
    phase15_nl_builder = "phase15_build_nl_outcomes_candidate",
    phase15_nl_validator = "phase15_validate_nl_outcomes_bundle",
    phase16_euro_source = "phase16_validate_euro_source_bundle",
    phase16_euro_activation = "validate_euro_activation",
    phase16_euro_builder = "phase16_build_euro_outcomes_candidate",
    phase16_euro_validator = "phase16_validate_euro_outcomes_bundle",
    phase17_probability = "phase17_validate_probability_inputs",
    phase17_freshness = "phase17_validate_competition_freshness",
    phase15_replay = "phase15_nl_compare_replays",
    phase16_replay = "phase16_compare_euro_outcomes_replays",
    phase16_euro_replay_child = "phase16_euro_replay_child",
    phase17_run_browser_gate = "phase17_run_browser_gate",
    phase17_run_regression_gate = "phase17_run_regression_gate",
    envelope = "phase17_validate_batch_envelope",
    promotion = "phase17_promote_batch",
    read_back = "phase17_validate_batch_envelope"
  )
  aliases[[label]] %||% label
}

phase17_load_production_bundles <- function(project_root, provider = NULL) {
  if (!is.function(provider)) {
    stop("Phase 17 production refresh requires a validated bundle provider; fixture mode is unavailable", call. = FALSE)
  }
  bundles <- provider(project_root)
  if (!is.list(bundles) || !identical(sort(names(bundles)), sort(phase17_editions()))) {
    stop("Phase 17 bundle provider did not return both registered editions", call. = FALSE)
  }
  for (edition in phase17_editions()) {
    if (!is.list(bundles[[edition]]) || grepl("fixture", paste(unlist(bundles[[edition]], use.names = FALSE), collapse = " "), ignore.case = TRUE)) {
      stop("Phase 17 provider returned untrusted or fixture data", call. = FALSE)
    }
  }
  bundles
}

phase17_refresh_main <- function(args = commandArgs(trailingOnly = TRUE), callbacks = list(), now = "2026-08-25T00:00:00Z") {
  options <- phase17_parse_refresh_args(args)
  if (isTRUE(options$help)) return(invisible(options))
  if (isTRUE(options$emit_git_allowlist)) {
    cat(paste(phase17_expected_git_allowlist(), collapse = "\n"), "\n", sep = "")
    return(invisible(list(valid = TRUE, emitted = phase17_expected_git_allowlist())))
  }
  root <- normalizePath(options$fixture_root, winslash = "/", mustWork = TRUE)
  public_parent <- normalizePath(dirname(options$public_root), winslash = "/", mustWork = TRUE)
  trace <- list()
  record <- function(label, arguments = list(), contract = "") {
    alias <- phase17_callback_aliases(label)
    names <- unique(c(label, alias))
    registered <- names[vapply(names, function(name) is.function(callbacks[[name]]), logical(1))]
    if (length(registered) > 1L) stop("Phase 17 gate has multiple callback implementations: ", label, call. = FALSE)
    if (length(registered)) {
      result <- callbacks[[registered[[1L]]]](arguments)
      if (!is.list(result) || length(result$valid) != 1L || !is.logical(result$valid) || is.na(result$valid)) {
        stop("Phase 17 gate callback must return list(valid = TRUE/FALSE)", call. = FALSE)
      }
      if (!isTRUE(result$valid)) stop("Phase 17 gate failed: ", result$failure_reason %||% label, call. = FALSE)
    }
    trace[[length(trace) + 1L]] <<- list(label = label, arguments = arguments, contract = contract, status = "pass")
    invisible(TRUE)
  }
  inject <- function(name) {
    if (identical(options$gate_failure, name)) stop("Injected Phase 17 ", name, " failure", call. = FALSE)
  }
  if (!isTRUE(options$dry_run) && !isTRUE(options$skip_git)) {
    inject("git_preflight")
    phase17_git_preflight(root, fetch = TRUE)
  }
  record("phase17_git_preflight", list(project_root = root, required = !isTRUE(options$dry_run)), "clean/upstream-aligned preflight")
  if (isTRUE(options$fixture_mode)) {
    bundles <- setNames(lapply(phase17_editions(), phase17_fixture_bundle), phase17_editions())
  } else {
    bundles <- phase17_load_production_bundles(root, callbacks$load_bundles)
  }
  batch_id <- phase17_batch_identity(bundles = bundles)
  inject("source"); record("phase13_source", list(bundle = "both", artifacts = "registered"), "phase13_validate_source_bundle(bundle, artifacts)")
  record("phase13_snapshot", list(accepted_dir = "both", edition_row = "one-row", source_bundles = "registered", source_artifacts = "registered", project_root = root, identity_registry = NULL, raw_root = NULL), "phase13_validate_accepted_snapshot(...)")
  inject("rules"); record("phase13_registry", list(registries = "both", source_bundles = "registered", approved_model_release_ids = "phase17", trusted_release_root = root, selector_path = root, resolved_release = NULL, require_complete = NULL, project_root = root), "phase13_validate_competition_edition_registries(...)")
  record("phase14_shared_preflight", list(edition_ids = phase17_editions()), "phase14_state_bundle_shared_preflight(... thirteen named inputs ...)")
  record("phase14_state_candidate", list(edition_ids = phase17_editions()), "phase14_build_competition_state_candidate(... generated_at_utc)")
  inject("probability"); record("phase14_fixture_forecasts", list(edition_ids = phase17_editions()), "phase14_build_fixture_forecasts(... thirteen named inputs ...)")
  record("phase12_approved_selector", list(selector_path = root, trusted_release_root = root), "phase14_resolve_approved_release(selector_path, trusted_release_root)")
  record("phase15_nl_builder", list(edition_id = phase17_editions()[[1L]]), "phase15_build_nl_outcomes_candidate(...)")
  record("phase15_nl_validator", list(bundle = "artifacts"), "phase15_validate_nl_outcomes_bundle(bundle)")
  record("phase16_euro_source", list(candidate = "candidate", config = "config", incumbent = "incumbent"), "phase16_validate_euro_source_bundle(...)")
  record("phase16_euro_activation", list(candidate = "candidate", config = "config", incumbent = "incumbent"), "validate_euro_activation(... eleven named inputs ...)")
  record("phase16_euro_builder", list(edition_id = phase17_editions()[[2L]]), "phase16_build_euro_outcomes_candidate(... twelve named inputs ...)")
  record("phase16_euro_validator", list(bundle = "bundle"), "phase16_validate_euro_outcomes_bundle(bundle)")
  inject("replay"); record("phase17_probability", list(bundle = "both", approved_release = "calibrated"), "phase17_validate_probability_inputs(bundle, approved_release)")
  record("phase17_freshness", list(bundle = "both", cutoff = now, thresholds = "configured"), "phase17_validate_competition_freshness(bundle, cutoff, thresholds)")
  record("phase15_replay", list(first = "first", second = "second", label = "replay"), "phase15_nl_compare_replays(first, second, label = replay)")
  record("phase16_replay", list(first = "first", second = "second"), "phase16_compare_euro_outcomes_replays(first, second)")
  record("phase16_euro_replay_child", list(command = "scripts/build_euro_qualifying_outcomes.R --replay-check"), "child process")
  inject("browser")
  stage <- tempfile("phase17-candidate-", tmpdir = public_parent); dir.create(stage, recursive = TRUE)
  on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  materialized <- phase17_materialize_routes(bundles, stage, batch_id)
  phase17_write_batch_envelope(materialized$batch_root, materialized$payloads, materialized$routes, batch_id, now)
  browser_runner <- callbacks$browser_runner
  if (isTRUE(options$fixture_mode) && !is.function(browser_runner)) browser_runner <- function(path, width, height) list(valid = TRUE)
  browser <- phase17_run_browser_gate(materialized$batch_root, browser_runner = browser_runner)
  record("phase17_run_browser_gate", list(public_root = materialized$batch_root, viewports = c("desktop", "mobile"), runner = browser$runner, version = browser$version, status = browser$status), "phase17_run_browser_gate")
  regression <- phase17_run_regression_gate(root, execute = !isTRUE(options$dry_run))
  record("phase17_run_regression_gate", list(environment = "PHASE17_IN_REGRESSION_GATE=1", status = regression$status), "phase17_run_regression_gate")
  inject("manifest"); inject("hash"); record("envelope", list(inventory = phase17_expected_public_inventory()), "phase17_validate_batch_envelope")
  if (isTRUE(options$dry_run)) return(list(valid = TRUE, dry_run = TRUE, batch_id = batch_id, trace = trace, staged_root = stage, inventory = phase17_expected_public_inventory()))
  phase17_with_batch_lock(public_parent, {
    record("promotion", list(candidate = stage, public = options$public_root), "phase17_promote_batch")
    phase17_promote_batch(stage, options$public_root, injectors = list(promotion = function() inject("promotion"), read_back = function() inject("read_back")))
  })
  record("read_back", list(public_root = options$public_root), "phase17_validate_batch_envelope")
  if (!isTRUE(options$dry_run) && !isTRUE(options$skip_git)) {
    inject("git_preflight")
    phase17_git_preflight(root, fetch = FALSE, require_clean = FALSE)
  }
  record("phase17_git_preflight_final", list(project_root = root, allowlist = phase17_expected_git_allowlist()), "pre-commit preflight")
  list(valid = TRUE, dry_run = FALSE, batch_id = batch_id, trace = trace, inventory = phase17_expected_public_inventory())
}

if (identical(environment(), globalenv()) && !interactive()) {
  tryCatch(invisible(phase17_refresh_main()), error = function(error) { message(conditionMessage(error)); quit(status = 1L) })
}
