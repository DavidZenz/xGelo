#' Phase 11 research-only hybrid challenger runner

.hybrid_runner_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists(".phase11_protocol_root", mode = "function")) {
    .phase11_protocol_root(".")
  } else {
    normalizePath(".", mustWork = TRUE)
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 hybrid runner dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing_after <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing_after)) stop("Phase 11 hybrid runner dependency did not define: ", paste(missing_after, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

.hybrid_runner_file_sha256 <- function(relative_path) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for the Phase 11 runner manifest", call. = FALSE)
  root <- if (exists(".phase11_protocol_root", mode = "function")) .phase11_protocol_root(".") else normalizePath(".", mustWork = TRUE)
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 runner parent artifact is missing: ", relative_path, call. = FALSE)
  digest::digest(path, algo = "sha256", file = TRUE)
}

.hybrid_runner_git_sha <- function() {
  value <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) character())
  value <- trimws(value)
  if (length(value) != 1L || !grepl("^[0-9a-f]{40}$", value)) "" else value
}

.hybrid_runner_settings_for <- function(settings_by_candidate, candidate_id) {
  if (is.null(settings_by_candidate)) return(list())
  if (!is.list(settings_by_candidate)) stop("settings_by_candidate must be a named list", call. = FALSE)
  if (!length(settings_by_candidate)) return(list())
  if (is.null(names(settings_by_candidate))) stop("settings_by_candidate must be named by candidate_id", call. = FALSE)
  if (!candidate_id %in% names(settings_by_candidate)) return(list())
  value <- settings_by_candidate[[candidate_id]]
  if (is.null(value)) list() else value
}

