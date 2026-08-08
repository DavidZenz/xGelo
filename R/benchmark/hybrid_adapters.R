#' Phase 11 registered adapters for hybrid challenger candidates

.hybrid_adapter_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists(".phase11_protocol_root", mode = "function")) {
    .phase11_protocol_root(".")
  } else {
    normalizePath(".", mustWork = TRUE)
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 11 hybrid adapter dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing_after <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing_after)) stop("Phase 11 hybrid adapter dependency did not define: ", paste(missing_after, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

hybrid_phase11_candidate_ids <- function(protocol = NULL) {
  if (is.null(protocol)) {
    .hybrid_adapter_source_if_missing("R/benchmark/hybrid_protocol.R", c("load_and_validate_hybrid_protocol"))
    protocol <- load_and_validate_hybrid_protocol()
  }
  ids <- as.character(protocol$model_registry$candidate_id)
  ids
}

.hybrid_adapter_registration <- function(protocol, candidate_id) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("hybrid_registration", "validate_hybrid_model_registry")
  )
  if (!inherits(protocol, "validated_hybrid_protocol") || !isTRUE(protocol$valid)) {
    stop("hybrid adapter requires a validated Phase 11 protocol", call. = FALSE)
  }
  allowed <- hybrid_phase11_candidate_ids(protocol)
  if (length(candidate_id) != 1L || !as.character(candidate_id) %in% allowed) {
    stop("unknown or inactive Phase 11 hybrid candidate_id", call. = FALSE)
  }
  hybrid_registration(protocol, candidate_id)
}

.hybrid_adapter_is_context <- function(registration) {
  is.data.frame(registration) && nrow(registration) == 1L &&
    grepl("context", as.character(registration$candidate_id[[1L]]), fixed = TRUE) &&
    !grepl("xg_gated", as.character(registration$candidate_id[[1L]]), fixed = TRUE)
}

.hybrid_adapter_is_xg <- function(registration) {
  is.data.frame(registration) && nrow(registration) == 1L &&
    grepl("xg_gated", as.character(registration$candidate_id[[1L]]), fixed = TRUE)
}

.hybrid_adapter_is_structural <- function(registration) {
  is.data.frame(registration) && nrow(registration) == 1L &&
    identical(
      as.character(registration$candidate_id[[1L]]),
      "phase11_structural_sparse_prior_open"
    )
}

.hybrid_adapter_xg_gate <- function(protocol, registration) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("validate_phase11_xg_gate_manifest", ".phase11_file_sha256")
  )
  if (!"xg_gate_manifest" %in% names(protocol)) {
    stop("D-12 xG-gated candidate requires a registered xG gate manifest", call. = FALSE)
  }
  gate <- protocol$xg_gate_manifest
  validate_phase11_xg_gate_manifest(gate)
  if (as.character(registration$gate_id[[1L]]) != as.character(gate$gate_id[[1L]]) ||
      as.character(registration$candidate_id[[1L]]) != as.character(gate$candidate_id[[1L]])) {
    stop("xG candidate registration does not match the D-12 gate manifest", call. = FALSE)
  }
  invisible(gate)
}

.hybrid_xg_registered_settings <- function(settings, registration) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol", "hybrid_registration")
  )
  .hybrid_adapter_source_if_missing("R/forecast/hybrid_rf.R", c("hybrid_rf_registered_settings"))
  base_protocol <- load_and_validate_hybrid_protocol()
  base_registration <- hybrid_registration(base_protocol, "phase11_rf_dynamic_elo_open")
  base_settings <- settings[setdiff(names(settings), c("feature_set_id", "rf_feature_set_id"))]
  resolved <- hybrid_rf_registered_settings(base_settings, base_registration, candidate_id = "phase11_rf_dynamic_elo_open")
  resolved$candidate_id <- as.character(registration$candidate_id[[1L]])
  resolved$feature_set_id <- as.character(registration$feature_set_id[[1L]])
  resolved$rf_feature_set_id <- as.character(registration$rf_feature_set_id[[1L]])
  resolved$registration_sha256 <- as.character(registration$registration_sha256[[1L]])
  resolved$settings_sha256 <- as.character(registration$settings_sha256[[1L]])
  resolved$gate_id <- as.character(registration$gate_id[[1L]])
  resolved$gate_parent_sha256 <- as.character(registration$gate_parent_sha256[[1L]])
  resolved
}

.hybrid_adapter_structural_manifest <- function(protocol, registration) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c(
      "validate_phase11_structural_prior_manifest",
      "validate_phase11_structural_source_manifest",
      ".phase11_file_sha256"
    )
  )
  if (!"structural_prior_manifest" %in% names(protocol)) {
    stop("Structural-prior candidate requires a registered structural prior manifest", call. = FALSE)
  }
  manifest <- validate_phase11_structural_prior_manifest(protocol$structural_prior_manifest)
  if (as.character(registration$candidate_id[[1L]]) != as.character(manifest$candidate_id[[1L]]) ||
      as.character(registration$structural_prior_manifest_sha256[[1L]]) !=
        .phase11_file_sha256("data/benchmark/phase11/structural_prior_manifest.csv")) {
    stop("Structural-prior registration does not parent the checked manifest", call. = FALSE)
  }
  loaded <- validate_phase11_structural_source_manifest(
    snapshot_path = as.character(manifest$snapshot_path[[1L]]),
    metadata_path = as.character(manifest$metadata_path[[1L]]),
    checksums_path = as.character(manifest$checksums_path[[1L]]),
    evidence_cutoff_exclusive = as.Date(manifest$evidence_cutoff_exclusive[[1L]]),
    registered_vintage_id = as.character(manifest$snapshot_vintage_id[[1L]])
  )
  expected <- c(
    source_snapshot_sha256 = attr(loaded, "structural_snapshot_sha256"),
    source_metadata_sha256 = attr(loaded, "structural_metadata_sha256"),
    source_rows_sha256 = attr(loaded, "structural_rows_sha256"),
    checksum_registry_sha256 = .phase11_file_sha256(as.character(manifest$checksums_path[[1L]]))
  )
  actual <- vapply(
    manifest[1L, names(expected), drop = FALSE], as.character, character(1)
  )
  if (any(tolower(actual) != tolower(expected))) {
    stop("Structural-prior manifest does not match its checked source parents", call. = FALSE)
  }
  list(manifest = manifest[1L, , drop = FALSE], snapshots = loaded)
}

.hybrid_structural_registered_settings <- function(settings, registration, manifest) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol", "hybrid_registration")
  )
  .hybrid_adapter_source_if_missing("R/forecast/hybrid_rf.R", c("hybrid_rf_registered_settings"))
  base_protocol <- load_and_validate_hybrid_protocol()
  base_registration <- hybrid_registration(base_protocol, "phase11_rf_dynamic_elo_open")
  base_settings <- settings[setdiff(names(settings), c("feature_set_id", "rf_feature_set_id"))]
  resolved <- hybrid_rf_registered_settings(
    base_settings, base_registration, candidate_id = "phase11_rf_dynamic_elo_open"
  )
  resolved$candidate_id <- as.character(registration$candidate_id[[1L]])
  resolved$feature_set_id <- as.character(base_registration$feature_set_id[[1L]])
  resolved$rf_feature_set_id <- as.character(base_registration$rf_feature_set_id[[1L]])
  resolved$registration_sha256 <- as.character(registration$registration_sha256[[1L]])
  resolved$settings_sha256 <- as.character(registration$settings_sha256[[1L]])
  resolved$distribution_id_prefix <- as.character(registration$candidate_id[[1L]])
  resolved$structural_prior_manifest_sha256 <- as.character(
    registration$structural_prior_manifest_sha256[[1L]]
  )
  resolved$structural_snapshot_vintage_id <- as.character(
    manifest$snapshot_vintage_id[[1L]]
  )
  resolved$prior_strength <- as.numeric(manifest$prior_strength[[1L]])
  resolved$prior_scale <- as.numeric(manifest$prior_scale[[1L]])
  resolved$prior_bounds <- c(
    as.numeric(manifest$prior_lower_bound[[1L]]),
    as.numeric(manifest$prior_upper_bound[[1L]])
  )
  resolved$evidence_half_life_days <- as.numeric(manifest$evidence_half_life_days[[1L]])
  resolved$effective_count_formula <- as.character(manifest$effective_count_formula[[1L]])
  resolved$feature_rule <- as.character(registration$feature_rule[[1L]])
  resolved$panel_rule <- as.character(registration$panel_rule[[1L]])
  resolved
}

