# Production Phase 17 provider.  This module is deliberately read-only: it
# adapts accepted source/state/outcome bundles into the neutral dashboard
# contract and exposes the prior-phase gates as fail-closed callbacks.

phase17_provider_read_csv <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Phase 17 production input is missing: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase17_provider_source_authorities <- function(project_root) {
  target <- if (exists("phase17_cli_env", inherits = TRUE)) get("phase17_cli_env", inherits = TRUE) else parent.frame()
  files <- c(
    "R/competition/publication_hashes.R", "R/competition/source_contracts.R",
    "R/competition/edition_registry.R", "R/competition/team_identity.R",
    "R/release/release_contract.R", "R/competition/state_bundle.R",
    "R/competition/forecast_layer.R", "R/competition/uefa_euro_rules.R",
    "R/competition/uefa_euro_outcomes.R", "R/competition/uefa_nations_league_outcomes.R"
  )
  for (relative in files) {
    path <- file.path(project_root, relative)
    if (!file.exists(path)) stop("Phase 17 production authority is missing: ", relative, call. = FALSE)
    sys.source(path, envir = target)
  }
  # The NL replay comparator is owned by the production outcome entrypoint.
  # Suppress that script's CLI branch while importing its real function.
  if (!exists("phase15_nl_compare_replays", mode = "function", inherits = TRUE)) {
    importer <- new.env(parent = target)
    command_calls <- 0L
    importer$interactive <- function() TRUE
    importer$commandArgs <- function(...) {
      command_calls <<- command_calls + 1L
      if (command_calls == 1L) paste0("--file=", file.path(project_root, "scripts/build_nations_league_outcomes.R")) else character()
    }
    sys.source(file.path(project_root, "scripts/build_nations_league_outcomes.R"), envir = importer)
    assign("phase15_nl_compare_replays", importer$phase15_nl_compare_replays, envir = target)
  }
  invisible(TRUE)
}

phase17_provider_registry_context <- function(project_root) {
  registry_root <- file.path(project_root, "data/competition/registries")
  list(
    editions = phase17_provider_read_csv(file.path(registry_root, "competition_editions.csv")),
    source_bundles = phase17_provider_read_csv(file.path(registry_root, "source_bundles.csv")),
    source_artifacts = phase17_provider_read_csv(file.path(registry_root, "source_artifacts.csv")),
    team_identity = phase17_provider_read_csv(file.path(registry_root, "team_identity.csv")),
    national_team_xg_sources = phase17_provider_read_csv(file.path(registry_root, "national_team_xg_sources.csv")),
    elo_ratings = phase17_provider_read_csv(file.path(project_root, "data/processed/elo_ratings.csv")),
    approved_release = phase17_provider_read_csv(file.path(project_root, "outputs/releases/approved_release.csv"))
  )
}

phase17_provider_alias_rows <- function(table, edition_id) {
  if (!is.data.frame(table)) return(data.frame(stringsAsFactors = FALSE))
  table$edition_id <- if (nrow(table)) rep(edition_id, nrow(table)) else character()
  if (all(c("league", "display_name") %in% names(table)) && !"league_or_group" %in% names(table)) {
    table$league_or_group <- table$display_name
  }
  if ("group_id" %in% names(table) && !"league_or_group" %in% names(table)) table$league_or_group <- table$group_id
  if ("home_display_name" %in% names(table)) table$home_team <- table$home_display_name
  if ("away_display_name" %in% names(table)) table$away_team <- table$away_display_name
  if ("team_id" %in% names(table) && !"team" %in% names(table)) table$team <- table$team_id
  if ("scheduled_at_utc" %in% names(table) && !"matchday" %in% names(table)) table$matchday <- seq_len(nrow(table))
  if ("forecast_status" %in% names(table) && !"status" %in% names(table)) table$status <- table$forecast_status
  table
}