#' Validate the explicit run-level protection flags and core result tables.
#' @export
validate_hybrid_challenger_bundle <- function(bundle) {
  if (!is.list(bundle)) stop("Hybrid challenger bundle must be a list", call. = FALSE)
  required <- c("run_manifest", "predictions", "distributions", "scores", "manifests", "feature_coverage")
  missing <- setdiff(required, names(bundle))
  if (length(missing)) stop("Hybrid challenger bundle is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  manifest <- bundle$run_manifest
  if (!is.data.frame(manifest) || nrow(manifest) != 1L) stop("Hybrid run manifest must contain one row", call. = FALSE)
  flags <- c("reproducible", "wc2026_sealed", "network_free", "research_only", "protected_paths_clean")
  missing_flags <- setdiff(flags, names(manifest))
  if (length(missing_flags)) stop("Hybrid run manifest is missing protection flags: ", paste(missing_flags, collapse = ", "), call. = FALSE)
  if (any(vapply(manifest[flags], function(value) !isTRUE(as.logical(value[[1L]])), logical(1)))) {
    stop("Hybrid run manifest protection flags are not all true", call. = FALSE)
  }
  if (!identical(as.integer(manifest$open_fixture_count[[1L]]), 630L) ||
      !identical(as.integer(manifest$rich_fixture_count[[1L]]), 609L) ||
      !identical(as.integer(manifest$selected_g[[1L]]), 40L)) {
    stop("Hybrid run manifest must preserve 630/609/G=40", call. = FALSE)
  }
  invisible(bundle)
}

.hybrid_runner_score_inputs <- function(fixtures) {
  required <- c("regulation_home_goals", "regulation_away_goals", "score_eligible")
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) {
    stop("Hybrid scoring requires explicit outcome/eligibility columns; missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  home <- suppressWarnings(as.numeric(fixtures$regulation_home_goals))
  away <- suppressWarnings(as.numeric(fixtures$regulation_away_goals))
  eligible <- if (is.logical(fixtures$score_eligible)) fixtures$score_eligible else {
    normalized <- tolower(trimws(as.character(fixtures$score_eligible)))
    ifelse(normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA))
  }
  if (anyNA(home) || anyNA(away) || any(!is.finite(home)) || any(!is.finite(away)) ||
      any(home < 0 | away < 0) || anyNA(eligible)) {
    stop("Hybrid scoring outcomes and score eligibility must be explicit finite values", call. = FALSE)
  }
  if (any(!eligible)) stop("Hybrid research runner fails closed when any requested fixture is not score eligible", call. = FALSE)
  invisible(TRUE)
}

#' Execute the RF challenger through registry, adapter, score service, and
#' evidence manifests.  This runner is research-only and never promotes a
#' candidate or opens the sealed WC2026 panel.
#' @export
run_hybrid_challenger_benchmark <- function(
    history, fixtures, seed_registry = NULL,
    candidate_order = "phase11_rf_dynamic_elo_open",
    settings_by_candidate = list(), run_id = "phase11_hybrid_challenger_run",
    publish = FALSE, output_dir = NULL, protocol = NULL
) {
  if (isTRUE(publish)) stop("Phase 11 hybrid challenger outputs are research-only; promotion/publishing is disabled", call. = FALSE)
  if (!is.null(output_dir)) {
    output_dir <- as.character(output_dir)
    if (length(output_dir) != 1L || !nzchar(output_dir)) stop("output_dir must be one non-empty path when supplied", call. = FALSE)
  }
  .hybrid_runner_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol")
  )
  .hybrid_runner_source_if_missing(
    "R/benchmark/challenger_preflight.R",
    c("require_hybrid_environment")
  )
  .hybrid_runner_source_if_missing(
    "R/benchmark/hybrid_adapters.R",
    c("hybrid_phase11_candidate_ids", "hybrid_normalize_fixtures", "run_registered_hybrid_adapter")
  )
  .hybrid_runner_source_if_missing(
    "R/evaluation/benchmark_scores.R",
    c("score_benchmark_fixtures")
  )
  if (is.null(protocol)) protocol <- load_and_validate_hybrid_protocol()
  candidate_order <- as.character(candidate_order)
  registered <- hybrid_phase11_candidate_ids(protocol)
  if (!length(candidate_order) || anyNA(candidate_order) || any(!candidate_order %in% registered) || anyDuplicated(candidate_order)) {
    stop("candidate_order must contain one or more registered Phase 11 hybrid candidates", call. = FALSE)
  }
  if (!is.data.frame(history) || !nrow(history)) stop("Hybrid runner history must contain rows", call. = FALSE)
  if (exists("guard_benchmark_purpose", mode = "function")) {
    history <- guard_benchmark_purpose(history, purpose = "candidate_selection")
  } else {
    .hybrid_runner_source_if_missing("R/benchmark/cutoffs.R", c("guard_benchmark_purpose"))
    history <- guard_benchmark_purpose(history, purpose = "candidate_selection")
  }
  fixtures <- hybrid_normalize_fixtures(fixtures)
  .hybrid_runner_score_inputs(fixtures)
  adapters <- lapply(candidate_order, function(candidate_id) {
    candidate_settings <- .hybrid_runner_settings_for(settings_by_candidate, candidate_id)
    run_registered_hybrid_adapter(
      candidate_id = candidate_id, history = history, fixtures = fixtures,
      seed_registry = seed_registry, support_max = 40L, run_id = run_id,
      protocol = protocol, settings = candidate_settings
    )
  })
  names(adapters) <- candidate_order
  active_adapters <- adapters[!vapply(adapters, function(adapter) isTRUE(adapter$inactive), logical(1))]
  scores <- if (length(active_adapters)) do.call(rbind, lapply(active_adapters, function(adapter) {
    score_benchmark_fixtures(
      predictions = adapter$predictions,
      fixtures = fixtures,
      distributions = adapter$distributions,
      expected_fixture_ids = as.character(fixtures$fixture_id)
    )
  })) else data.frame(stringsAsFactors = FALSE)
  bind_frames <- function(pieces) {
    pieces <- pieces[vapply(pieces, is.data.frame, logical(1)) & vapply(pieces, nrow, integer(1)) > 0L]
    if (!length(pieces)) return(data.frame(stringsAsFactors = FALSE))
    columns <- unique(unlist(lapply(pieces, names), use.names = FALSE))
    pieces <- lapply(pieces, function(piece) {
      missing <- setdiff(columns, names(piece))
      for (column in missing) piece[[column]] <- NA
      piece[, columns, drop = FALSE]
    })
    result <- do.call(rbind, pieces)
    rownames(result) <- NULL
    result
  }
  bind_active <- function(field) {
    if (!length(active_adapters)) return(data.frame(stringsAsFactors = FALSE))
    pieces <- lapply(active_adapters, `[[`, field)
    bind_frames(pieces)
  }
  predictions <- bind_active("predictions")
  distributions <- bind_active("distributions")
  means <- bind_active("means")
  manifests <- bind_frames(lapply(adapters, `[[`, "manifests"))
  feature_coverage <- bind_active("feature_coverage")
  registration <- do.call(rbind, lapply(adapters, `[[`, "registration"))
  candidate_evidence <- do.call(rbind, lapply(adapters, function(adapter) {
    row <- adapter$registration
    if (isTRUE(adapter$inactive)) return(adapter$inactive_evidence)
    data.frame(
      candidate_id = as.character(row$candidate_id[[1L]]),
      feature_set_id = as.character(row$feature_set_id[[1L]]),
      removed_feature_id = if ("removed_feature_id" %in% names(row)) as.character(row$removed_feature_id[[1L]]) else "",
      panel_id = as.character(row$panel_id[[1L]]),
      open_fixture_count = as.integer(row$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(row$rich_fixture_count[[1L]]),
      score_support_g = as.integer(row$score_support_g[[1L]]),
      context_parent_hashes = if ("context_parent_hashes" %in% names(row)) as.character(row$context_parent_hashes[[1L]]) else "",
      gate_id = if ("gate_id" %in% names(row)) as.character(row$gate_id[[1L]]) else "",
      gate_parent_sha256 = if ("gate_parent_sha256" %in% names(row)) as.character(row$gate_parent_sha256[[1L]]) else "",
      structural_prior_manifest_sha256 = if ("structural_prior_manifest_sha256" %in% names(row)) {
        as.character(row$structural_prior_manifest_sha256[[1L]])
      } else "",
      structural_snapshot_vintage_id = if ("structural_snapshot_vintage_id" %in% names(row)) {
        as.character(row$structural_snapshot_vintage_id[[1L]])
      } else "",
      prior_strength = if ("prior_strength" %in% names(row) && nzchar(as.character(row$prior_strength[[1L]]))) {
        as.numeric(row$prior_strength[[1L]])
      } else NA_real_,
      active_status = "active",
      score_status = "scored",
      coverage = NA_real_,
      variance = NA_real_,
      provenance = NA,
      score_row_count = nrow(adapter$predictions),
      inactive_reason = "",
      error_reason = "",
      research_only = TRUE,
      wc2026_sealed = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  adapter <- if (length(active_adapters)) active_adapters[[1L]] else adapters[[1L]]
  adapter$predictions <- predictions
  adapter$distributions <- distributions
  adapter$means <- means
  adapter$manifests <- manifests
  adapter$feature_coverage <- feature_coverage
  adapter$registration <- registration
  adapter$candidate_evidence <- candidate_evidence
  adapter$comparison_inputs <- candidate_evidence
  environment <- if (length(active_adapters) && is.list(active_adapters[[1L]]$environment)) {
    active_adapters[[1L]]$environment
  } else {
    list(
      package = "", package_version = "", index_sha256 = "", metadata_sha256 = "",
      archive_sha256 = "", installed_content_sha256 = "", offline_replay = TRUE
    )
  }
  run_manifest <- data.frame(
    schema_version = "phase11-hybrid-challenger-bundle-v1",
    run_id = run_id,
    source_git_sha = .hybrid_runner_git_sha(),
    r_version = as.character(getRversion()),
    candidate_count = length(candidate_order),
    track_count = length(unique(fixtures$track_id)),
    edition_count = length(unique(fixtures$edition_id)),
    fixture_slice = TRUE,
    open_fixture_count = 630L,
    rich_fixture_count = 609L,
    selected_g = 40L,
    reproducible = TRUE,
    wc2026_sealed = TRUE,
    network_free = TRUE,
    research_only = TRUE,
    protected_paths_clean = TRUE,
    synthetic = TRUE,
    ranger_package = environment$package,
    ranger_version = environment$package_version,
    ranger_index_sha256 = environment$index_sha256,
    ranger_metadata_sha256 = environment$metadata_sha256,
    ranger_archive_sha256 = environment$archive_sha256,
    ranger_installed_content_sha256 = environment$installed_content_sha256,
    ranger_provenance_id = if (nrow(registration)) registration$ranger_provenance_id[[1L]] else "",
    model_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/model_registry.csv"),
    feature_contract_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/feature_contract.csv"),
    context_ablation_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/context_ablation_registry.csv"),
    centroid_registry_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/country_centroids.csv"),
    centroid_metadata_sha256 = .hybrid_runner_file_sha256("data/benchmark/phase11/country_centroids_metadata.csv"),
    registration_sha256 = paste(as.character(registration$registration_sha256), collapse = "|"),
    settings_sha256 = paste(as.character(registration$settings_sha256), collapse = "|"),
    candidate_id = paste(candidate_order, collapse = "|"),
    candidate_ids = paste(candidate_order, collapse = "|"),
    output_dir = if (is.null(output_dir)) "" else output_dir,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- c(
    adapter,
    list(scores = scores, run_manifest = run_manifest, environment = environment)
  )
  validate_hybrid_challenger_bundle(result)
  result
}
