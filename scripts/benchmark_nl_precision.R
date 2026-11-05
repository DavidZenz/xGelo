#!/usr/bin/env Rscript

# Read-only production benchmark. Accepted inputs and the approved-model
# knockout handoff are captured once; only benchmark reports are written.
nl_benchmark_metrics <- function(result) {
  frames <- list()
  for (name in c("projected_standings", "team_path_probabilities", "euro_priority_queue")) {
    data <- result[[name]]
    fields <- intersect(c("probability", grep("^p_", names(data), value = TRUE)), names(data))
    # Reason strings intentionally start with p_ in the EURO contract. They
    # describe unavailable values and must never be counted as probabilities.
    fields <- fields[vapply(data[fields], is.numeric, logical(1)) & !grepl("_reason$", fields)]
    key_fields <- intersect(c("league", "group_id", "team_id", "rank"), names(data))
    key <- do.call(paste, c(data[key_fields], sep = "::"))
    for (field in fields) frames[[length(frames) + 1L]] <- data.frame(
      key = paste(name, key, field, sep = "::"), probability = data[[field]], stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, frames); rownames(out) <- NULL; out
}

nl_benchmark_probability_audit <- function(result) {
  events <- nl_benchmark_metrics(result)
  known <- is.finite(events$probability)
  bounded <- all(events$probability[known] >= 0 & events$probability[known] <= 1)
  standings <- result$projected_standings
  sum_check <- function(keys) {
    values <- split(standings$probability, do.call(paste, c(standings[keys], sep = "::")))
    all(vapply(values, function(p) anyNA(p) || abs(sum(p) - 1) < 1e-10, logical(1)))
  }
  paths <- result$team_path_probabilities
  expected_mass <- c(p_quarter_final = 8, p_semi_final = 4, p_third_place = 2, p_final = 2, p_champion = 1)
  actual_mass <- vapply(names(expected_mass), function(field) {
    p <- paths[[field]]; if (anyNA(p)) NA_real_ else sum(p)
  }, numeric(1))
  known_mass <- is.finite(actual_mass)
  stage_mass <- all(abs(actual_mass[known_mass] - expected_mass[known_mass]) < 1e-10)
  nested <- all(paths$p_champion <= paths$p_final + 1e-10 &
    paths$p_final <= paths$p_semi_final + 1e-10 & paths$p_semi_final <= paths$p_quarter_final + 1e-10, na.rm = TRUE)
  checks <- list(probabilities_bounded = bounded, each_team_rank_mass_one = sum_check(c("group_id", "team_id")),
    each_group_position_mass_one = sum_check(c("group_id", "rank")),
    expected_knockout_participant_mass = stage_mass, knockout_paths_nested = nested)
  if (!all(unlist(checks))) stop("Independent Nations League benchmark probability audit failed", call. = FALSE)
  c(checks, list(knockout_expected_mass = as.list(expected_mass), knockout_observed_mass = as.list(actual_mass)))
}

# Production seam: one immutable handoff, one 1k preview, one selected run.
# Return that selected object to the normal candidate writer without rerunning
# it. The lower-count object is never eligible for outcomes publication.
nl_benchmark_run_for_publication <- function(inputs, output,
    simulate = uefa_nl_run_simulation) {
  selected <- inputs$simulation_count
  uefa_nl_mc_require_publication(selected)
  if (length(output) != 1L || is.na(output) || !startsWith(output, "/"))
    stop("Production precision report directory must be an absolute path", call. = FALSE)
  if (!dir.create(output, recursive = TRUE, showWarnings = FALSE) && !dir.exists(output))
    stop("Cannot create production precision report directory", call. = FALSE)
  write_report <- function(value, name) {
    target <- file.path(output, name)
    temporary <- tempfile(pattern = ".precision-", tmpdir = output)
    on.exit(unlink(temporary), add = TRUE)
    jsonlite::write_json(value, temporary, auto_unbox = TRUE, pretty = TRUE, digits = 17, na = "null")
    if (!file.rename(temporary, target)) stop("Cannot install production precision report", call. = FALSE)
  }
  frozen <- inputs; frozen$simulation_count <- NULL
  report <- list(schema_version = "nl-production-precision-benchmark-v1",
    source_bundle_id = inputs$source_bundle_id, source_bundle_sha256 = inputs$source_bundle_sha256,
    state_manifest_sha256 = inputs$state_manifest_sha256, cutoff_utc = inputs$cutoff_utc,
    model_release_id = inputs$model_release_id, seed = inputs$seed, workers = inputs$workers,
    input_sha256 = uefa_nl_sim_hash_data(frozen), r_version = as.character(getRversion()),
    precision_policy = uefa_nl_mc_policy(), selected_simulations = selected, runs = list())
  write_report(report, "input_manifest.json")
  previous <- NULL
  for (count in c(1000L, as.integer(selected))) {
    cat(sprintf("NL_PRECISION simulations=%d workers=%d start\n", count, inputs$workers))
    args <- inputs; args$simulation_count <- count
    timing <- system.time(result <- do.call(simulate, args))
    events <- nl_benchmark_metrics(result)
    audit <- nl_benchmark_probability_audit(result)
    utils::write.csv(events, file.path(output, paste0("event_probabilities_", count, ".csv")), row.names = FALSE)
    intervals <- uefa_nl_mc_interval(events$probability, count)
    utils::write.csv(cbind(key = events$key, intervals), file.path(output, paste0("event_intervals_", count, ".csv")), row.names = FALSE)
    run <- list(simulations = count, elapsed_seconds = unname(timing[["elapsed"]]),
      user_seconds = unname(timing[["user.self"]]), system_seconds = unname(timing[["sys.self"]]),
      output_size_bytes = as.numeric(object.size(result)), output_sha256 = uefa_nl_sim_hash_data(result$output_hashes),
      resolved_event_count = sum(is.finite(events$probability)), unavailable_event_count = sum(!is.finite(events$probability)),
      monte_carlo_precision = uefa_nl_mc_precision(count), probability_audit = audit)
    if (!is.null(previous)) {
      both <- merge(previous, events, by = "key", suffixes = c("_1000", "_selected"))
      known <- is.finite(both$probability_1000) & is.finite(both$probability_selected)
      difference <- abs(both$probability_1000[known] - both$probability_selected[known])
      run$comparison <- list(earlier_count = 1000L, compared_events = length(difference),
        maximum_absolute_change = if (length(difference)) max(difference) else NA_real_,
        mean_absolute_change = if (length(difference)) mean(difference) else NA_real_,
        p95_absolute_change = if (length(difference)) unname(stats::quantile(difference, .95)) else NA_real_,
        description = "Observed nested fixed-seed sample change; not a bound on model error or simultaneous convergence")
    }
    report$runs[[as.character(count)]] <- run
    write_report(report, "benchmark_report.json")
    cat(sprintf("NL_PRECISION simulations=%d elapsed_seconds=%.3f resolved_events=%d unavailable_events=%d\n",
      count, run$elapsed_seconds, run$resolved_event_count, run$unavailable_event_count))
    if (count == selected) break
    previous <- events
    rm(result); invisible(gc())
  }
  list(simulation = result, report = report)
}

nl_benchmark_main <- function(arguments = commandArgs(trailingOnly = TRUE)) {
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  options <- list(counts = c(1000L, 10000L), workers = 4L, seed = 15017L,
    output = file.path(root, "outputs/benchmarks/nl-precision-2026-11-05"),
    prepared_inputs = NULL, capture_only = FALSE)
  for (argument in arguments) {
    if (argument == "--capture-only") { options$capture_only <- TRUE; next }
    parts <- strsplit(argument, "=", fixed = TRUE)[[1L]]
    if (length(parts) != 2L) stop("Use --counts=N,N --workers=N --seed=N --output=path", call. = FALSE)
    if (parts[1] == "--counts") options$counts <- as.integer(strsplit(parts[2], ",", fixed = TRUE)[[1]]) else
    if (parts[1] == "--workers") options$workers <- as.integer(parts[2]) else
    if (parts[1] == "--seed") options$seed <- as.integer(parts[2]) else
    if (parts[1] == "--output") options$output <- parts[2] else
    if (parts[1] == "--prepared-inputs") options$prepared_inputs <- parts[2] else stop("Unknown benchmark option", call. = FALSE)
  }
  if (anyNA(options$counts) || any(options$counts < 1L) || anyDuplicated(options$counts) ||
      is.na(options$workers) || options$workers < 1L || is.na(options$seed) || options$seed < 0L)
    stop("Counts/workers must be positive integers and seed nonnegative", call. = FALSE)
  api <- new.env(parent = globalenv())
  api$interactive <- function() TRUE
  api$commandArgs <- function(trailingOnly = FALSE) if (trailingOnly) character() else
    paste0("--file=", file.path(root, "scripts/build_nations_league_outcomes.R"))
  sys.source(file.path(root, "scripts/build_nations_league_outcomes.R"), api)
  dir.create(options$output, recursive = TRUE, showWarnings = FALSE)
  write_report <- function(value, filename) jsonlite::write_json(value,
    file.path(options$output, filename), auto_unbox = TRUE, pretty = TRUE, digits = 17, na = "null")
  if (!is.null(options$prepared_inputs)) {
    manifest <- jsonlite::read_json(paste0(options$prepared_inputs, ".manifest.json"), simplifyVector = TRUE)
    if (!identical(manifest$schema_version, "nl-frozen-benchmark-inputs-v1") ||
        !identical(manifest$file_sha256, digest::digest(file = options$prepared_inputs, algo = "sha256")))
      stop("Frozen benchmark inputs fail their byte-bound manifest", call. = FALSE)
    inputs <- readRDS(options$prepared_inputs)
    if (!identical(manifest$input_sha256, api$uefa_nl_sim_hash_data(inputs)))
      stop("Frozen benchmark inputs fail their semantic input hash", call. = FALSE)
    cat("NL_BENCHMARK reusing byte-verified frozen accepted inputs\n")
  } else {
    cat("NL_BENCHMARK capturing accepted production inputs\n")
    loaded <- api$phase15_nl_default_inputs(project_root = root)
    saveRDS(loaded, file.path(options$output, "accepted_loaded_inputs.rds"))
    cat("NL_BENCHMARK accepted inputs captured; preparing full approved-model knockout handoff\n")
    handoff <- api$phase15_nl_knockout_forecast_handoff(loaded)
    inputs <- list(canonical_matches = loaded$state_bundle$canonical_matches,
    completed_results = loaded$source$results, forecast_status = handoff$forecast_status,
    forecasts = handoff$forecasts, score_distributions = handoff$score_distributions,
    groups = list(groups = loaded$topology$groups, group_rows = loaded$topology$teams),
    rules = loaded$rules, seed = options$seed, workers = options$workers,
    source_bundle_id = loaded$state_bundle$source_bundle_id,
    source_bundle_sha256 = loaded$state_bundle$source_bundle_sha256,
    model_release_id = loaded$state_bundle$model_release_id,
    model_lineage = loaded$state_bundle$model_lineage,
    state_manifest_sha256 = loaded$state_bundle$state_manifest_sha256,
    euro_playoff_eligibility = NULL, official_stage_slots = loaded$stage_capture$stage_capture,
    cutoff_utc = max(as.character(loaded$source$manifest$accepted_at_utc)))
    frozen_path <- file.path(options$output, "frozen_simulation_inputs.rds")
    saveRDS(inputs, frozen_path)
    write_report(list(schema_version = "nl-frozen-benchmark-inputs-v1",
      file_sha256 = digest::digest(file = frozen_path, algo = "sha256"),
      input_sha256 = api$uefa_nl_sim_hash_data(inputs)), "frozen_simulation_inputs.rds.manifest.json")
    cat("NL_BENCHMARK full simulation inputs captured\n")
  }
  # Seed and worker count affect execution, not the captured model handoff.
  inputs$seed <- options$seed; inputs$workers <- options$workers
  identity <- list(schema_version = "nl-production-precision-benchmark-v1",
    source_bundle_id = inputs$source_bundle_id, source_bundle_sha256 = inputs$source_bundle_sha256,
    state_manifest_sha256 = inputs$state_manifest_sha256, cutoff_utc = inputs$cutoff_utc,
    model_release_id = inputs$model_release_id, seed = options$seed, workers = options$workers,
    input_sha256 = api$uefa_nl_sim_hash_data(inputs), r_version = as.character(getRversion()),
    precision_policy = api$uefa_nl_mc_policy())
  write_report(identity, "input_manifest.json")
  if (isTRUE(options$capture_only)) return(invisible(identity))
  report <- identity; report$runs <- list(); previous <- NULL
  for (count in sort(options$counts)) {
    cat(sprintf("NL_BENCHMARK simulations=%d workers=%d start\n", count, options$workers))
    args <- c(inputs, list(simulation_count = count))
    timing <- system.time(result <- do.call(api$uefa_nl_run_simulation, args))
    vector <- nl_benchmark_metrics(result)
    utils::write.csv(vector, file.path(options$output, paste0("event_probabilities_", count, ".csv")), row.names = FALSE)
    run <- list(simulations = count, elapsed_seconds = unname(timing[["elapsed"]]),
      user_seconds = unname(timing[["user.self"]]), system_seconds = unname(timing[["sys.self"]]),
      output_size_bytes = as.numeric(object.size(result)), output_sha256 = api$uefa_nl_sim_hash_data(result$output_hashes),
      resolved_event_count = sum(is.finite(vector$probability)), unavailable_event_count = sum(!is.finite(vector$probability)),
      monte_carlo_precision = api$uefa_nl_mc_precision(count))
    run$probability_audit <- nl_benchmark_probability_audit(result)
    if (!is.null(previous)) {
      both <- merge(previous$events, vector, by = "key", suffixes = c("_earlier", "_later"))
      known <- is.finite(both$probability_earlier) & is.finite(both$probability_later)
      difference <- abs(both$probability_earlier[known] - both$probability_later[known])
      run$comparison <- list(earlier_count = previous$count, compared_events = length(difference),
        maximum_absolute_change = if (length(difference)) max(difference) else NA_real_,
        mean_absolute_change = if (length(difference)) mean(difference) else NA_real_,
        p95_absolute_change = if (length(difference)) unname(stats::quantile(difference, 0.95)) else NA_real_,
        description = "Observed nested fixed-seed sample change; not a bound on model error or simultaneous convergence")
    }
    report$runs[[as.character(count)]] <- run
    write_report(report, "benchmark_report.json")
    previous <- list(count = count, events = vector)
    cat(sprintf("NL_BENCHMARK simulations=%d elapsed_seconds=%.3f resolved_events=%d unavailable_events=%d\n",
      count, run$elapsed_seconds, run$resolved_event_count, run$unavailable_event_count))
    rm(result); invisible(gc())
  }
  invisible(report)
}

if (sys.nframe() == 0L) nl_benchmark_main()