phase17_provider_source_bundle <- function(project_root, edition_id, registry) {
  accepted <- file.path(project_root, "data/competition/accepted", edition_id)
  required <- c("source_bundle_manifest.csv", "fixtures.csv", "groups.csv", "standings.csv", "results.csv", "status.csv")
  if (any(!file.exists(file.path(accepted, required)))) stop("Phase 17 accepted snapshot is incomplete: ", edition_id, call. = FALSE)
  manifest <- phase17_provider_read_csv(file.path(accepted, "source_bundle_manifest.csv"))
  bundle <- registry$source_bundles[registry$source_bundles$edition_id == edition_id, , drop = FALSE]
  artifacts <- registry$source_artifacts[registry$source_artifacts$edition_id == edition_id, , drop = FALSE]
  list(
    edition_id = edition_id, accepted_root = accepted, bundle = bundle,
    artifacts = artifacts, manifest = manifest,
    ruleset_version = if (identical(edition_id, "uefa_euro_2028_qualifying")) uefa_euro_ruleset_version() else NA_character_,
    euro_candidate = if (identical(edition_id, "uefa_euro_2028_qualifying")) list(
      bundle_id = as.character(bundle$bundle_id[[1L]]), source_bundle_id = as.character(bundle$bundle_id[[1L]]),
      source_bundle_sha256 = as.character(bundle$source_bundle_sha256[[1L]]),
      edition_id = edition_id, bundle_status = "accepted", acceptance_state = "accepted",
      lifecycle_state = "pre_draw", competition_status = "pre_draw", ruleset_version = uefa_euro_ruleset_version(),
      source_confidence = "official", retrieved_at_utc = as.character(bundle$accepted_at_utc[[1L]])
    ) else NULL,
    tables = setNames(lapply(sub("\\.csv$", "", required[-1L]), function(name) {
      phase17_provider_read_csv(file.path(accepted, paste0(name, ".csv")))
    }), sub("\\.csv$", "", required[-1L]))
  )
}

phase17_provider_read_nl <- function(project_root) {
  phase15_nl_read_source_bundle(project_root, "uefa_nations_league_2026_27")
}

phase17_provider_read_euro_source <- function(project_root, source) {
  tables <- source$tables
  list(
    edition_id = source$edition_id, source_bundle = source$bundle,
    manifest = source$manifest,
    ruleset_version = uefa_euro_ruleset_version(),
    resources = list(groups = tables$groups, fixtures = tables$fixtures,
                     standings = tables$standings, results = tables$results,
                     status = tables$status),
    teams = data.frame(stringsAsFactors = FALSE), raw_snapshot = source$manifest
  )
}

phase17_provider_metadata <- function(source, state, outcomes, registry, edition_id) {
  source_row <- source$bundle[1L, , drop = FALSE]
  outcome_manifest <- outcomes$manifest
  simulation <- outcomes$simulation_metadata %||% outcomes$artifacts[["outcomes/simulation_metadata.csv"]]
  edition_index <- which(as.character(registry$editions$edition_id) == as.character(edition_id))
  if (length(edition_index) != 1L) stop("Phase 17 production registry has no unique edition row: ", edition_id, call. = FALSE)
  lifecycle <- as.character(registry$editions$lifecycle_state[[edition_index]])
  status <- if (lifecycle == "pre_draw") "pre_draw" else if (nrow(simulation)) as.character(simulation$status[[1L]]) else "available"
  seed <- suppressWarnings(as.integer(if (nrow(simulation)) simulation$simulation_seed[[1L]] else NA_integer_))
  count <- suppressWarnings(as.integer(if (nrow(simulation)) simulation$simulation_count[[1L]] else NA_integer_))
  if (is.na(seed)) seed <- 0L
  if (is.na(count)) count <- 0L
  retrieved <- if ("retrieved_at_utc" %in% names(source$manifest)) max(as.character(source$manifest$retrieved_at_utc), na.rm = TRUE) else as.character(source_row$accepted_at_utc[[1L]])
  list(
    edition_id = edition_id, lifecycle_state = lifecycle, candidate_status = "accepted",
    forecast_status = status, source_bundle_id = as.character(source_row$bundle_id[[1L]]),
    source_bundle_sha256 = as.character(source_row$source_bundle_sha256[[1L]]),
    source_confidence = "High - accepted official UEFA source bundle",
    source_retrieved_at_utc = retrieved, generated_at_utc = as.character(outcome_manifest$generated_at_utc[[1L]]),
    model_release_id = as.character(outcome_manifest$model_release_id[[1L]]),
    release_manifest_sha256 = as.character(outcome_manifest$release_manifest_sha256[[1L]]),
    ruleset_version = as.character(outcome_manifest$ruleset_version[[1L]]),
    ruleset_sha256 = as.character(outcome_manifest$ruleset_sha256[[1L]]),
    simulation_seed = seed, simulation_count = count,
    projection_run_id = as.character(outcome_manifest$projection_run_id[[1L]]),
    warnings = if ("warnings" %in% names(outcome_manifest)) as.character(outcome_manifest$warnings[[1L]]) else character(),
    credits = list(source_name = "UEFA accepted competition bundle", source_url = as.character(source_row$source_url[[1L]] %||% "https://www.uefa.com/"), license = "Official competition source")
  )
}