.hybrid_structural_fallback_settings <- function(settings, registration) {
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R", c("hybrid_rf_registered_settings")
  )
  base_registration <- tryCatch({
    .hybrid_adapter_source_if_missing(
      "R/benchmark/hybrid_protocol.R", c("canonical_phase11_model_registry")
    )
    canonical_phase11_model_registry()
  }, error = function(error) NULL)
  resolved <- if (!is.null(base_registration)) {
    tryCatch(
      hybrid_rf_registered_settings(
        settings[setdiff(names(settings), c("feature_set_id", "rf_feature_set_id"))],
        base_registration,
        candidate_id = "phase11_rf_dynamic_elo_open"
      ),
      error = function(error) NULL
    )
  } else NULL
  if (is.null(resolved)) {
    resolved <- list(
      support_max = 40L,
      ranger_package = as.character(registration$ranger_package[[1L]]),
      ranger_version = as.character(registration$ranger_version[[1L]]),
      ranger_provenance_id = as.character(registration$ranger_provenance_id[[1L]]),
      provenance_path = "data/benchmark/phase11/ranger_provenance.csv"
    )
  }
  resolved$candidate_id <- as.character(registration$candidate_id[[1L]])
  resolved$feature_set_id <- as.character(registration$feature_set_id[[1L]])
  resolved$rf_feature_set_id <- as.character(registration$rf_feature_set_id[[1L]])
  resolved$registration_sha256 <- as.character(registration$registration_sha256[[1L]])
  resolved$settings_sha256 <- as.character(registration$settings_sha256[[1L]])
  resolved$distribution_id_prefix <- as.character(registration$candidate_id[[1L]])
  resolved$structural_prior_manifest_sha256 <- as.character(
    registration$structural_prior_manifest_sha256[[1L]]
  )
  resolved$structural_snapshot_vintage_id <- as.character(
    registration$structural_snapshot_vintage_id[[1L]]
  )
  resolved$prior_strength <- suppressWarnings(as.numeric(registration$prior_strength[[1L]]))
  resolved$evidence_half_life_days <- 730
  resolved$prior_bounds <- c(0.65, 1.55)
  resolved
}

.hybrid_structural_inactive_manifests <- function(
    registration, fixtures, run_id, settings, reason, manifest = NULL
) {
  boundaries <- unique(fixtures[c("edition_id", "track_id", "boundary_id", "evidence_cutoff_exclusive")])
  rows <- lapply(seq_len(nrow(boundaries)), function(index) {
    boundary <- boundaries[index, , drop = FALSE]
    cutoff <- as.Date(boundary$evidence_cutoff_exclusive[[1L]])
    prior_date <- cutoff - 1
    data.frame(
      model_manifest_id = paste(run_id, registration$candidate_id[[1L]], boundary$boundary_id[[1L]], sep = "__"),
      run_id = run_id,
      model_id = registration$candidate_id[[1L]],
      edition_id = boundary$edition_id[[1L]],
      track_id = boundary$track_id[[1L]],
      boundary_id = boundary$boundary_id[[1L]],
      fit_status = "inactive",
      fit_row_count = 0L,
      fit_min_date = prior_date,
      fit_max_date = prior_date,
      max_result_date = prior_date,
      max_feature_source_date = prior_date,
      evidence_cutoff_exclusive = cutoff,
      active_predictors = "",
      dropped_predictors_with_reason = paste0("structural prior inactive: ", reason),
      model_family = as.character(registration$model_family[[1L]]),
      convergence_status = "not_run",
      fallback_status = "inactive_structural_validation_failed",
      adapter_version = as.character(registration$adapter_version[[1L]]),
      code_version = "phase11-v1",
      r_version = as.character(getRversion()),
      package_versions = "",
      registration_sha256 = settings$registration_sha256,
      settings_sha256 = settings$settings_sha256,
      parent_hashes = .phase11_sha256(paste(
        settings$registration_sha256, settings$settings_sha256,
        if (!is.null(manifest)) manifest$checksum_registry_sha256[[1L]] else "",
        boundary$boundary_id[[1L]], sep = "|"
      )),
      mean_parent_candidate_id = as.character(registration$mean_parent_candidate_id[[1L]]),
      mean_prediction_hash = .phase11_sha256(character()),
      ranger_package = settings$ranger_package,
      ranger_version = settings$ranger_version,
      ranger_provenance_id = settings$ranger_provenance_id,
      research_only = TRUE,
      wc2026_sealed = TRUE,
      mode_id = registration$mode_id[[1L]],
      open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
      score_support_g = as.integer(registration$score_support_g[[1L]]),
      context_feature_set_id = "",
      removed_feature_id = "",
      context_parent_hashes = "",
      gate_id = "",
      gate_parent_sha256 = "",
      structural_prior_manifest_sha256 = as.character(registration$structural_prior_manifest_sha256[[1L]]),
      structural_snapshot_vintage_id = as.character(registration$structural_snapshot_vintage_id[[1L]]),
      structural_diagnostics = "",
      active_status = "inactive",
      score_status = "no_score_structural_validation_failed",
      inactive_reason = reason,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

.hybrid_structural_inactive_result <- function(
    registration, fixtures, seed_registry, run_id, protocol, settings, reason, manifest = NULL
) {
  manifests <- .hybrid_structural_inactive_manifests(
    registration, fixtures, run_id, settings, reason, manifest
  )
  validate_model_manifests(manifests)
  evidence <- data.frame(
    candidate_id = as.character(registration$candidate_id[[1L]]),
    feature_set_id = as.character(registration$feature_set_id[[1L]]),
    removed_feature_id = "",
    panel_id = as.character(registration$panel_id[[1L]]),
    open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
    rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
    score_support_g = as.integer(registration$score_support_g[[1L]]),
    context_parent_hashes = "",
    gate_id = "",
    gate_parent_sha256 = "",
    structural_prior_manifest_sha256 = as.character(registration$structural_prior_manifest_sha256[[1L]]),
    structural_snapshot_vintage_id = as.character(registration$structural_snapshot_vintage_id[[1L]]),
    prior_strength = as.numeric(registration$prior_strength[[1L]]),
    active_status = "inactive",
    score_status = "no_score_structural_validation_failed",
    coverage = NA_real_,
    variance = NA_real_,
    provenance = NA,
    score_row_count = 0L,
    inactive_reason = reason,
    error_reason = reason,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    candidate_id = as.character(registration$candidate_id[[1L]]),
    registration = registration,
    settings = settings,
    protocol = protocol,
    predictions = data.frame(stringsAsFactors = FALSE),
    distributions = data.frame(stringsAsFactors = FALSE),
    means = data.frame(stringsAsFactors = FALSE),
    manifests = manifests,
    feature_coverage = data.frame(stringsAsFactors = FALSE),
    seed_registry = seed_registry,
    environment = NULL,
    inactive = TRUE,
    inactive_evidence = evidence,
    structural_prior_manifest = manifest,
    structural_inactive_reason = reason,
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}

.hybrid_xg_inactive_manifests <- function(registration, fixtures, run_id, gate, settings) {
  date_col <- if ("actual_completion_date" %in% names(fixtures)) "actual_completion_date" else "evidence_cutoff_exclusive"
  boundaries <- unique(fixtures[c("edition_id", "track_id", "boundary_id", "evidence_cutoff_exclusive")])
  rows <- lapply(seq_len(nrow(boundaries)), function(index) {
    boundary <- boundaries[index, , drop = FALSE]
    cutoff <- as.Date(boundary$evidence_cutoff_exclusive[[1L]])
    prior_date <- cutoff - 1
    data.frame(
      model_manifest_id = paste(run_id, registration$candidate_id[[1L]], boundary$boundary_id[[1L]], sep = "__"),
      run_id = run_id,
      model_id = registration$candidate_id[[1L]],
      edition_id = boundary$edition_id[[1L]],
      track_id = boundary$track_id[[1L]],
      boundary_id = boundary$boundary_id[[1L]],
      fit_status = "inactive",
      fit_row_count = 0L,
      fit_min_date = prior_date,
      fit_max_date = prior_date,
      max_result_date = prior_date,
      max_feature_source_date = prior_date,
      evidence_cutoff_exclusive = cutoff,
      active_predictors = "",
      dropped_predictors_with_reason = "xG gate failed: no model fit or score rows",
      model_family = as.character(registration$model_family[[1L]]),
      convergence_status = "not_run",
      fallback_status = "inactive_gate_failed",
      adapter_version = as.character(registration$adapter_version[[1L]]),
      code_version = "phase11-v1",
      r_version = as.character(getRversion()),
      package_versions = "",
      registration_sha256 = settings$registration_sha256,
      settings_sha256 = settings$settings_sha256,
      parent_hashes = .phase11_sha256(paste(
        settings$registration_sha256, settings$settings_sha256,
        gate$gate_parent_sha256[[1L]], boundary$boundary_id[[1L]], sep = "|"
      )),
      mean_parent_candidate_id = registration$candidate_id[[1L]],
      mean_prediction_hash = .phase11_sha256(character()),
      ranger_package = settings$ranger_package,
      ranger_version = settings$ranger_version,
      ranger_provenance_id = settings$ranger_provenance_id,
      research_only = TRUE,
      wc2026_sealed = TRUE,
      mode_id = registration$mode_id[[1L]],
      open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
      score_support_g = as.integer(registration$score_support_g[[1L]]),
      context_feature_set_id = "",
      removed_feature_id = "",
      context_parent_hashes = "",
      gate_id = as.character(gate$gate_id[[1L]]),
      gate_parent_sha256 = as.character(gate$gate_parent_sha256[[1L]]),
      structural_prior_manifest_sha256 = "",
      structural_snapshot_vintage_id = "",
      structural_diagnostics = "",
      active_status = "inactive",
      score_status = "no_score_gate_failed",
      inactive_reason = as.character(gate$inactive_reason[[1L]]),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

.hybrid_xg_inactive_result <- function(registration, fixtures, seed_registry, run_id, protocol, settings, gate) {
  manifests <- .hybrid_xg_inactive_manifests(registration, fixtures, run_id, gate, settings)
  validate_model_manifests(manifests)
  evidence <- data.frame(
    candidate_id = as.character(registration$candidate_id[[1L]]),
    feature_set_id = as.character(registration$feature_set_id[[1L]]),
    removed_feature_id = "",
    panel_id = as.character(registration$panel_id[[1L]]),
    open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
    rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
    score_support_g = as.integer(registration$score_support_g[[1L]]),
    context_parent_hashes = as.character(if ("context_parent_hashes" %in% names(registration)) registration$context_parent_hashes[[1L]] else ""),
    gate_id = as.character(gate$gate_id[[1L]]),
    gate_parent_sha256 = as.character(gate$gate_parent_sha256[[1L]]),
    structural_prior_manifest_sha256 = "",
    structural_snapshot_vintage_id = "",
    prior_strength = NA_real_,
    active_status = "inactive",
    score_status = "no_score_gate_failed",
    coverage = as.numeric(gate$coverage[[1L]]),
    variance = as.numeric(gate$variance[[1L]]),
    provenance = as.logical(gate$provenance[[1L]]),
    inactive_reason = as.character(gate$inactive_reason[[1L]]),
    error_reason = "",
    score_row_count = 0L,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    candidate_id = as.character(registration$candidate_id[[1L]]),
    registration = registration,
    settings = settings,
    protocol = protocol,
    predictions = data.frame(stringsAsFactors = FALSE),
    distributions = data.frame(stringsAsFactors = FALSE),
    means = data.frame(stringsAsFactors = FALSE),
    manifests = manifests,
    feature_coverage = data.frame(stringsAsFactors = FALSE),
    seed_registry = seed_registry,
    environment = NULL,
    inactive = TRUE,
    inactive_evidence = evidence,
    gate = gate,
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}

.hybrid_adapter_context_removed_feature <- function(registration) {
  if (!.hybrid_adapter_is_context(registration) || !"removed_feature_id" %in% names(registration)) return("")
  value <- as.character(registration$removed_feature_id[[1L]])
  if (is.na(value)) "" else value
}

#' Normalize only benchmark identity and chronology fields; source features are
#' never imputed by the adapter.
#' @export
hybrid_normalize_fixtures <- function(fixtures) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_contract_require_columns")
  )
  required <- c(
    "edition_id", "fixture_id", "boundary_id", "home_team_id", "away_team_id",
    "venue_role", "actual_completion_date", "evidence_cutoff_exclusive"
  )
  benchmark_contract_require_columns(fixtures, required, "Hybrid adapter fixtures")
  result <- fixtures
  result$edition_id <- as.character(result$edition_id)
  result$fixture_id <- as.character(result$fixture_id)
  result$boundary_id <- as.character(result$boundary_id)
  result$home_team_id <- as.character(result$home_team_id)
  result$away_team_id <- as.character(result$away_team_id)
  result$venue_role <- as.character(result$venue_role)
  if (any(is.na(result$fixture_id) | !nzchar(result$fixture_id)) || anyDuplicated(result$fixture_id)) {
    stop("Hybrid adapter fixture IDs must be unique and non-empty", call. = FALSE)
  }
  if (any(is.na(result$edition_id) | !nzchar(result$edition_id)) ||
      any(is.na(result$boundary_id) | !nzchar(result$boundary_id)) ||
      any(is.na(result$home_team_id) | !nzchar(result$home_team_id)) ||
      any(is.na(result$away_team_id) | !nzchar(result$away_team_id)) ||
      any(is.na(result$venue_role) | !nzchar(result$venue_role))) {
    stop("Hybrid adapter fixture identity is incomplete", call. = FALSE)
  }
  result$actual_completion_date <- as.Date(result$actual_completion_date)
  result$evidence_cutoff_exclusive <- as.Date(result$evidence_cutoff_exclusive)
  if (anyNA(result$actual_completion_date) || anyNA(result$evidence_cutoff_exclusive) ||
      any(result$evidence_cutoff_exclusive > result$actual_completion_date)) {
    stop("Hybrid adapter fixture chronology is invalid", call. = FALSE)
  }
  if (!"track_id" %in% names(result)) result$track_id <- "frozen"
  result$track_id <- as.character(result$track_id)
  if (any(is.na(result$track_id) | !nzchar(result$track_id))) stop("Hybrid adapter track_id values must be explicit", call. = FALSE)
  if (!"forecast_sequence" %in% names(result)) result$forecast_sequence <- seq_len(nrow(result))
  result$forecast_sequence <- as.integer(result$forecast_sequence)
  if (anyNA(result$forecast_sequence) || anyDuplicated(result[c("track_id", "forecast_sequence")])) {
    stop("Hybrid adapter forecast_sequence values must be unique within each track", call. = FALSE)
  }
  if (!"result_cutoff_exclusive" %in% names(result)) {
    result$result_cutoff_exclusive <- result$evidence_cutoff_exclusive
  } else {
    result$result_cutoff_exclusive <- as.Date(result$result_cutoff_exclusive)
  }
  if (anyNA(result$result_cutoff_exclusive) || any(result$result_cutoff_exclusive > result$evidence_cutoff_exclusive)) {
    stop("Hybrid adapter result cutoffs must not exceed evidence cutoffs", call. = FALSE)
  }
  if (any(result$home_team_id == result$away_team_id)) stop("Hybrid adapter fixtures cannot have identical teams", call. = FALSE)
  rownames(result) <- NULL
  result
}

hybrid_default_seed_registry <- function(fixtures, seed = 920001L) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_seed_key_sha256", "validate_seed_registry", "benchmark_contract_row_hash")
  )
  fixtures <- hybrid_normalize_fixtures(fixtures)
  seed <- as.integer(seed)
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Hybrid seed base must be one non-negative integer", call. = FALSE)
  registry <- data.frame(
    schema_version = "1.0",
    seed_id = paste0("phase11_seed__", fixtures$edition_id, "__", fixtures$fixture_id),
    purpose = "phase11_hybrid_challenger_common_random_number",
    edition_id = fixtures$edition_id,
    boundary_id = fixtures$boundary_id,
    fixture_id = fixtures$fixture_id,
    seed = seed + seq_len(nrow(fixtures)) - 1L,
    model_independent = TRUE,
    seed_key_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  registry$seed_key_sha256 <- benchmark_seed_key_sha256(registry)
  validate_seed_registry(registry)
  registry
}

.hybrid_adapter_seed_registry <- function(fixtures, seed_registry = NULL) {
  if (is.null(seed_registry)) return(hybrid_default_seed_registry(fixtures))
  .hybrid_adapter_source_if_missing("R/benchmark/contracts.R", c("validate_seed_registry"))
  validate_seed_registry(seed_registry)
  required <- c("edition_id", "boundary_id", "fixture_id")
  if (any(!fixtures$fixture_id %in% seed_registry$fixture_id)) stop("Hybrid seed registry is missing fixture seeds", call. = FALSE)
  seed_index <- match(fixtures$fixture_id, seed_registry$fixture_id)
  if (any(as.character(seed_registry$edition_id[seed_index]) != fixtures$edition_id) ||
      any(as.character(seed_registry$boundary_id[seed_index]) != fixtures$boundary_id)) {
    stop("Hybrid seed registry fixture identity does not match the adapter fixtures", call. = FALSE)
  }
  seed_registry
}

.hybrid_manifest_rows <- function(fit, registration, fixtures, history, run_id, mean_predictions) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("benchmark_contract_sha256", "validate_model_manifests")
  )
  date_candidates <- c("actual_completion_date", "date", "match_date", "result_date")
  date_col <- intersect(date_candidates, names(history))[[1L]]
  history_dates <- as.Date(history[[date_col]])
  boundaries <- unique(fixtures[c("edition_id", "track_id", "boundary_id", "evidence_cutoff_exclusive")])
  rows <- lapply(seq_len(nrow(boundaries)), function(index) {
    boundary <- boundaries[index, , drop = FALSE]
    cutoff <- as.Date(boundary$evidence_cutoff_exclusive[[1L]])
    eligible <- history_dates[!is.na(history_dates) & history_dates < cutoff]
    if (!length(eligible)) stop("Hybrid manifest cannot be created without pre-cutoff history", call. = FALSE)
    boundary_means <- mean_predictions[mean_predictions$boundary_id == boundary$boundary_id[[1L]], , drop = FALSE]
    mean_hash <- if (nrow(boundary_means)) {
      benchmark_contract_sha256(sort(as.character(boundary_means$mean_prediction_hash)))
    } else {
      benchmark_contract_sha256(character())
    }
    model_manifest_id <- paste(run_id, registration$candidate_id[[1L]], boundary$boundary_id[[1L]], sep = "__")
    data.frame(
      model_manifest_id = model_manifest_id,
      run_id = run_id,
      model_id = registration$candidate_id[[1L]],
      edition_id = boundary$edition_id[[1L]],
      track_id = boundary$track_id[[1L]],
      boundary_id = boundary$boundary_id[[1L]],
      fit_status = "ok",
      fit_row_count = fit$fit_row_count,
      fit_min_date = min(eligible),
      fit_max_date = max(eligible),
      max_result_date = max(eligible),
      max_feature_source_date = fit$max_feature_source_date,
      evidence_cutoff_exclusive = cutoff,
      active_predictors = paste(fit$active_predictors, collapse = "|"),
      dropped_predictors_with_reason = if (length(fit$dropped_predictors)) {
        paste(fit$dropped_predictors, collapse = "|")
      } else "",
      model_family = fit$model_family,
      convergence_status = fit$convergence_status,
      fallback_status = fit$fallback_status,
      adapter_version = registration$adapter_version[[1L]],
      code_version = "phase11-v1",
      r_version = as.character(getRversion()),
      package_versions = paste0("ranger=", fit$ranger_version, ";digest=", as.character(utils::packageVersion("digest"))),
      registration_sha256 = fit$registration_sha256,
      settings_sha256 = fit$settings_sha256,
      parent_hashes = benchmark_contract_sha256(c(
        fit$registration_sha256, fit$settings_sha256, fit$fit_data_sha256,
        if (!is.null(fit$context_parent_hashes)) fit$context_parent_hashes else "",
        boundary$boundary_id[[1L]]
      )),
      mean_parent_candidate_id = registration$candidate_id[[1L]],
      mean_prediction_hash = mean_hash,
      ranger_package = fit$ranger_package,
      ranger_version = fit$ranger_version,
      ranger_provenance_id = fit$ranger_provenance_id,
      research_only = TRUE,
      wc2026_sealed = TRUE,
      mode_id = registration$mode_id[[1L]],
      open_fixture_count = as.integer(registration$open_fixture_count[[1L]]),
      rich_fixture_count = as.integer(registration$rich_fixture_count[[1L]]),
      score_support_g = as.integer(registration$score_support_g[[1L]]),
      context_feature_set_id = if ("context_feature_set_id" %in% names(registration)) {
        as.character(registration$context_feature_set_id[[1L]])
      } else "",
      removed_feature_id = if ("removed_feature_id" %in% names(registration)) {
        as.character(registration$removed_feature_id[[1L]])
      } else "",
      context_parent_hashes = if (!is.null(fit$context_parent_hashes)) fit$context_parent_hashes else "",
      gate_id = if (!is.null(fit$gate_id)) as.character(fit$gate_id) else "",
      gate_parent_sha256 = if (!is.null(fit$gate_parent_sha256)) as.character(fit$gate_parent_sha256) else "",
      structural_prior_manifest_sha256 = if (!is.null(fit$structural_prior_manifest_sha256)) {
        as.character(fit$structural_prior_manifest_sha256)
      } else "",
      structural_snapshot_vintage_id = if (!is.null(fit$structural_snapshot_vintage_id)) {
        as.character(fit$structural_snapshot_vintage_id)
      } else "",
      structural_diagnostics = if (!is.null(fit$structural_diagnostics)) {
        as.character(fit$structural_diagnostics)
      } else "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

.hybrid_adapter_markets <- function(distributions, fixture_ids) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c("derive_benchmark_markets")
  )
  rows <- lapply(fixture_ids, function(fixture_id) {
    grid <- distributions[distributions$mean_parent_id == fixture_id, , drop = FALSE]
    if (!nrow(grid)) stop("Hybrid distributions are missing fixture ", fixture_id, call. = FALSE)
    market <- derive_benchmark_markets(grid)
    data.frame(
      fixture_id = fixture_id,
      score_distribution_id = as.character(grid$score_distribution_id[[1L]]),
      as.data.frame(market, stringsAsFactors = FALSE),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

.hybrid_context_base_feature_ids <- function() {
  c(
    "home_attack_effect", "home_defence_effect",
    "away_attack_effect", "away_defence_effect", "elo_diff"
  )
}

.hybrid_context_all_feature_ids <- function() {
  .hybrid_adapter_source_if_missing(
    "R/forecast/context_features.R", c("phase11_context_feature_names")
  )
  c(.hybrid_context_base_feature_ids(), phase11_context_feature_names())
}

.hybrid_context_complete_rows <- function(data) {
  features <- phase11_context_feature_names()
  complete <- vapply(seq_len(nrow(data)), function(index) {
    all(vapply(features, function(feature) {
      isTRUE(as.logical(data[[paste0(feature, "__value_present")]][index])) &&
        !isTRUE(as.logical(data[[paste0(feature, "__imputed")]][index]))
    }, logical(1)))
  }, logical(1))
  complete
}

.hybrid_context_registered_settings <- function(settings, registration) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol", "hybrid_registration")
  )
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R",
    c("hybrid_rf_registered_settings")
  )
  if (!is.list(settings)) stop("Context RF settings must be a named list", call. = FALSE)
  if ("feature_set_id" %in% names(settings) &&
      !identical(as.character(settings$feature_set_id[[1L]]), as.character(registration$feature_set_id[[1L]]))) {
    stop("Context RF feature_set_id is not registered for this candidate", call. = FALSE)
  }
  if ("rf_feature_set_id" %in% names(settings) &&
      !identical(as.character(settings$rf_feature_set_id[[1L]]), as.character(registration$rf_feature_set_id[[1L]]))) {
    stop("Context RF rf_feature_set_id is not registered for this candidate", call. = FALSE)
  }
  base_protocol <- load_and_validate_hybrid_protocol()
  base_registration <- hybrid_registration(base_protocol, "phase11_rf_dynamic_elo_open")
  base_settings <- settings[setdiff(names(settings), c("feature_set_id", "rf_feature_set_id"))]
  resolved <- hybrid_rf_registered_settings(
    base_settings, base_registration, candidate_id = "phase11_rf_dynamic_elo_open"
  )
  resolved$candidate_id <- as.character(registration$candidate_id[[1L]])
  resolved$feature_set_id <- as.character(registration$feature_set_id[[1L]])
  resolved$rf_feature_set_id <- as.character(registration$rf_feature_set_id[[1L]])
  resolved$registration_sha256 <- as.character(registration$registration_sha256[[1L]])
  resolved$settings_sha256 <- as.character(registration$settings_sha256[[1L]])
  resolved
}

.hybrid_context_prepare_boundary <- function(history, fixtures, centroid_path = NULL, metadata_path = NULL) {
  .hybrid_adapter_source_if_missing(
    "R/forecast/context_features.R",
    c("load_phase11_country_centroids", "build_open_context_features", "validate_open_context_feature_evidence")
  )
  centroids <- if (is.null(centroid_path)) {
    load_phase11_country_centroids()
  } else {
    load_phase11_country_centroids(centroid_path, metadata_path)
  }
  history_date_col <- .phase11_context_date_column(history, "Context history")
  history_dates <- as.Date(history[[history_date_col]])
  boundary_cutoff <- as.Date(unique(fixtures$evidence_cutoff_exclusive))
  if (length(boundary_cutoff) != 1L || is.na(boundary_cutoff)) {
    stop("Context boundary requires one exclusive evidence cutoff", call. = FALSE)
  }
  history <- history[!is.na(history_dates) & history_dates < boundary_cutoff, , drop = FALSE]
  if (!nrow(history)) stop("Context boundary has no pre-cutoff history", call. = FALSE)
  history_context <- build_open_context_features(
    fixtures = history, history = history, country_centroids = centroids,
    strict_common_panel = FALSE
  )
  fixture_context <- build_open_context_features(
    fixtures = fixtures, history = history, country_centroids = centroids,
    strict_common_panel = TRUE
  )
  list(
    history = history,
    history_context = history_context,
    fixture_context = fixture_context,
    centroids = centroids,
    parent_hashes = paste(
      attr(centroids, "phase11_context_registry_sha256"),
      attr(centroids, "phase11_context_metadata_sha256"),
      sep = "#"
    )
  )
}

.hybrid_context_fit <- function(history_context, cutoff, settings, registration) {
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R",
    c("hybrid_rf_registered_settings", "hybrid_rf_validate_evidence", ".hybrid_rf_goal_columns", ".hybrid_rf_date_column")
  )
  .hybrid_adapter_source_if_missing(
    "R/benchmark/challenger_preflight.R", c("require_hybrid_environment")
  )
  settings <- .hybrid_context_registered_settings(settings, registration)
  environment <- require_hybrid_environment(settings$provenance_path, offline = TRUE)
  if (!is.data.frame(history_context) || !nrow(history_context)) stop("Context RF history must contain rows", call. = FALSE)
  date_col <- .hybrid_rf_date_column(history_context, "Context RF history")
  response <- .hybrid_rf_goal_columns(history_context, "Context RF history")
  cutoff <- as.Date(cutoff)
  dates <- as.Date(history_context[[date_col]])
  if (length(cutoff) != 1L || is.na(cutoff) || anyNA(dates)) stop("Context RF chronology is incomplete", call. = FALSE)
  training <- history_context[dates < cutoff, , drop = FALSE]
  if (!nrow(training)) stop("Context RF history has no rows before the exclusive cutoff", call. = FALSE)
  complete <- .hybrid_context_complete_rows(training)
  if (!all(complete)) training <- training[complete, , drop = FALSE]
  if (!nrow(training)) stop("Context RF has no complete point-in-time context training rows", call. = FALSE)
  hybrid_rf_validate_evidence(
    training, as.Date(training[[date_col]]),
    feature_ids = .hybrid_context_base_feature_ids(), label = "Context RF training history"
  )
  validate_open_context_feature_evidence(training, strict_common_panel = TRUE, date_col = "date")
  context_ids <- phase11_context_feature_names()
  removed <- .hybrid_adapter_context_removed_feature(registration)
  active_context <- setdiff(context_ids, removed)
  feature_ids <- c(.hybrid_context_base_feature_ids(), active_context)
  goals <- training[, unname(response), drop = FALSE]
  for (column in names(goals)) goals[[column]] <- suppressWarnings(as.numeric(goals[[column]]))
  if (any(!is.finite(as.matrix(goals))) || any(as.matrix(goals) < 0)) {
    stop("Context RF training goals must be finite non-negative values", call. = FALSE)
  }
  predictors <- training[, feature_ids, drop = FALSE]
  if ("stage_id" %in% feature_ids) {
    predictors$stage_id <- factor(as.character(predictors$stage_id))
  }
  if (any(vapply(predictors, function(value) anyNA(value), logical(1)))) {
    stop("Context RF training predictors contain missing values", call. = FALSE)
  }
  model_data <- cbind(goals, predictors)
  home_formula <- stats::reformulate(feature_ids, response = response[["home"]])
  away_formula <- stats::reformulate(feature_ids, response = response[["away"]])
  fit_arguments <- list(
    data = model_data, num.trees = settings$`num.trees`, mtry = settings$mtry,
    min.node.size = settings$`min.node.size`, importance = "none", write.forest = TRUE,
    num.threads = 1L, verbose = FALSE, seed = settings$seed
  )
  home_model <- do.call(ranger::ranger, c(list(formula = home_formula), fit_arguments))
  away_arguments <- fit_arguments
  away_arguments$seed <- settings$seed + 1L
  away_model <- do.call(ranger::ranger, c(list(formula = away_formula), away_arguments))
  source_dates <- unlist(lapply(.hybrid_context_all_feature_ids(), function(feature) {
    if (!paste0(feature, "__source_date") %in% names(training)) return(as.Date(NA))
    as.Date(training[[paste0(feature, "__source_date")]])
  }))
  fit_columns <- unique(c("fixture_id", date_col, unname(response), feature_ids))
  fit_columns <- intersect(fit_columns, names(training))
  fit_data_sha256 <- digest::digest(training[, fit_columns, drop = FALSE], algo = "sha256", serialize = TRUE)
  structure(list(
    model_id = as.character(registration$mean_model_id[[1L]]),
    candidate_id = as.character(registration$candidate_id[[1L]]),
    model_family = "random_forest_goal_means",
    panel_id = as.character(registration$panel_id[[1L]]),
    home_model = home_model,
    away_model = away_model,
    feature_ids = feature_ids,
    registered_feature_ids = .hybrid_context_all_feature_ids(),
    active_predictors = feature_ids,
    dropped_predictors = if (nzchar(removed)) removed else character(),
    training_dates = as.Date(training[[date_col]]),
    fit_training_dates = as.Date(training[[date_col]]),
    fit_row_count = nrow(training),
    cutoff = cutoff,
    registration = registration,
    runtime_settings = settings,
    environment = environment,
    ranger_provenance_id = settings$ranger_provenance_id,
    ranger_package = settings$ranger_package,
    ranger_version = settings$ranger_version,
    settings_sha256 = settings$settings_sha256,
    registration_sha256 = settings$registration_sha256,
    max_feature_source_date = max(source_dates[!is.na(source_dates)]),
    convergence_status = "converged",
    fallback_status = if (all(complete)) "none" else "context_training_rows_excluded_for_missing_evidence",
    fit_data_sha256 = fit_data_sha256,
    context_parent_hashes = as.character(registration$context_parent_hashes[[1L]]),
    seed_home = settings$seed,
    seed_away = settings$seed + 1L,
    stage_levels = levels(predictors$stage_id)
  ), class = "hybrid_context_two_goal_rf")
}

.hybrid_context_predict_means <- function(fit, fixtures, settings) {
  if (!inherits(fit, "hybrid_context_two_goal_rf") || !is.list(fit)) {
    stop("Context RF fit must be a hybrid_context_two_goal_rf", call. = FALSE)
  }
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R", c("hybrid_rf_registered_settings", "hybrid_rf_validate_evidence")
  )
  settings <- .hybrid_context_registered_settings(settings, fit$registration)
  if (!is.data.frame(fixtures) || !nrow(fixtures)) stop("Context RF prediction fixtures must contain rows", call. = FALSE)
  cutoff_col <- if ("evidence_cutoff_exclusive" %in% names(fixtures)) "evidence_cutoff_exclusive" else "date"
  cutoffs <- as.Date(fixtures[[cutoff_col]])
  if (anyNA(cutoffs)) stop("Context RF prediction cutoffs are incomplete", call. = FALSE)
  hybrid_rf_validate_evidence(
    fixtures, cutoffs, feature_ids = .hybrid_context_base_feature_ids(),
    label = "Context RF prediction fixtures"
  )
  validate_open_context_feature_evidence(fixtures, strict_common_panel = TRUE, date_col = "date")
  predictor_data <- fixtures[, fit$feature_ids, drop = FALSE]
  if ("stage_id" %in% fit$feature_ids) {
    predictor_data$stage_id <- factor(as.character(predictor_data$stage_id), levels = fit$stage_levels)
  }
  if (anyNA(predictor_data)) stop("Context RF prediction contains an unseen or missing stage", call. = FALSE)
  home_means <- as.numeric(stats::predict(fit$home_model, data = predictor_data)$predictions)
  away_means <- as.numeric(stats::predict(fit$away_model, data = predictor_data)$predictions)
  home_means <- pmax(home_means, .Machine$double.eps)
  away_means <- pmax(away_means, .Machine$double.eps)
  if (any(!is.finite(home_means) | !is.finite(away_means))) stop("Context RF prediction produced non-finite goal means", call. = FALSE)
  identity_columns <- intersect(
    c("fixture_id", "edition_id", "track_id", "boundary_id", "home_team_id", "away_team_id",
      "venue_role", "actual_completion_date", "evidence_cutoff_exclusive", "date"),
    names(fixtures)
  )
  output <- fixtures[, identity_columns, drop = FALSE]
  for (feature in fit$registered_feature_ids) output[[feature]] <- fixtures[[feature]]
  companions <- unlist(lapply(fit$registered_feature_ids, function(feature) paste0(feature, c(
    "__source_date", "__source_present", "__value_present", "__imputed", "__imputation_reason",
    "__source_id", "__source_vintage", "__derivation_rule", "__parent_hashes", "__license_class"
  ))), use.names = FALSE)
  for (column in companions) output[[column]] <- fixtures[[column]]
  output$mu_home <- home_means
  output$mu_away <- away_means
  output$model_id <- fit$model_id
  output$candidate_id <- fit$candidate_id
  output$panel_id <- fit$panel_id
  output$prediction_status <- "ok"
  output$settings_sha256 <- settings$settings_sha256
  output$registration_sha256 <- settings$registration_sha256
  output$ranger_package <- settings$ranger_package
  output$ranger_version <- settings$ranger_version
  output$ranger_provenance_id <- settings$ranger_provenance_id
  output$context_parent_hashes <- fit$context_parent_hashes
  output$mean_prediction_hash <- vapply(seq_len(nrow(output)), function(index) {
    digest::digest(
      paste(as.character(output$fixture_id[index]), format(home_means[index], digits = 17), format(away_means[index], digits = 17), sep = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  rownames(output) <- NULL
  output
}

.hybrid_context_nb_score_distributions <- function(means, support_max = 40L, settings) {
  .hybrid_adapter_source_if_missing("R/benchmark/baselines.R", c("benchmark_one_distribution"))
  if (!is.data.frame(means) || !nrow(means) || !all(c("fixture_id", "mu_home", "mu_away") %in% names(means))) {
    stop("Context RF means require fixture_id, mu_home, and mu_away", call. = FALSE)
  }
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max != 40L) {
    stop("Context RF score distributions must use sealed G=40 support", call. = FALSE)
  }
  if (anyDuplicated(as.character(means$fixture_id))) stop("Context RF means fixture IDs must be unique", call. = FALSE)
  home <- suppressWarnings(as.numeric(means$mu_home)); away <- suppressWarnings(as.numeric(means$mu_away))
  if (any(!is.finite(home) | home <= 0 | !is.finite(away) | away <= 0)) stop("Context RF means must be finite and positive", call. = FALSE)
  goals <- 0:support_max
  prefix <- if ("distribution_id_prefix" %in% names(settings)) settings$distribution_id_prefix else settings$candidate_id
  grids <- lapply(seq_len(nrow(means)), function(index) {
    home_probability <- stats::dnbinom(goals, size = as.numeric(settings$home_theta), mu = home[[index]])
    away_probability <- stats::dnbinom(goals, size = as.numeric(settings$away_theta), mu = away[[index]])
    raw_tail <- max(0, 1 - sum(home_probability) * sum(away_probability))
    id <- paste0(prefix, "__", as.character(means$fixture_id[index]), "__score")
    grid <- benchmark_one_distribution(id, home_probability, away_probability, raw_tail, support_max)
    grid$mean_parent_id <- as.character(means$fixture_id[index])
    grid$settings_sha256 <- settings$settings_sha256
    grid$registration_sha256 <- settings$registration_sha256
    grid$ranger_provenance_id <- settings$ranger_provenance_id
    grid$context_parent_hashes <- if ("context_parent_hashes" %in% names(settings)) settings$context_parent_hashes else ""
    grid
  })
  result <- do.call(rbind, grids)
  rownames(result) <- NULL
  result
}

.hybrid_structural_apply_boundary <- function(
    base_means, boundary_fixtures, history, cutoff, snapshots, settings
) {
  .hybrid_adapter_source_if_missing(
    "R/forecast/structural_prior.R",
    c(
      "compute_structural_prior_signal", "effective_recent_match_count",
      "apply_structural_sparse_shrinkage"
    )
  )
  teams <- unique(c(
    as.character(boundary_fixtures$home_team_id),
    as.character(boundary_fixtures$away_team_id)
  ))
  signal <- compute_structural_prior_signal(
    snapshots = snapshots,
    team_ids = teams,
    evidence_cutoff_exclusive = cutoff,
    registered_vintage_id = settings$structural_snapshot_vintage_id,
    prior_scale = settings$prior_scale,
    prior_bounds = settings$prior_bounds
  )
  counts <- effective_recent_match_count(
    history = history,
    team_ids = teams,
    evidence_cutoff_exclusive = cutoff,
    evidence_half_life_days = settings$evidence_half_life_days
  )
  home_signal <- signal[match(as.character(boundary_fixtures$home_team_id), signal$team_id), , drop = FALSE]
  away_signal <- signal[match(as.character(boundary_fixtures$away_team_id), signal$team_id), , drop = FALSE]
  home_counts <- counts[match(as.character(boundary_fixtures$home_team_id), counts$team_id), , drop = FALSE]
  away_counts <- counts[match(as.character(boundary_fixtures$away_team_id), counts$team_id), , drop = FALSE]
  if (anyNA(home_signal$structural_prior) || anyNA(away_signal$structural_prior) ||
      anyNA(home_counts$effective_match_count) || anyNA(away_counts$effective_match_count)) {
    stop("Structural prior could not resolve point-in-time team evidence", call. = FALSE)
  }
  home_input <- data.frame(
    team_id = as.character(boundary_fixtures$home_team_id),
    baseline_mean = as.numeric(base_means$mu_home),
    structural_prior = as.numeric(base_means$mu_home) * as.numeric(home_signal$structural_prior),
    effective_match_count = as.numeric(home_counts$effective_match_count),
    stringsAsFactors = FALSE
  )
  away_input <- data.frame(
    team_id = as.character(boundary_fixtures$away_team_id),
    baseline_mean = as.numeric(base_means$mu_away),
    structural_prior = as.numeric(base_means$mu_away) * as.numeric(away_signal$structural_prior),
    effective_match_count = as.numeric(away_counts$effective_match_count),
    stringsAsFactors = FALSE
  )
  home_shrink <- apply_structural_sparse_shrinkage(
    home_input,
    prior_strength = settings$prior_strength,
    evidence_half_life_days = settings$evidence_half_life_days,
    registered_vintage_id = settings$structural_snapshot_vintage_id,
    bounds = settings$prior_bounds
  )
  away_shrink <- apply_structural_sparse_shrinkage(
    away_input,
    prior_strength = settings$prior_strength,
    evidence_half_life_days = settings$evidence_half_life_days,
    registered_vintage_id = settings$structural_snapshot_vintage_id,
    bounds = settings$prior_bounds
  )
  means <- base_means
  means$home_pre_shrinkage_mean <- home_shrink$pre_shrinkage_mean
  means$away_pre_shrinkage_mean <- away_shrink$pre_shrinkage_mean
  means$home_structural_prior <- home_shrink$structural_prior
  means$away_structural_prior <- away_shrink$structural_prior
  means$home_structural_prior_multiplier <- as.numeric(home_signal$structural_prior)
  means$away_structural_prior_multiplier <- as.numeric(away_signal$structural_prior)
  means$home_structural_signal <- as.numeric(home_signal$structural_signal)
  means$away_structural_signal <- as.numeric(away_signal$structural_signal)
  means$home_effective_match_count <- home_shrink$effective_match_count
  means$away_effective_match_count <- away_shrink$effective_match_count
  means$home_prior_weight <- home_shrink$prior_weight
  means$away_prior_weight <- away_shrink$prior_weight
  means$mu_home <- home_shrink$post_shrinkage_mean
  means$mu_away <- away_shrink$post_shrinkage_mean
  means$structural_prior_manifest_sha256 <- settings$structural_prior_manifest_sha256
  means$structural_snapshot_vintage_id <- settings$structural_snapshot_vintage_id
  means$mean_prediction_hash <- vapply(seq_len(nrow(means)), function(index) {
    digest::digest(
      paste(
        as.character(means$fixture_id[index]),
        format(as.numeric(means$mu_home[index]), digits = 17),
        format(as.numeric(means$mu_away[index]), digits = 17),
        sep = "|"
      ),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  list(
    means = means,
    diagnostics = paste(
      "prior_strength", settings$prior_strength,
      "half_life_days", settings$evidence_half_life_days,
      "vintage", settings$structural_snapshot_vintage_id,
      "source_rows_sha256", attr(snapshots, "structural_rows_sha256"),
      sep = "="
    )
  )
}

#' Run one registered Phase 11 RF candidate through fit, prediction, evidence,
#' and common-contract validation.
#' @export
run_registered_hybrid_adapter <- function(
    candidate_id, history, fixtures, seed_registry = NULL, support_max = 40L,
    run_id = "benchmark_run", protocol = NULL, settings = list()
) {
  .hybrid_adapter_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("load_and_validate_hybrid_protocol", "hybrid_registration")
  )
  .hybrid_adapter_source_if_missing(
    "R/forecast/hybrid_rf.R",
    c("hybrid_rf_registered_settings", "fit_hybrid_two_goal_rf", "predict_hybrid_rf_means", "hybrid_rf_nb_score_distributions")
  )
  .hybrid_adapter_source_if_missing(
    "R/benchmark/contracts.R",
    c(
      "benchmark_contract_require_columns", "validate_benchmark_predictions",
      "validate_model_manifests", "build_registered_feature_coverage",
      "validate_benchmark_feature_evidence", "benchmark_feature_coverage_id"
    )
  )
  if (is.null(protocol)) protocol <- load_and_validate_hybrid_protocol()
  registration <- .hybrid_adapter_registration(protocol, candidate_id)
  fixtures <- hybrid_normalize_fixtures(fixtures)
  if (!is.data.frame(history) || !nrow(history)) stop("Hybrid adapter history must contain rows", call. = FALSE)
  seed_registry <- .hybrid_adapter_seed_registry(fixtures, seed_registry)
  structural_manifest <- NULL
  structural_snapshots <- NULL
  if (.hybrid_adapter_is_xg(registration)) {
    gate <- .hybrid_adapter_xg_gate(protocol, registration)
    settings <- .hybrid_xg_registered_settings(settings, registration)
    if (!.phase11_bool(gate$active[[1L]], "xG gate active")) {
      return(.hybrid_xg_inactive_result(registration, fixtures, seed_registry, run_id, protocol, settings, gate))
    }
  } else if (.hybrid_adapter_is_structural(registration)) {
    structural_info <- tryCatch(
      .hybrid_adapter_structural_manifest(protocol, registration),
      error = function(error) error
    )
    if (inherits(structural_info, "error")) {
      inactive_settings <- .hybrid_structural_fallback_settings(settings, registration)
      return(.hybrid_structural_inactive_result(
        registration, fixtures, seed_registry, run_id, protocol, inactive_settings,
        conditionMessage(structural_info)
      ))
    }
    structural_manifest <- structural_info$manifest
    structural_snapshots <- structural_info$snapshots
    settings <- .hybrid_structural_registered_settings(settings, registration, structural_manifest)
  }
  settings <- if (.hybrid_adapter_is_xg(registration)) {
    .hybrid_xg_registered_settings(settings, registration)
  } else if (.hybrid_adapter_is_structural(registration)) {
    settings
  } else if (.hybrid_adapter_is_context(registration)) {
    .hybrid_context_registered_settings(settings, registration)
  } else {
    hybrid_rf_registered_settings(settings, registration)
  }
  if (.hybrid_adapter_is_context(registration)) {
    settings$distribution_id_prefix <- as.character(registration$candidate_id[[1L]])
    settings$context_parent_hashes <- as.character(registration$context_parent_hashes[[1L]])
  }
  if (as.integer(support_max) != settings$support_max) stop("Hybrid adapter support differs from registered G=40", call. = FALSE)

  boundary_groups <- split(seq_len(nrow(fixtures)), as.character(fixtures$boundary_id))
  pieces <- lapply(boundary_groups, function(index) {
    boundary_fixtures <- fixtures[index, , drop = FALSE]
    cutoffs <- unique(as.Date(boundary_fixtures$evidence_cutoff_exclusive))
    if (length(cutoffs) != 1L || is.na(cutoffs[[1L]])) stop("Hybrid boundary requires one exclusive evidence cutoff", call. = FALSE)
    if (.hybrid_adapter_is_context(registration)) {
      prepared <- .hybrid_context_prepare_boundary(history, boundary_fixtures)
      fit <- .hybrid_context_fit(prepared$history_context, cutoffs[[1L]], settings, registration)
      means <- .hybrid_context_predict_means(fit, prepared$fixture_context, settings)
      distributions <- .hybrid_context_nb_score_distributions(means, settings$support_max, settings)
      piece_history <- prepared$history
      context_parent_hashes <- prepared$parent_hashes
    } else if (.hybrid_adapter_is_structural(registration)) {
      structural_team_check <- tryCatch({
        compute_structural_prior_signal(
          snapshots = structural_snapshots,
          team_ids = unique(c(
            as.character(boundary_fixtures$home_team_id),
            as.character(boundary_fixtures$away_team_id)
          )),
          evidence_cutoff_exclusive = cutoffs[[1L]],
          registered_vintage_id = settings$structural_snapshot_vintage_id,
          prior_scale = settings$prior_scale,
          prior_bounds = settings$prior_bounds
        )
        TRUE
      }, error = function(error) error)
      if (inherits(structural_team_check, "error")) {
        return(.hybrid_structural_inactive_result(
          registration, fixtures, seed_registry, run_id, protocol, settings,
          conditionMessage(structural_team_check), structural_manifest
        ))
      }
      fit <- fit_hybrid_two_goal_rf(
        history, cutoffs[[1L]], settings, hybrid_registration(protocol, "phase11_rf_dynamic_elo_open")
      )
      means <- predict_hybrid_rf_means(
        fit, boundary_fixtures, settings
      )
      structural_result <- tryCatch(
        .hybrid_structural_apply_boundary(
          base_means = means,
          boundary_fixtures = boundary_fixtures,
          history = history,
          cutoff = cutoffs[[1L]],
          snapshots = structural_snapshots,
          settings = settings
        ),
        error = function(error) error
      )
      if (inherits(structural_result, "error")) {
        return(.hybrid_structural_inactive_result(
          registration, fixtures, seed_registry, run_id, protocol, settings,
          conditionMessage(structural_result), structural_manifest
        ))
      }
      means <- structural_result$means
      means$model_id <- as.character(registration$mean_model_id[[1L]])
      means$candidate_id <- as.character(registration$candidate_id[[1L]])
      means$panel_id <- as.character(registration$panel_id[[1L]])
      means$settings_sha256 <- settings$settings_sha256
      means$registration_sha256 <- settings$registration_sha256
      means$ranger_package <- settings$ranger_package
      means$ranger_version <- settings$ranger_version
      means$ranger_provenance_id <- settings$ranger_provenance_id
      distributions <- hybrid_rf_nb_score_distributions(means, settings$support_max, settings)
      fit$candidate_id <- as.character(registration$candidate_id[[1L]])
      fit$model_id <- as.character(registration$mean_model_id[[1L]])
      fit$model_family <- as.character(registration$model_family[[1L]])
      fit$panel_id <- as.character(registration$panel_id[[1L]])
      fit$registration <- registration
      fit$runtime_settings <- settings
      fit$registration_sha256 <- settings$registration_sha256
      fit$settings_sha256 <- settings$settings_sha256
      fit$structural_prior_manifest_sha256 <- settings$structural_prior_manifest_sha256
      fit$structural_snapshot_vintage_id <- settings$structural_snapshot_vintage_id
      fit$structural_diagnostics <- structural_result$diagnostics
      piece_history <- history
      context_parent_hashes <- NULL
    } else {
      fit <- fit_hybrid_two_goal_rf(history, cutoffs[[1L]], settings, registration)
      means <- predict_hybrid_rf_means(fit, boundary_fixtures, settings)
      distributions <- hybrid_rf_nb_score_distributions(means, settings$support_max, settings)
      piece_history <- history
      context_parent_hashes <- NULL
    }
    markets <- .hybrid_adapter_markets(distributions, as.character(boundary_fixtures$fixture_id))
    list(
      fit = fit, fixtures = boundary_fixtures, means = means, distributions = distributions,
      markets = markets, history = piece_history, context_parent_hashes = context_parent_hashes
    )
  })
  inactive_pieces <- pieces[vapply(pieces, function(piece) isTRUE(piece$inactive), logical(1))]
  if (length(inactive_pieces)) return(inactive_pieces[[1L]])
  distributions <- do.call(rbind, lapply(pieces, `[[`, "distributions"))
  means <- do.call(rbind, lapply(pieces, `[[`, "means"))
  markets <- do.call(rbind, lapply(pieces, `[[`, "markets"))
  manifests <- do.call(rbind, lapply(pieces, function(piece) {
    manifest <- .hybrid_manifest_rows(
      piece$fit, registration, piece$fixtures, piece$history, run_id, piece$means
    )
    if (!is.null(piece$context_parent_hashes) && "context_parent_hashes" %in% names(manifest)) {
      manifest$context_parent_hashes <- piece$context_parent_hashes
    }
    manifest
  }))
  manifests <- manifests[!duplicated(manifests$model_manifest_id), , drop = FALSE]
  fixture_index <- match(as.character(fixtures$fixture_id), as.character(markets$fixture_id))
  market <- markets[fixture_index, , drop = FALSE]
  seeds <- seed_registry[match(fixtures$fixture_id, seed_registry$fixture_id), , drop = FALSE]
  model_manifest_ids <- paste(run_id, registration$candidate_id, fixtures$boundary_id, sep = "__")
  predictions <- data.frame(
    schema_version = "1.0",
    run_id = run_id,
    model_id = registration$candidate_id,
    panel_id = registration$panel_id,
    edition_id = fixtures$edition_id,
    track_id = fixtures$track_id,
    fixture_id = fixtures$fixture_id,
    boundary_id = fixtures$boundary_id,
    forecast_sequence = fixtures$forecast_sequence,
    home_team_id = fixtures$home_team_id,
    away_team_id = fixtures$away_team_id,
    venue_role = fixtures$venue_role,
    evidence_cutoff_exclusive = fixtures$evidence_cutoff_exclusive,
    result_cutoff_exclusive = fixtures$result_cutoff_exclusive,
    model_manifest_id = model_manifest_ids,
    feature_coverage_id = vapply(seq_len(nrow(fixtures)), function(index) {
      benchmark_feature_coverage_id(
        run_id, registration$candidate_id, fixtures$track_id[index], fixtures$boundary_id[index], fixtures$fixture_id[index]
      )
    }, character(1)),
    seed_id = seeds$seed_id,
    score_distribution_id = market$score_distribution_id,
    p_home = market$p_home,
    p_draw = market$p_draw,
    p_away = market$p_away,
    expected_home_goals = market$expected_home_goals,
    expected_away_goals = market$expected_away_goals,
    p_over_2_5 = market$p_over_2_5,
    p_under_2_5 = market$p_under_2_5,
    p_btts = market$p_btts,
    modal_home_goals = market$modal_home_goals,
    modal_away_goals = market$modal_away_goals,
    modal_score_probability = market$modal_score_probability,
    prediction_status = "ok",
    failure_reason = "",
    mean_prediction_hash = means$mean_prediction_hash[match(fixtures$fixture_id, means$fixture_id)],
    registration_sha256 = settings$registration_sha256,
    settings_sha256 = settings$settings_sha256,
    ranger_package = settings$ranger_package,
    ranger_version = settings$ranger_version,
    ranger_provenance_id = settings$ranger_provenance_id,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_model_manifests(manifests)
  validate_benchmark_predictions(predictions, fixtures, distributions, seed_registry, settings$support_max)
  feature_contract <- protocol$feature_contract
  if ("feature_set_id" %in% names(feature_contract) && "feature_set_id" %in% names(registration)) {
    feature_sets <- as.character(registration$feature_set_id[[1L]])
    if (.hybrid_adapter_is_context(registration)) {
      feature_sets <- c("phase11_rf_dynamic_elo_open", feature_sets)
    }
    feature_contract <- feature_contract[as.character(feature_contract$feature_set_id) %in% feature_sets, , drop = FALSE]
  }
  if (!nrow(feature_contract)) stop("Registered hybrid candidate has no feature-contract rows", call. = FALSE)
  feature_coverage <- build_registered_feature_coverage(
    registration, predictions, fixtures, feature_contract, manifests
  )
  model_registry <- data.frame(
    model_id = registration$candidate_id,
    panel_id = registration$panel_id,
    stringsAsFactors = FALSE
  )
  validate_benchmark_feature_evidence(predictions, feature_coverage, model_registry, feature_contract)
  list(
    candidate_id = candidate_id,
    registration = registration,
    settings = settings,
    protocol = protocol,
    predictions = predictions,
    distributions = distributions,
    means = means,
    manifests = manifests,
    feature_coverage = feature_coverage,
    seed_registry = seed_registry,
    environment = pieces[[1L]]$fit$environment,
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}