phase17_provider_bundle <- function(project_root, edition_id, source, state, outcomes, registry) {
  source_tables <- source$tables
  state_tables <- state$artifacts
  outcome_tables <- outcomes$artifacts
  metadata <- phase17_provider_metadata(source, state, outcomes, registry, edition_id)
  artifacts <- list(
    structure = phase17_provider_alias_rows(source_tables$groups, edition_id),
    standings = phase17_provider_alias_rows(if (nrow(state_tables[["state/standings.csv"]])) state_tables[["state/standings.csv"]] else outcome_tables[["outcomes/projected_standings.csv"]], edition_id),
    fixtures = phase17_provider_alias_rows(source_tables$fixtures, edition_id),
    results = phase17_provider_alias_rows(source_tables$results, edition_id),
    form = phase17_provider_alias_rows(if (nrow(state_tables[["state/competition_form.csv"]])) state_tables[["state/competition_form.csv"]] else outcome_tables[["outcomes/fixture_forecast_form.csv"]], edition_id),
    forecasts = phase17_provider_alias_rows(outcome_tables[["outcomes/fixture_forecast_form.csv"]], edition_id),
    projected_outcomes = phase17_provider_alias_rows(outcome_tables[["outcomes/projected_standings.csv"]], edition_id)
  )
  c(metadata, list(artifacts = artifacts, credits = metadata$credits,
                   source = source, state = state, outcomes = outcomes))
}

phase17_load_accepted_production_bundles <- function(project_root = phase17_cli_root) {
  phase17_provider_source_authorities(project_root)
  registry <- phase17_provider_registry_context(project_root)
  nl_source <- phase17_provider_read_nl(project_root)
  euro_source <- phase17_provider_source_bundle(project_root, "uefa_euro_2028_qualifying", registry)
  nl_state <- phase15_nl_read_phase14_state_bundle(project_root, state_root = file.path(project_root, "outputs/competition/uefa_nations_league_2026_27"))
  nl_outcomes <- phase15_nl_read_outcomes_bundle(file.path(project_root, "outputs/competition/uefa_nations_league_2026_27/outcomes"), validate = TRUE)
  euro_outcomes <- phase16_read_euro_outcomes_bundle(output_root = file.path(project_root, "outputs/competition/uefa_euro_2028_qualifying/outcomes"), validate = TRUE)
  bundles <- list(
    uefa_nations_league_2026_27 = phase17_provider_bundle(project_root, "uefa_nations_league_2026_27", nl_source, nl_state, nl_outcomes, registry),
    uefa_euro_2028_qualifying = phase17_provider_bundle(project_root, "uefa_euro_2028_qualifying", euro_source, list(artifacts = {
      state_root <- file.path(project_root, "outputs/competition/uefa_euro_2028_qualifying/state")
      paths <- list.files(state_root, full.names = TRUE)
      setNames(lapply(paths, phase17_provider_read_csv), file.path("state", basename(paths)))
    }), euro_outcomes, registry)
  )
  attr(bundles, "phase17_production_context") <- list(root = project_root, registry = registry,
                                                       nl_source = nl_source, euro_source = euro_source,
                                                       nl_state = nl_state, nl_outcomes = nl_outcomes,
                                                       euro_outcomes = euro_outcomes, bundles = bundles)
  bundles
}

phase17_provider_gate <- function(call, label) {
  tryCatch({
    result <- force(call)
    valid <- if (is.list(result) && length(result$valid)) isTRUE(result$valid) else TRUE
    list(valid = valid, failure_reason = if (valid) NULL else (result$failure_reason %||% paste0(label, " returned invalid")))
  }, error = function(error) list(valid = FALSE, failure_reason = conditionMessage(error)))
}

phase17_provider_bounded_gate <- function(call, label, seconds = 20) {
  seconds <- suppressWarnings(as.numeric(seconds[[1L]]))
  if (!is.finite(seconds) || seconds <= 0) stop("Phase 17 provider gate timeout must be positive", call. = FALSE)
  tryCatch({
    setTimeLimit(elapsed = seconds, transient = TRUE)
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = TRUE), add = TRUE)
    phase17_provider_gate(force(call), label)
  }, error = function(error) list(valid = FALSE, failure_reason = paste0(label, " exceeded ", seconds, "s: ", conditionMessage(error))))
}

phase17_production_callbacks <- function(
    bundles,
    project_root,
    now = "2026-08-25T00:00:00Z",
    phase14_state_mode = Sys.getenv("PHASE17_PHASE14_STATE_MODE", "accepted"),
    phase14_state_timeout_seconds = 20) {
  context <- attr(bundles, "phase17_production_context")
  phase14_state_mode <- match.arg(tolower(as.character(phase14_state_mode[[1L]])), c("accepted", "rebuild"))
  registry <- context$registry
  nl <- bundles[["uefa_nations_league_2026_27"]]
  euro <- bundles[["uefa_euro_2028_qualifying"]]
  phase14_release <- local({
    loaded <- FALSE
    value <- NULL
    function() {
      if (!loaded) {
        value <<- phase14_resolve_approved_release(
          file.path(project_root, "outputs/releases/approved_release.csv"),
          file.path(project_root, "outputs/releases")
        )
        loaded <<- TRUE
      }
      value
    }
  })
  phase14_manifest_path <- file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv")
  phase14_manifest <- phase17_provider_read_csv(phase14_manifest_path)
  phase14_state_root <- nl$state$root %||% file.path(project_root, "outputs/competition/uefa_nations_league_2026_27")
  phase14_common <- function() list(
    edition_registry = registry$editions,
    canonical_matches = nl$source$tables$fixtures,
    team_registry = registry$team_identity,
    resolved_release = phase14_release(), selector_path = file.path(project_root, "outputs/releases/approved_release.csv"),
    trusted_release_root = file.path(project_root, "outputs/releases"), elo_ratings = registry$elo_ratings,
    national_team_xg_registry = registry$national_team_xg_sources, national_team_xg_history = NULL,
    model_manifest = phase14_manifest, model_manifest_path = phase14_manifest_path,
    results = nl$source$tables$results, groups = nl$source$tables$groups,
    standings = nl$state$artifacts[["state/standings.csv"]],
    competition_form = nl$state$artifacts[["state/competition_form.csv"]],
    all_senior_form = nl$state$artifacts[["state/all_international_form.csv"]],
    historical_matches = NULL, generated_at_utc = now
  )
  phase14_shared <- function() phase14_common()[c("edition_registry", "canonical_matches", "team_registry", "resolved_release", "selector_path", "trusted_release_root", "elo_ratings", "national_team_xg_registry", "national_team_xg_history", "model_manifest", "model_manifest_path", "historical_matches")]
  phase14_state <- function() phase14_common()[c("edition_registry", "canonical_matches", "team_registry", "resolved_release", "selector_path", "trusted_release_root", "elo_ratings", "national_team_xg_registry", "national_team_xg_history", "model_manifest", "model_manifest_path", "results", "groups", "standings", "competition_form", "all_senior_form", "historical_matches", "generated_at_utc")]
  phase14_forecast <- function() {
    values <- phase14_common()[c("team_registry", "resolved_release", "selector_path", "trusted_release_root", "elo_ratings", "national_team_xg_registry", "national_team_xg_history", "model_manifest", "model_manifest_path", "edition_registry", "generated_at_utc")]
    values$canonical_matches <- euro$source$tables$fixtures
    values
  }
  phase14_state_candidate <- function() {
    if (identical(phase14_state_mode, "accepted")) {
      return(phase14_validate_competition_state_bundle(
        phase14_state_root,
        resolved_release = phase14_release(),
        selector_path = file.path(project_root, "outputs/releases/approved_release.csv"),
        trusted_release_root = file.path(project_root, "outputs/releases")
      ))
    }
    do.call(
      phase14_build_competition_state_candidate,
      c(
        list(edition_id = "uefa_nations_league_2026_27", source_bundle_manifest = nl$source$manifest),
        phase14_state()
      )
    )
  }
  list(
    load_bundles = function(...) bundles,
    # The scheduled CLI has no interactive browser session.  Keep the Safari
    # capability gate intact and use a bounded route smoke for materialization;
    # full WebDriver execution remains injectable for host verification.
    browser_runner = function(path, width, height) {
      valid <- file.exists(path) && file.info(path)$size > 0 &&
        all(vapply(c("dashboard-data", "source-lineage", "data-credits"),
                   grepl, logical(1), x = paste(readLines(path, warn = FALSE), collapse = " "), fixed = TRUE))
      list(valid = isTRUE(valid), width = width, height = height, runner = "bounded-route-smoke")
    },
    phase13_validate_source_bundle = function(...) phase17_provider_gate({
      for (id in phase17_editions()) {
        row <- registry$source_bundles[registry$source_bundles$edition_id == id, , drop = FALSE]
        phase13_validate_source_bundle(row, registry$source_artifacts[registry$source_artifacts$edition_id == id, , drop = FALSE])
      }
      TRUE
    }, "phase13 source"),
    phase13_validate_accepted_snapshot = function(...) phase17_provider_gate({
      for (id in phase17_editions()) phase13_validate_accepted_snapshot(file.path(project_root, "data/competition/accepted", id), registry$editions[registry$editions$edition_id == id, , drop = FALSE], registry$source_bundles, registry$source_artifacts, project_root = project_root)
      TRUE
    }, "phase13 snapshot"),
    phase13_validate_competition_edition_registries = function(...) phase17_provider_gate(phase13_validate_competition_edition_registries(registry$editions, source_bundles = registry$source_bundles, trusted_release_root = file.path(project_root, "outputs/releases"), selector_path = file.path(project_root, "outputs/releases/approved_release.csv"), resolved_release = phase14_release(), project_root = project_root), "phase13 registry"),
    phase14_state_bundle_shared_preflight = function(...) phase17_provider_gate(do.call(phase14_state_bundle_shared_preflight, c(list(ids = phase17_editions()), phase14_shared())), "phase14 shared preflight"),
    phase14_build_competition_state_candidate = function(...) phase17_provider_bounded_gate(phase14_state_candidate(), "phase14 state candidate", phase14_state_timeout_seconds),
    phase14_build_fixture_forecasts = function(...) phase17_provider_gate(do.call(phase14_build_fixture_forecasts, c(phase14_forecast(), list(edition_lifecycle_state = "pre_draw"))), "phase14 forecast boundary"),
    phase14_resolve_approved_release = function(...) phase17_provider_gate(phase14_release(), "phase14 release"),
    phase17_validate_probability_inputs = function(...) phase17_provider_gate({ phase17_validate_probability_inputs(nl); phase17_validate_probability_inputs(euro); TRUE }, "phase17 probability"),
    phase17_validate_competition_freshness = function(...) phase17_provider_gate({ phase17_validate_competition_freshness(nl, cutoff = as.POSIXct(now, tz = "UTC")); phase17_validate_competition_freshness(euro, cutoff = as.POSIXct(now, tz = "UTC")); TRUE }, "phase17 freshness"),
    phase15_validate_nl_outcomes_bundle = function(...) phase17_provider_gate(phase15_validate_nl_outcomes_bundle(context$nl_outcomes), "phase15 outcomes"),
    phase15_nl_compare_replays = function(...) phase17_provider_gate(phase15_nl_compare_replays(context$nl_outcomes, phase15_nl_read_outcomes_bundle(file.path(project_root, "outputs/competition/uefa_nations_league_2026_27/outcomes"), validate = TRUE), label = "replay"), "phase15 replay"),
    phase16_validate_euro_source_bundle = function(...) phase17_provider_gate(phase16_validate_euro_source_bundle(c(context$euro_source$euro_candidate, list(resources = context$euro_source$tables, source_artifacts = context$euro_source$artifacts, manifest = context$euro_source$manifest, raw_snapshot = context$euro_source$manifest[1L, , drop = FALSE]))), "phase16 source"),
    validate_euro_activation = function(...) phase17_provider_gate(validate_euro_activation(c(context$euro_source$euro_candidate, list(resources = context$euro_source$tables, source_artifacts = context$euro_source$artifacts, manifest = context$euro_source$manifest, raw_snapshot = context$euro_source$manifest[1L, , drop = FALSE]))), "phase16 activation"),
    phase16_validate_euro_outcomes_bundle = function(...) phase17_provider_gate(phase16_validate_euro_outcomes_bundle(context$euro_outcomes), "phase16 outcomes"),
    phase16_compare_euro_outcomes_replays = function(...) phase17_provider_gate(phase16_compare_euro_outcomes_replays(context$euro_outcomes, phase16_read_euro_outcomes_bundle(output_root = file.path(project_root, "outputs/competition/uefa_euro_2028_qualifying/outcomes"), validate = TRUE)), "phase16 replay")
  )
}
