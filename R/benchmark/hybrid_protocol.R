#' Phase 11 hybrid challenger protocol and registry contracts

.phase11_protocol_root <- function(path = ".") {
  if (exists("benchmark_find_project_root", mode = "function")) {
    return(benchmark_find_project_root(path))
  }
  candidate <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Could not locate the xGelo project root", call. = FALSE)
    candidate <- parent
  }
}

.phase11_protocol_path <- function(...) {
  file.path(.phase11_protocol_root("."), ...)
}

.phase11_sha256 <- function(value = NULL, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 11 protocol validation", call. = FALSE)
  }
  if (isTRUE(file)) return(digest::digest(value, algo = "sha256", file = TRUE))
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.phase11_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value[value == "TRUE"] <- "true"
  value[value == "FALSE"] <- "false"
  value
}

.phase11_row_sha256 <- function(data, hash_col) {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    .phase11_sha256(paste(
      vapply(data[index, fields, drop = FALSE], .phase11_scalar, character(1)),
      collapse = "|"
    ))
  }, character(1))
}

.phase11_subset_sha256 <- function(data, fields) {
  vapply(seq_len(nrow(data)), function(index) {
    .phase11_sha256(paste(
      vapply(data[index, fields, drop = FALSE], .phase11_scalar, character(1)),
      collapse = "|"
    ))
  }, character(1))
}

.phase11_read_csv <- function(path) {
  if (!file.exists(path)) stop("Phase 11 protocol file is missing: ", basename(path), call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
}

.phase11_require_contracts <- function() {
  if (!exists("benchmark_contract_require_columns", mode = "function")) {
    contracts_path <- .phase11_protocol_path("R", "benchmark", "contracts.R")
    if (!file.exists(contracts_path)) stop("Benchmark contracts are missing: ", contracts_path, call. = FALSE)
    source(contracts_path, local = .GlobalEnv)
  }
  invisible(TRUE)
}

.phase11_file_sha256 <- function(relative_path) {
  path <- if (grepl("^(/|[A-Za-z]:[/\\\\])", as.character(relative_path))) {
    normalizePath(relative_path, mustWork = FALSE)
  } else {
    .phase11_protocol_path(relative_path)
  }
  if (!file.exists(path)) stop("Phase 11 protocol parent artifact is missing: ", relative_path, call. = FALSE)
  .phase11_sha256(path, file = TRUE)
}

.phase11_assert_hash <- function(data, hash_col, label) {
  if (!hash_col %in% names(data)) stop(label, " is missing ", hash_col, call. = FALSE)
  actual <- tolower(.phase11_scalar(data[[hash_col]]))
  if (any(!grepl("^[0-9a-f]{64}$", actual))) {
    stop(label, " contains noncanonical SHA-256 values", call. = FALSE)
  }
  expected <- if (hash_col == "settings_sha256") {
    .phase11_model_settings_sha256(data)
  } else {
    .phase11_row_sha256(data, hash_col)
  }
  if (any(actual != expected)) stop(label, " hash mismatch", call. = FALSE)
  invisible(TRUE)
}

.phase11_model_settings_fields <- function() {
  c(
    "candidate_id", "adapter_id", "adapter_version", "mean_model_id", "dependence_id",
    "tuning_protocol_id", "tuning_grid_id", "feature_set_id", "rf_feature_set_id", "score_support_max",
    "settings", "num.trees", "mtry", "min.node.size", "seed_policy", "seed_id",
    "home_away_tuning_relationship", "nb_dispersion_source", "home_theta", "away_theta",
    "ranger_package", "ranger_version", "ranger_provenance_id"
  )
}

.phase11_rf_tuning_grid_fields <- function() {
  c(
    "candidate_id", "num.trees", "mtry", "min.node.size", "seed_policy",
    "feature_set_id", "home_away_tuning_relationship", "nb_dispersion_source",
    "home_theta", "away_theta", "ranger_package", "ranger_version",
    "ranger_provenance_id"
  )
}

.phase11_rf_tuning_grid_sha256 <- function(data) {
  fields <- .phase11_rf_tuning_grid_fields()
  missing <- setdiff(fields, names(data))
  if (length(missing)) stop("Phase 11 RF tuning grid is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  .phase11_sha256(paste(
    vapply(data[1L, fields, drop = FALSE], .phase11_scalar, character(1)),
    collapse = "|"
  ))
}

.phase11_model_settings_sha256 <- function(data) {
  fields <- .phase11_model_settings_fields()
  missing <- setdiff(fields, names(data))
  if (length(missing)) stop("Phase 11 RF settings are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  .phase11_subset_sha256(data, fields)
}

.phase11_bool <- function(value, label) {
  value <- tolower(as.character(value))
  if (length(value) != 1L || is.na(value) || !value %in% c("true", "false")) {
    stop(label, " must be true or false", call. = FALSE)
  }
  identical(value, "true")
}

.phase11_bool_vector <- function(value, label, n = length(value)) {
  if (length(value) != n) stop(label, " has the wrong row count", call. = FALSE)
  if (is.logical(value)) result <- value else {
    normalized <- tolower(trimws(as.character(value)))
    result <- ifelse(normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA))
  }
  if (anyNA(result)) stop(label, " must contain only true/false values", call. = FALSE)
  result
}

.phase11_input_sha256 <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 11 input hashes", call. = FALSE)
  }
  if (is.character(value) && length(value) == 1L && file.exists(value)) {
    return(.phase11_sha256(value, file = TRUE))
  }
  if (is.null(value)) return(.phase11_sha256("", file = FALSE))
  digest::digest(value, algo = "sha256", serialize = TRUE)
}

.phase11_xg_gate_threshold_defaults <- function() {
  list(
    minimum_source_coverage = 0.80,
    minimum_nonzero_variance = 1e-8,
    require_complete_provenance = TRUE,
    require_active_model = TRUE,
    minimum_forecast_coverage = 0.80
  )
}

.phase11_xg_gate_companion_suffixes <- function() {
  c("__source_date", "__source_present", "__value_present", "__imputed", "__imputation_reason")
}

.phase11_xg_table_coverage <- function(data, predictors, cutoff) {
  if (!is.data.frame(data) || !nrow(data)) {
    return(list(
      coverage = 0,
      by_predictor = stats::setNames(rep(0, length(predictors)), predictors),
      provenance_complete = FALSE,
      invalid_rows = 0L
    ))
  }
  cutoff <- as.Date(cutoff)
  by_predictor <- stats::setNames(rep(0, length(predictors)), predictors)
  valid_rows <- vector("list", length(predictors))
  invalid_rows <- 0L
  for (index in seq_along(predictors)) {
    predictor <- predictors[[index]]
    companions <- paste0(predictor, .phase11_xg_gate_companion_suffixes())
    complete_columns <- all(c(predictor, companions) %in% names(data))
    if (!complete_columns) {
      valid_rows[[index]] <- rep(FALSE, nrow(data))
      next
    }
    values <- suppressWarnings(as.numeric(data[[predictor]]))
    source_date <- as.Date(data[[paste0(predictor, "__source_date")]])
    source_present <- .phase11_bool_vector(
      data[[paste0(predictor, "__source_present")]],
      paste0(predictor, " source presence"), nrow(data)
    )
    value_present <- .phase11_bool_vector(
      data[[paste0(predictor, "__value_present")]],
      paste0(predictor, " value presence"), nrow(data)
    )
    imputed <- .phase11_bool_vector(
      data[[paste0(predictor, "__imputed")]],
      paste0(predictor, " imputation"), nrow(data)
    )
    valid <- source_present & value_present & !imputed & is.finite(values) &
      !is.na(source_date) & source_date < cutoff
    by_predictor[[predictor]] <- mean(valid)
    valid_rows[[index]] <- valid
    invalid_rows <- invalid_rows + sum(source_present & (is.na(source_date) | source_date >= cutoff))
  }
  row_coverage <- if (length(valid_rows)) {
    Reduce(`&`, valid_rows)
  } else {
    rep(FALSE, nrow(data))
  }
  provenance_complete <- all(vapply(valid_rows, length, integer(1)) == nrow(data)) &&
    invalid_rows == 0L && any(row_coverage)
  list(
    coverage = if (length(by_predictor)) min(by_predictor) else 0,
    by_predictor = by_predictor,
    provenance_complete = provenance_complete,
    invalid_rows = as.integer(invalid_rows)
  )
}

#' Evaluate the registered point-in-time xG activation gate.
#'
#' D-12 deliberately treats source presence, value presence, imputation, and
#' variance as separate facts.  A feature table containing zero placeholders
#' therefore cannot activate xG unless its evidence companions also qualify.
#' @export
evaluate_hybrid_xg_gate <- function(
    feature_table = "data/processed/goal_training_features_hybrid.csv",
    home_model = "models/home_goal_model_hybrid.rds",
    away_model = "models/away_goal_model_hybrid.rds",
    rolling_form = "data/processed/rolling_form.csv",
    forecast_features = "data/processed/worldcup_2026_forecast_features_hybrid.csv",
    predictors = NULL,
    thresholds = NULL,
    evidence_cutoff_exclusive = as.Date("2026-06-05"),
    gate_id = "phase11_xg_gate_d12_v1",
    candidate_id = "phase11_rf_dynamic_elo_context_xg_gated_open"
) {
  .phase11_protocol_source_if_missing <- function(relative_path, symbols) {
    missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
    if (!length(missing)) return(invisible(TRUE))
    path <- .phase11_protocol_path(relative_path)
    if (!file.exists(path)) stop("Phase 11 xG gate dependency is missing: ", relative_path, call. = FALSE)
    source(path, local = .GlobalEnv)
    invisible(TRUE)
  }
  .phase11_protocol_source_if_missing("R/forecast/xg_usage_audit.R", c("audit_xg_feature_usage", "xg_form_predictors"))
  predictors <- if (is.null(predictors)) xg_form_predictors() else as.character(predictors)
  if (!length(predictors) || anyNA(predictors) || any(!nzchar(predictors)) || anyDuplicated(predictors)) {
    stop("xG gate predictors must be a non-empty unique character vector", call. = FALSE)
  }
  defaults <- .phase11_xg_gate_threshold_defaults()
  thresholds <- modifyList(defaults, if (is.null(thresholds)) list() else thresholds)
  required_thresholds <- names(defaults)
  missing_thresholds <- setdiff(required_thresholds, names(thresholds))
  if (length(missing_thresholds)) stop("xG gate thresholds are missing: ", paste(missing_thresholds, collapse = ", "), call. = FALSE)
  numeric_thresholds <- c("minimum_source_coverage", "minimum_nonzero_variance", "minimum_forecast_coverage")
  for (name in numeric_thresholds) {
    value <- suppressWarnings(as.numeric(thresholds[[name]]))
    if (length(value) != 1L || is.na(value) || !is.finite(value) || value < 0) {
      stop("xG gate threshold is invalid: ", name, call. = FALSE)
    }
    thresholds[[name]] <- value
  }
  thresholds$require_complete_provenance <- .phase11_bool(thresholds$require_complete_provenance, "require_complete_provenance")
  thresholds$require_active_model <- .phase11_bool(thresholds$require_active_model, "require_active_model")

  cutoff <- as.Date(evidence_cutoff_exclusive)
  if (length(cutoff) != 1L || is.na(cutoff)) stop("xG gate evidence cutoff must be one valid date", call. = FALSE)
  audit <- audit_xg_feature_usage(
    feature_table = feature_table,
    home_model = home_model,
    away_model = away_model,
    rolling_form = rolling_form,
    forecast_features = forecast_features,
    predictors = predictors
  )
  feature_data <- read_audit_table(feature_table, "feature_table")
  forecast_data <- read_audit_table(forecast_features, "forecast_features", required = FALSE)
  training <- .phase11_xg_table_coverage(feature_data, predictors, cutoff)
  forecast <- .phase11_xg_table_coverage(forecast_data, predictors, cutoff)
  forecast_coverage <- if (is.data.frame(forecast_data) && nrow(forecast_data)) forecast$coverage else 0

  variance_by_predictor <- stats::setNames(rep(0, length(predictors)), predictors)
  if (nrow(audit)) {
    for (predictor in predictors) {
      row <- audit[as.character(audit$predictor) == predictor, , drop = FALSE]
      if (nrow(row) == 1L) {
        value <- suppressWarnings(as.numeric(row$sd[[1L]]))
        variance_by_predictor[[predictor]] <- if (is.finite(value)) value^2 else 0
      }
    }
  }
  variance <- if (length(variance_by_predictor)) min(variance_by_predictor) else 0
  model_labels <- if (nrow(audit)) as.logical(audit$active_in_model) else logical()
  model_labelled <- length(model_labels) == length(predictors) && all(model_labels)
  provenance <- isTRUE(training$provenance_complete) &&
    isTRUE(forecast$provenance_complete) &&
    all(is.finite(unlist(variance_by_predictor))) &&
    nrow(audit) == length(predictors)

  source_hashes <- c(
    feature_table = .phase11_input_sha256(feature_table),
    home_model = .phase11_input_sha256(home_model),
    away_model = .phase11_input_sha256(away_model),
    rolling_form = .phase11_input_sha256(rolling_form),
    forecast_features = .phase11_input_sha256(forecast_features),
    audit = .phase11_input_sha256(audit)
  )
  gate_parent_sha256 <- .phase11_sha256(paste(unname(source_hashes), collapse = "|"))
  reasons <- character()
  if (training$coverage < thresholds$minimum_source_coverage) {
    reasons <- c(reasons, sprintf("coverage %.6f < %.6f", training$coverage, thresholds$minimum_source_coverage))
  }
  if (forecast_coverage < thresholds$minimum_forecast_coverage) {
    reasons <- c(reasons, sprintf("forecast coverage %.6f < %.6f", forecast_coverage, thresholds$minimum_forecast_coverage))
  }
  if (variance < thresholds$minimum_nonzero_variance) {
    reasons <- c(reasons, sprintf("variance %.12g < %.12g", variance, thresholds$minimum_nonzero_variance))
  }
  if (thresholds$require_complete_provenance && !provenance) reasons <- c(reasons, "provenance incomplete")
  if (thresholds$require_active_model && !model_labelled) reasons <- c(reasons, "xG predictors are not actively retained by both labelled models")
  active <- training$coverage >= thresholds$minimum_source_coverage &&
    forecast_coverage >= thresholds$minimum_forecast_coverage &&
    variance >= thresholds$minimum_nonzero_variance &&
    (!thresholds$require_complete_provenance || provenance) &&
    (!thresholds$require_active_model || model_labelled)
  inactive_reason <- if (active) "" else paste(c("D-12 xG gate failed:", reasons), collapse = "; ")
  list(
    schema_version = "phase11-xg-gate-v1",
    gate_id = as.character(gate_id),
    candidate_id = as.character(candidate_id),
    evidence_cutoff_exclusive = cutoff,
    predictors = predictors,
    audit = audit,
    coverage_by_predictor = training$by_predictor,
    forecast_coverage_by_predictor = forecast$by_predictor,
    variance_by_predictor = variance_by_predictor,
    coverage = as.numeric(training$coverage),
    forecast_coverage = as.numeric(forecast_coverage),
    variance = as.numeric(variance),
    provenance = isTRUE(provenance),
    model_labelled = isTRUE(model_labelled),
    thresholds = thresholds,
    active = isTRUE(active),
    active_status = if (active) "active" else "inactive",
    score_status = if (active) "score_eligible" else "no_score_gate_failed",
    inactive_reason = inactive_reason,
    source_hashes = source_hashes,
    gate_parent_sha256 = gate_parent_sha256,
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}

.phase11_xg_gate_manifest_row <- function(gate) {
  thresholds <- gate$thresholds
  hashes <- gate$source_hashes
  row <- data.frame(
    schema_version = "1.0",
    gate_id = as.character(gate$gate_id),
    candidate_id = as.character(gate$candidate_id),
    decision_rule = "D-12: activate only when point-in-time coverage, variance, provenance, and model labelling thresholds pass",
    predictors = paste(as.character(gate$predictors), collapse = "|"),
    evidence_cutoff_exclusive = as.Date(gate$evidence_cutoff_exclusive),
    minimum_source_coverage = as.numeric(thresholds$minimum_source_coverage),
    minimum_forecast_coverage = as.numeric(thresholds$minimum_forecast_coverage),
    minimum_nonzero_variance = as.numeric(thresholds$minimum_nonzero_variance),
    require_complete_provenance = isTRUE(thresholds$require_complete_provenance),
    require_active_model = isTRUE(thresholds$require_active_model),
    coverage = as.numeric(gate$coverage),
    forecast_coverage = as.numeric(gate$forecast_coverage),
    variance = as.numeric(gate$variance),
    provenance = isTRUE(gate$provenance),
    model_labelled = isTRUE(gate$model_labelled),
    active = isTRUE(gate$active),
    active_status = as.character(gate$active_status),
    score_status = as.character(gate$score_status),
    inactive_reason = as.character(gate$inactive_reason),
    source_hash_feature_table = unname(hashes[["feature_table"]]),
    source_hash_home_model = unname(hashes[["home_model"]]),
    source_hash_away_model = unname(hashes[["away_model"]]),
    source_hash_rolling_form = unname(hashes[["rolling_form"]]),
    source_hash_forecast_features = unname(hashes[["forecast_features"]]),
    source_hash_audit = unname(hashes[["audit"]]),
    gate_parent_sha256 = as.character(gate$gate_parent_sha256),
    source_hashes = paste(paste(names(hashes), unname(hashes), sep = "="), collapse = "|"),
    active_candidate_rule = "xG-informed candidates are rejected unless active_status=active",
    research_only = TRUE,
    wc2026_sealed = TRUE,
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- .phase11_row_sha256(row, "row_sha256")
  row
}

#' Validate the durable xG gate manifest.
#' @export
validate_phase11_xg_gate_manifest <- function(data) {
  required <- c(
    "schema_version", "gate_id", "candidate_id", "decision_rule", "predictors",
    "evidence_cutoff_exclusive", "minimum_source_coverage", "minimum_forecast_coverage",
    "minimum_nonzero_variance", "require_complete_provenance", "require_active_model",
    "coverage", "forecast_coverage", "variance", "provenance", "model_labelled", "active",
    "active_status", "score_status", "inactive_reason", "source_hash_feature_table",
    "source_hash_home_model", "source_hash_away_model", "source_hash_rolling_form",
    "source_hash_forecast_features", "source_hash_audit", "gate_parent_sha256",
    "source_hashes", "active_candidate_rule", "research_only", "wc2026_sealed", "row_sha256"
  )
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Phase 11 xG gate manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!is.data.frame(data) || nrow(data) != 1L) stop("Phase 11 xG gate manifest must contain exactly one row", call. = FALSE)
  if (as.character(data$gate_id) != "phase11_xg_gate_d12_v1") stop("Phase 11 xG gate must cite the registered D-12 gate", call. = FALSE)
  if (as.character(data$candidate_id) != "phase11_rf_dynamic_elo_context_xg_gated_open") stop("Phase 11 xG gate candidate identity is not registered", call. = FALSE)
  if (length(strsplit(as.character(data$predictors), "|", fixed = TRUE)[[1L]]) < 1L) stop("Phase 11 xG gate predictors are empty", call. = FALSE)
  cutoff <- as.Date(data$evidence_cutoff_exclusive)
  if (is.na(cutoff)) stop("Phase 11 xG gate evidence cutoff is invalid", call. = FALSE)
  threshold_names <- c("minimum_source_coverage", "minimum_forecast_coverage", "minimum_nonzero_variance")
  if (any(!vapply(data[threshold_names], function(x) is.finite(as.numeric(x[[1L]])) && as.numeric(x[[1L]]) >= 0, logical(1)))) {
    stop("Phase 11 xG gate thresholds are invalid", call. = FALSE)
  }
  bool_names <- c("require_complete_provenance", "require_active_model", "provenance", "model_labelled", "active", "research_only", "wc2026_sealed")
  for (name in bool_names) .phase11_bool(data[[name]][[1L]], paste0("xG gate ", name))
  hash_names <- c(
    "source_hash_feature_table", "source_hash_home_model", "source_hash_away_model",
    "source_hash_rolling_form", "source_hash_forecast_features", "source_hash_audit",
    "gate_parent_sha256"
  )
  if (any(!vapply(data[hash_names], function(x) grepl("^[0-9a-f]{64}$", tolower(as.character(x[[1L]]))), logical(1)))) {
    stop("Phase 11 xG gate source hashes must be canonical SHA-256 values", call. = FALSE)
  }
  expected_parent <- .phase11_sha256(paste(
    as.character(data$source_hash_feature_table), as.character(data$source_hash_home_model),
    as.character(data$source_hash_away_model), as.character(data$source_hash_rolling_form),
    as.character(data$source_hash_forecast_features), as.character(data$source_hash_audit),
    sep = "|"
  ))
  if (!identical(tolower(as.character(data$gate_parent_sha256)), expected_parent)) stop("Phase 11 xG gate parent hash mismatch", call. = FALSE)
  .phase11_assert_hash(data, "row_sha256", "Phase 11 xG gate manifest")
  active <- .phase11_bool(data$active[[1L]], "xG gate active")
  provenance_requirement_failed <- .phase11_bool(data$require_complete_provenance[[1L]], "xG gate require_complete_provenance") &&
    !.phase11_bool(data$provenance[[1L]], "xG gate provenance")
  model_requirement_failed <- .phase11_bool(data$require_active_model[[1L]], "xG gate require_active_model") &&
    !.phase11_bool(data$model_labelled[[1L]], "xG gate model_labelled")
  if (active && (
    as.numeric(data$coverage) < as.numeric(data$minimum_source_coverage) ||
      as.numeric(data$forecast_coverage) < as.numeric(data$minimum_forecast_coverage) ||
      as.numeric(data$variance) < as.numeric(data$minimum_nonzero_variance) ||
      provenance_requirement_failed || model_requirement_failed
  )) {
    stop("D-12 xG gate cannot be active below a declared threshold", call. = FALSE)
  }
  if (active && as.character(data$active_status) != "active") stop("Active xG gate must be labelled active", call. = FALSE)
  if (!active && (as.character(data$active_status) != "inactive" || as.character(data$score_status) != "no_score_gate_failed" || !nzchar(as.character(data$inactive_reason)))) {
    stop("Inactive xG gate must publish explicit inactive/no-score evidence", call. = FALSE)
  }
  invisible(data)
}

#' Build and write the canonical current xG gate manifest.
#' @export
write_phase11_xg_gate_manifest <- function(
    manifest_path = "data/benchmark/phase11/xg_gate_manifest.csv",
    gate = NULL
) {
  root <- .phase11_protocol_root(".")
  path <- if (grepl("^(/|[A-Za-z]:[/\\\\])", manifest_path)) manifest_path else file.path(root, manifest_path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (is.null(gate)) gate <- evaluate_hybrid_xg_gate()
  row <- .phase11_xg_gate_manifest_row(gate)
  utils::write.csv(row, path, row.names = FALSE, na = "", quote = TRUE)
  validate_phase11_xg_gate_manifest(.phase11_read_csv(path))
  invisible(row)
}

#' Validate the committed, checksum-backed structural source snapshot.
#'
#' This protocol-level wrapper keeps structural input validation discoverable
#' from the same registry loader as the RF and xG gates.  The implementation
#' lives in `R/forecast/structural_prior.R` so it can also be used directly by
#' fold-local adapters.
#' @export
validate_phase11_structural_source_manifest <- function(
    snapshot_path = "data/benchmark/phase11/structural_sources.csv",
    metadata_path = "data/benchmark/phase11/structural_sources_metadata.csv",
    checksums_path = "data/benchmark/phase11/structural_sources_checksums.csv",
    evidence_cutoff_exclusive = as.Date("2026-06-05"),
    registered_vintage_id = NULL
) {
  if (!exists("load_structural_prior_snapshots", mode = "function")) {
    source(.phase11_protocol_path("R", "forecast", "structural_prior.R"), local = .GlobalEnv)
  }
  load_structural_prior_snapshots(
    snapshot_path = snapshot_path,
    metadata_path = metadata_path,
    checksums_path = checksums_path,
    evidence_cutoff_exclusive = evidence_cutoff_exclusive,
    registered_vintage_id = registered_vintage_id
  )
}

.phase11_structural_manifest_paths <- function() {
  list(
    snapshot = "data/benchmark/phase11/structural_sources.csv",
    metadata = "data/benchmark/phase11/structural_sources_metadata.csv",
    checksums = "data/benchmark/phase11/structural_sources_checksums.csv"
  )
}

#' Build the canonical structural-prior manifest parent.
#' @export
canonical_phase11_structural_prior_manifest <- function(
    snapshot_path = "data/benchmark/phase11/structural_sources.csv",
    metadata_path = "data/benchmark/phase11/structural_sources_metadata.csv",
    checksums_path = "data/benchmark/phase11/structural_sources_checksums.csv",
    evidence_cutoff_exclusive = as.Date("2026-06-05"),
    candidate_id = "phase11_structural_sparse_prior_open",
    prior_strength = 4,
    evidence_half_life_days = 730,
    prior_scale = 0.15,
    prior_bounds = c(0.65, 1.55)
) {
  loaded <- validate_phase11_structural_source_manifest(
    snapshot_path, metadata_path, checksums_path, evidence_cutoff_exclusive
  )
  paths <- .phase11_structural_manifest_paths()
  metadata <- attr(loaded, "structural_metadata")
  vintage_id <- unique(as.character(loaded$vintage_id))
  indicator_ids <- unique(as.character(loaded$indicator_id))
  indicator_definitions <- unique(paste(as.character(loaded$indicator_id), as.character(loaded$indicator_definition), sep = "="))
  transformations <- unique(as.character(loaded$transformation))
  parent_hashes <- unique(as.character(loaded$parent_source_sha256))
  if (length(vintage_id) != 1L) stop("Structural prior manifest requires one frozen snapshot vintage", call. = FALSE)
  row <- data.frame(
    schema_version = "1.0",
    manifest_id = "phase11_structural_prior_manifest_d09_d11_v1",
    candidate_id = as.character(candidate_id),
    decision_rule = "D-09/D-10/D-11: structural values may affect sparse goal means only through continuous evidence-weighted prior shrinkage",
    snapshot_path = paths$snapshot,
    metadata_path = paths$metadata,
    checksums_path = paths$checksums,
    snapshot_vintage_id = vintage_id,
    source_year = as.integer(unique(loaded$source_year)[[1L]]),
    source_date = as.Date(unique(loaded$source_date)[[1L]]),
    indicator_ids = paste(indicator_ids, collapse = "|"),
    indicator_definitions = paste(indicator_definitions, collapse = "|"),
    transformations = paste(transformations, collapse = "|"),
    source_name = paste(unique(as.character(loaded$source_name)), collapse = "|"),
    license_class = paste(unique(as.character(loaded$license_class)), collapse = "|"),
    parent_source_sha256 = paste(parent_hashes, collapse = "|"),
    source_snapshot_sha256 = as.character(attr(loaded, "structural_snapshot_sha256")),
    source_metadata_sha256 = as.character(attr(loaded, "structural_metadata_sha256")),
    source_rows_sha256 = as.character(attr(loaded, "structural_rows_sha256")),
    checksum_registry_sha256 = .phase11_file_sha256(checksums_path),
    prior_strength = as.numeric(prior_strength),
    prior_scale = as.numeric(prior_scale),
    prior_lower_bound = as.numeric(prior_bounds[[1L]]),
    prior_upper_bound = as.numeric(prior_bounds[[2L]]),
    evidence_half_life_days = as.numeric(evidence_half_life_days),
    effective_count_formula = "effective_match_count=sum(exp(-log(2) * (evidence_cutoff_exclusive - match_date) / evidence_half_life_days))",
    prior_application_rule = "post=(1-prior_weight)*baseline_mean+prior_weight*structural_prior; prior_weight=prior_strength/(prior_strength+effective_match_count)",
    raw_structural_predictors_allowed = FALSE,
    acquisition_note = paste(unique(as.character(metadata$acquisition_note)), collapse = "|"),
    evidence_cutoff_exclusive = as.Date(evidence_cutoff_exclusive),
    research_only = TRUE,
    wc2026_sealed = TRUE,
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- .phase11_row_sha256(row, "row_sha256")
  row
}

#' Validate the durable structural-prior manifest.
#' @export
validate_phase11_structural_prior_manifest <- function(data) {
  required <- c(
    "schema_version", "manifest_id", "candidate_id", "decision_rule",
    "snapshot_path", "metadata_path", "checksums_path", "snapshot_vintage_id",
    "source_year", "source_date", "indicator_ids", "indicator_definitions",
    "transformations", "source_name", "license_class", "parent_source_sha256",
    "source_snapshot_sha256", "source_metadata_sha256", "source_rows_sha256",
    "checksum_registry_sha256", "prior_strength", "prior_scale", "prior_lower_bound",
    "prior_upper_bound", "evidence_half_life_days", "effective_count_formula",
    "prior_application_rule", "raw_structural_predictors_allowed", "acquisition_note",
    "evidence_cutoff_exclusive", "research_only", "wc2026_sealed", "row_sha256"
  )
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Phase 11 structural prior manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!is.data.frame(data) || nrow(data) != 1L) stop("Phase 11 structural prior manifest must contain exactly one row", call. = FALSE)
  if (as.character(data$candidate_id) != "phase11_structural_sparse_prior_open") stop("Structural prior manifest candidate identity is not registered", call. = FALSE)
  if (as.character(data$license_class) != "open-or-derived-open") stop("Structural prior manifest license is not open", call. = FALSE)
  if (.phase11_bool(data$raw_structural_predictors_allowed[[1L]], "structural prior raw_structural_predictors_allowed")) {
    stop("Structural prior manifest cannot permit raw structural predictors", call. = FALSE)
  }
  hashes <- c(
    data$parent_source_sha256, data$source_snapshot_sha256, data$source_metadata_sha256,
    data$source_rows_sha256, data$checksum_registry_sha256
  )
  if (any(!grepl("^[0-9a-f]{64}(\\|[0-9a-f]{64})*$", tolower(as.character(hashes))))) {
    stop("Structural prior manifest contains noncanonical source hashes", call. = FALSE)
  }
  cutoff <- as.Date(data$evidence_cutoff_exclusive)
  source_date <- as.Date(data$source_date)
  if (is.na(cutoff) || is.na(source_date) || source_date >= cutoff || as.integer(data$source_year) >= as.integer(format(cutoff, "%Y"))) {
    stop("Structural prior manifest source vintage is not strictly pre-cutoff", call. = FALSE)
  }
  if (!grepl("prior_weight=prior_strength/(prior_strength+effective_match_count)", as.character(data$prior_application_rule), fixed = TRUE) ||
      !grepl("effective_match_count", as.character(data$effective_count_formula), fixed = TRUE)) {
    stop("Structural prior manifest must declare continuous effective-count weighting", call. = FALSE)
  }
  for (name in c("research_only", "wc2026_sealed")) .phase11_bool(data[[name]][[1L]], paste0("structural prior ", name))
  .phase11_assert_hash(data, "row_sha256", "Phase 11 structural prior manifest")
  invisible(data)
}

#' Write the canonical structural-prior manifest.
#' @export
write_phase11_structural_prior_manifest <- function(
    manifest_path = "data/benchmark/phase11/structural_prior_manifest.csv", ...
) {
  root <- .phase11_protocol_root(".")
  path <- if (grepl("^(/|[A-Za-z]:[/\\\\])", manifest_path)) manifest_path else file.path(root, manifest_path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  row <- canonical_phase11_structural_prior_manifest(...)
  utils::write.csv(row, path, row.names = FALSE, na = "", quote = TRUE)
  validate_phase11_structural_prior_manifest(.phase11_read_csv(path))
  invisible(row)
}

#' Return immutable Phase 11 RF protocol constants.
#'
#' @export
phase11_protocol_constants <- function() {
  list(
    schema_version = "phase11-hybrid-protocol-v1",
    candidate_id = "phase11_rf_dynamic_elo_open",
    adapter_id = "phase11_hybrid_rf",
    adapter_version = "phase11-v1",
    panel_id = "open_core",
    mode_id = "open_default",
    score_support_max = 40L,
    open_fixture_count = 630L,
    rich_fixture_count = 609L,
    seed_id = "920001",
    ranger_package = "ranger",
    ranger_version = "0.18.0",
    research_only = TRUE,
    wc2026_sealed = TRUE
  )
}

#' Build the canonical open RF model-registration row.
#'
#' @export
canonical_phase11_model_registry <- function() {
  constants <- phase11_protocol_constants()
  registration <- data.frame(
    schema_version = "1.0",
    candidate_id = constants$candidate_id,
    model_family = "random_forest_goal_means",
    adapter_id = constants$adapter_id,
    adapter_version = constants$adapter_version,
    native_panel_id = constants$panel_id,
    panel_id = constants$panel_id,
    mode_id = constants$mode_id,
    mode = constants$mode_id,
    mean_model_id = "phase11_rf_dynamic_elo_open_v1",
    dependence_id = "negative_binomial_independent",
    mean_parent_candidate_id = "",
    nested_parent_candidate_id = "",
    tuning_protocol_id = "phase11_rf_registered_v1",
    tuning_grid_id = "phase11_rf_grid_v1",
    feature_set_id = "phase11_rf_dynamic_elo_open",
    rf_feature_set_id = "phase11_rf_dynamic_elo_open",
    score_support_max = as.character(constants$score_support_max),
    open_fixture_count = as.character(constants$open_fixture_count),
    rich_fixture_count = as.character(constants$rich_fixture_count),
    score_support_g = as.character(constants$score_support_max),
    open_mode_compatible = "true",
    research_only = "true",
    wc2026_sealed = "true",
    complexity_rank = "8",
    settings = paste(
      "num.trees=64", "mtry=3", "min.node.size=1",
      "seed_policy=registered_seed", "rf_feature_set_id=phase11_rf_dynamic_elo_open",
      "home_away_tuning_relationship=shared_registered_settings",
      "nb_dispersion_source=registered_nb_theta", "home_theta=8", "away_theta=8",
      sep = ";"
    ),
    `num.trees` = "64",
    mtry = "3",
    `min.node.size` = "1",
    seed_policy = "registered_seed",
    seed_id = constants$seed_id,
    home_away_tuning_relationship = "shared_registered_settings",
    nb_dispersion_source = "registered_nb_theta",
    home_theta = "8",
    away_theta = "8",
    ranger_package = constants$ranger_package,
    ranger_version = constants$ranger_version,
    ranger_provenance_id = .phase11_file_sha256("data/benchmark/phase11/ranger_provenance.csv"),
    phase10_parent_registry_sha256 = .phase11_file_sha256("data/benchmark/phase10/model_registry.csv"),
    context_feature_set_id = "",
    removed_feature_id = "",
    context_parent_hashes = "",
    centroid_registry_sha256 = "",
    centroid_metadata_sha256 = "",
    panel_rule = "open_core",
    feature_rule = "registered_dynamic_elo_features_only",
    gate_id = "",
    gate_parent_sha256 = "",
    structural_prior_manifest_sha256 = "",
    structural_snapshot_vintage_id = "",
    prior_strength = "",
    effective_count_formula = "",
    settings_identity = "",
    settings_sha256 = "",
    registration_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  registration$settings_sha256 <- .phase11_model_settings_sha256(registration)
  registration$tuning_grid_sha256 <- .phase11_rf_tuning_grid_sha256(registration)
  registration$registration_sha256 <- .phase11_row_sha256(registration, "registration_sha256")
  registration
}

.phase11_xg_model_row <- function(open_registration) {
  row <- open_registration
  row$candidate_id <- "phase11_rf_dynamic_elo_context_xg_gated_open"
  row$model_family <- "random_forest_goal_means_xg_gated"
  row$mean_model_id <- "phase11_rf_dynamic_elo_context_xg_gated_open_v1"
  row$mean_parent_candidate_id <- "phase11_rf_dynamic_elo_context_open"
  row$nested_parent_candidate_id <- "phase11_rf_dynamic_elo_context_open"
  row$feature_set_id <- "phase11_rf_dynamic_elo_context_xg_gated_open"
  row$rf_feature_set_id <- "phase11_rf_dynamic_elo_context_xg_gated_open"
  row$complexity_rank <- "10"
  row$settings <- paste(
    "num.trees=64", "mtry=3", "min.node.size=1",
    "seed_policy=registered_seed", "rf_feature_set_id=phase11_rf_dynamic_elo_context_xg_gated_open",
    "feature_rule=open_context_plus_xg_only_after_gate",
    "gate_id=phase11_xg_gate_d12_v1",
    "home_away_tuning_relationship=shared_registered_settings",
    "nb_dispersion_source=registered_nb_theta", "home_theta=8", "away_theta=8",
    sep = ";"
  )
  row$context_feature_set_id <- "phase11_rf_dynamic_elo_context_open"
  row$panel_rule <- "open_core_when_gate_active"
  row$feature_rule <- "open_context_plus_xg_only_after_gate"
  row$gate_id <- "phase11_xg_gate_d12_v1"
  row$gate_parent_sha256 <- .phase11_file_sha256("data/benchmark/phase11/xg_gate_manifest.csv")
  row$context_parent_hashes <- .phase11_context_centroid_file_hashes()$parent
  row$settings_sha256 <- .phase11_model_settings_sha256(row)
  row$tuning_grid_sha256 <- .phase11_rf_tuning_grid_sha256(row)
  row$registration_sha256 <- .phase11_row_sha256(row, "registration_sha256")
  row
}

.phase11_structural_model_row <- function(open_registration) {
  row <- open_registration
  row$candidate_id <- "phase11_structural_sparse_prior_open"
  row$model_family <- "random_forest_goal_means_structural_prior"
  row$mean_model_id <- "phase11_structural_sparse_prior_open_v1"
  row$mean_parent_candidate_id <- "phase11_rf_dynamic_elo_open"
  row$nested_parent_candidate_id <- "phase11_rf_dynamic_elo_open"
  row$feature_set_id <- "phase11_rf_dynamic_elo_open"
  row$rf_feature_set_id <- "phase11_rf_dynamic_elo_open"
  row$complexity_rank <- "9"
  row$settings <- paste(
    "num.trees=64", "mtry=3", "min.node.size=1",
    "seed_policy=registered_seed", "rf_feature_set_id=phase11_rf_dynamic_elo_open",
    "feature_rule=structural_prior_only_no_raw_fields",
    "structural_snapshot_vintage_id=worldbank_wdi_2000_v1",
    "prior_strength=4", "evidence_half_life_days=730",
    "effective_count_formula=registered_recency_weighted_appearances",
    "home_away_tuning_relationship=shared_registered_settings",
    "nb_dispersion_source=registered_nb_theta", "home_theta=8", "away_theta=8",
    sep = ";"
  )
  row$panel_rule <- "open_core"
  row$feature_rule <- "structural_prior_only_no_raw_fields"
  row$structural_prior_manifest_sha256 <- .phase11_file_sha256(
    "data/benchmark/phase11/structural_prior_manifest.csv"
  )
  row$structural_snapshot_vintage_id <- "worldbank_wdi_2000_v1"
  row$prior_strength <- "4"
  row$effective_count_formula <- paste(
    "effective_match_count=sum(exp(-log(2) * (evidence_cutoff_exclusive - match_date)",
    "/ evidence_half_life_days))"
  )
  row$settings_identity <- paste(
    "prior_strength=4", "evidence_half_life_days=730",
    "prior_scale=0.15", "prior_bounds=0.65|1.55",
    "raw_structural_predictors_allowed=false",
    sep = ";"
  )
  row$settings_sha256 <- .phase11_model_settings_sha256(row)
  row$tuning_grid_sha256 <- .phase11_rf_tuning_grid_sha256(row)
  row$registration_sha256 <- .phase11_row_sha256(row, "registration_sha256")
  row
}

.phase11_context_feature_ids <- function() {
  c("host", "neutral", "rest_days", "travel_km", "stage_id")
}

.phase11_context_candidate_ids <- function() {
  c(
    "phase11_rf_dynamic_elo_context_open",
    "phase11_rf_dynamic_elo_context_drop_host_open",
    "phase11_rf_dynamic_elo_context_drop_neutral_open",
    "phase11_rf_dynamic_elo_context_drop_rest_open",
    "phase11_rf_dynamic_elo_context_drop_travel_open",
    "phase11_rf_dynamic_elo_context_drop_stage_open"
  )
}

.phase11_context_centroid_file_hashes <- function() {
  centroid <- .phase11_file_sha256("data/benchmark/phase11/country_centroids.csv")
  metadata <- .phase11_file_sha256("data/benchmark/phase11/country_centroids_metadata.csv")
  list(
    centroid = centroid,
    metadata = metadata,
    parent = paste(centroid, metadata, sep = "#"),
    combined = .phase11_sha256(paste(centroid, metadata, sep = "|"))
  )
}

.phase11_context_model_row <- function(open_registration, candidate_id, removed_feature_id = "") {
  hashes <- .phase11_context_centroid_file_hashes()
  row <- open_registration
  row$candidate_id <- candidate_id
  row$mean_model_id <- paste0(candidate_id, "_v1")
  row$feature_set_id <- "phase11_rf_dynamic_elo_context_open"
  row$rf_feature_set_id <- "phase11_rf_dynamic_elo_context_open"
  row$mean_parent_candidate_id <- "phase11_rf_dynamic_elo_open"
  row$nested_parent_candidate_id <- "phase11_rf_dynamic_elo_open"
  row$complexity_rank <- "9"
  row$settings <- paste(
    "num.trees=64", "mtry=3", "min.node.size=1",
    "seed_policy=registered_seed", "rf_feature_set_id=phase11_rf_dynamic_elo_context_open",
    "context_features=host|neutral|rest_days|travel_km|stage_id",
    paste0("removed_feature_id=", removed_feature_id),
    "home_away_tuning_relationship=shared_registered_settings",
    "nb_dispersion_source=registered_nb_theta", "home_theta=8", "away_theta=8",
    sep = ";"
  )
  row$context_feature_set_id <- "phase11_rf_dynamic_elo_context_open"
  row$removed_feature_id <- removed_feature_id
  row$context_parent_hashes <- hashes$parent
  row$centroid_registry_sha256 <- hashes$centroid
  row$centroid_metadata_sha256 <- hashes$metadata
  row$settings_sha256 <- .phase11_model_settings_sha256(row)
  row$tuning_grid_sha256 <- .phase11_rf_tuning_grid_sha256(row)
  row$registration_sha256 <- .phase11_row_sha256(row, "registration_sha256")
  row
}

#' Return the complete Phase 11 model registry, including context variants.
#'
#' `canonical_phase11_model_registry()` intentionally remains the one-row RF
#' registration consumed by the inherited RF fit API.  This row-oriented
#' constructor is used for the durable Phase 11 registry file.
#' @export
canonical_phase11_model_registry_rows <- function() {
  open_registration <- canonical_phase11_model_registry()
  context <- do.call(rbind, lapply(seq_along(.phase11_context_candidate_ids()), function(index) {
    .phase11_context_model_row(
      open_registration,
      .phase11_context_candidate_ids()[[index]],
      if (index == 1L) "" else .phase11_context_feature_ids()[[index - 1L]]
    )
  }))
  xg <- .phase11_xg_model_row(open_registration)
  structural <- .phase11_structural_model_row(open_registration)
  rbind(open_registration, context, xg, structural)
}

#' Return the registered context bundle and one-feature-drop ablation rows.
#' @export
canonical_phase11_context_ablation_registry <- function() {
  hashes <- .phase11_context_centroid_file_hashes()
  candidates <- .phase11_context_candidate_ids()
  removed <- c("", .phase11_context_feature_ids())
  registry <- data.frame(
    schema_version = rep("1.0", length(candidates)),
    ablation_id = paste0("phase11_context_ablation__", c("full", .phase11_context_feature_ids())),
    candidate_id = candidates,
    model_id = candidates,
    base_candidate_id = rep("phase11_rf_dynamic_elo_context_open", length(candidates)),
    panel_id = rep("open_core", length(candidates)),
    mode_id = rep("open_default", length(candidates)),
    feature_set_id = rep("phase11_rf_dynamic_elo_context_open", length(candidates)),
    removed_feature_id = removed,
    comparison_role = c("full_context_bundle", rep("drop_one_context_feature", 5L)),
    open_fixture_count = rep("630", length(candidates)),
    rich_fixture_count = rep("609", length(candidates)),
    score_support_g = rep("40", length(candidates)),
    adapter_id = rep("phase11_hybrid_rf", length(candidates)),
    adapter_version = rep("phase11-v1", length(candidates)),
    source_parent_hashes = rep(hashes$parent, length(candidates)),
    availability_rule = rep(
      "strict common open_core context panel; source/fixture evidence must be point-in-time",
      length(candidates)
    ),
    missingness_rule = rep(
      "no silent imputation; unavailable context values make the candidate ineligible",
      length(candidates)
    ),
    research_only = rep("true", length(candidates)),
    wc2026_sealed = rep("true", length(candidates)),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  registry$row_sha256 <- .phase11_row_sha256(registry, "row_sha256")
  registry
}

#' Validate the context bundle and individual ablation registry.
#' @export
validate_phase11_context_ablation_registry <- function(data) {
  required <- c(
    "schema_version", "ablation_id", "candidate_id", "model_id", "base_candidate_id",
    "panel_id", "mode_id", "feature_set_id", "removed_feature_id", "comparison_role",
    "open_fixture_count", "rich_fixture_count", "score_support_g", "adapter_id",
    "adapter_version", "source_parent_hashes", "availability_rule", "missingness_rule",
    "research_only", "wc2026_sealed", "row_sha256"
  )
  .phase11_require_contracts()
  benchmark_contract_require_columns(data, required, "Phase 11 context ablation registry")
  benchmark_contract_require_unique(data, "candidate_id", "Phase 11 context ablation registry")
  expected <- .phase11_context_candidate_ids()
  if (!setequal(as.character(data$candidate_id), expected) || nrow(data) != length(expected)) {
    stop("Phase 11 context ablation registry must contain the full bundle and five drop-one rows", call. = FALSE)
  }
  if (any(as.character(data$panel_id) != "open_core") ||
      any(as.character(data$mode_id) != "open_default") ||
      any(as.integer(data$open_fixture_count) != 630L) ||
      any(as.integer(data$rich_fixture_count) != 609L) ||
      any(as.integer(data$score_support_g) != 40L)) {
    stop("Context ablations must preserve open_core 630/609/G=40", call. = FALSE)
  }
  if (any(!vapply(data$research_only, .phase11_bool, logical(1), label = "research_only")) ||
      any(!vapply(data$wc2026_sealed, .phase11_bool, logical(1), label = "wc2026_sealed"))) {
    stop("Context ablations must remain research-only with WC2026 sealed", call. = FALSE)
  }
  full <- data$candidate_id == expected[[1L]]
  if (any(as.character(data$removed_feature_id[full]) != "") ||
      any(as.character(data$comparison_role[full]) != "full_context_bundle")) {
    stop("The full context bundle cannot remove a feature", call. = FALSE)
  }
  drops <- data[!full, , drop = FALSE]
  expected_drop_ids <- .phase11_context_feature_ids()
  if (!setequal(as.character(drops$removed_feature_id), expected_drop_ids) ||
      any(as.character(drops$comparison_role) != "drop_one_context_feature")) {
    stop("Context ablations must remove exactly one named context feature", call. = FALSE)
  }
  parent_parts <- strsplit(as.character(data$source_parent_hashes), "#", fixed = TRUE)
  if (any(lengths(parent_parts) != 2L) || any(!vapply(parent_parts, function(x) all(grepl("^[0-9a-f]{64}$", x)), logical(1)))) {
    stop("Context ablation source parents must contain centroid and metadata SHA-256 values", call. = FALSE)
  }
  .phase11_assert_hash(data, "row_sha256", "Phase 11 context ablation registry")
  invisible(data)
}

#' Return the one-row deterministic RF tuning grid registered for Phase 11.
#'
#' The grid is intentionally small and immutable for this research-only
#' challenger.  Home and away forests share the same tuning identity.
#' @export
canonical_phase11_rf_tuning_grid <- function() {
  registration <- canonical_phase11_model_registry()
  data.frame(
    schema_version = "1.0",
    tuning_grid_id = registration$tuning_grid_id,
    tuning_grid_sha256 = registration$tuning_grid_sha256,
    candidate_id = registration$candidate_id,
    num.trees = as.integer(registration$`num.trees`),
    mtry = as.integer(registration$mtry),
    min.node.size = as.integer(registration$`min.node.size`),
    seed_policy = registration$seed_policy,
    seed_id = registration$seed_id,
    feature_set_id = registration$feature_set_id,
    rf_feature_set_id = registration$rf_feature_set_id,
    home_away_tuning_relationship = registration$home_away_tuning_relationship,
    nb_dispersion_source = registration$nb_dispersion_source,
    home_theta = as.numeric(registration$home_theta),
    away_theta = as.numeric(registration$away_theta),
    ranger_package = registration$ranger_package,
    ranger_version = registration$ranger_version,
    ranger_provenance_id = registration$ranger_provenance_id,
    settings_sha256 = registration$settings_sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

#' Validate the frozen one-row RF tuning grid against its registration.
#' @export
validate_phase11_rf_tuning_grid <- function(grid, registration = NULL) {
  required <- c(
    "tuning_grid_id", "tuning_grid_sha256", "candidate_id", "num.trees", "mtry",
    "min.node.size", "seed_policy", "feature_set_id", "home_away_tuning_relationship",
    "nb_dispersion_source", "home_theta", "away_theta", "ranger_package",
    "ranger_version", "ranger_provenance_id", "settings_sha256"
  )
  missing <- setdiff(required, names(grid))
  if (length(missing)) stop("Phase 11 RF tuning grid is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!is.data.frame(grid) || nrow(grid) != 1L) stop("Phase 11 RF tuning grid must contain exactly one frozen row", call. = FALSE)
  registration <- if (is.null(registration)) canonical_phase11_model_registry() else registration
  if (!is.data.frame(registration) || nrow(registration) != 1L) stop("RF tuning-grid registration must contain one row", call. = FALSE)
  if (!identical(as.character(grid$candidate_id), as.character(registration$candidate_id)) ||
      !identical(as.character(grid$tuning_grid_id), as.character(registration$tuning_grid_id)) ||
      !identical(as.character(grid$settings_sha256), as.character(registration$settings_sha256))) {
    stop("Phase 11 RF tuning grid does not match its model registration", call. = FALSE)
  }
  expected_grid_hash <- .phase11_rf_tuning_grid_sha256(registration)
  if (!identical(as.character(grid$tuning_grid_sha256), expected_grid_hash) ||
      !identical(as.character(registration$tuning_grid_sha256), expected_grid_hash)) {
    stop("Phase 11 RF tuning grid hash mismatch", call. = FALSE)
  }
  if (any(as.integer(grid$num.trees) != 64L) || any(as.integer(grid$mtry) != 3L) ||
      any(as.integer(grid$min.node.size) != 1L) ||
      any(as.character(grid$seed_policy) != "registered_seed") ||
      any(as.character(grid$home_away_tuning_relationship) != "shared_registered_settings") ||
      any(as.character(grid$nb_dispersion_source) != "registered_nb_theta") ||
      any(as.character(grid$ranger_package) != "ranger") ||
      any(as.character(grid$ranger_version) != "0.18.0")) {
    stop("Phase 11 RF tuning grid contains an unregistered setting", call. = FALSE)
  }
  invisible(grid)
}

#' Build the canonical open RF feature contract.
#'
#' @export
canonical_phase11_feature_contract <- function() {
  source_hash <- .phase11_file_sha256("R/forecast/dynamic_goal_ability.R")
  elo_hash <- .phase11_file_sha256("data/processed/elo_matches.csv")
  features <- data.frame(
    schema_version = rep("1.0", 5L),
    panel_id = rep("open_core", 5L),
    feature_id = c(
      "home_attack_effect", "home_defence_effect",
      "away_attack_effect", "away_defence_effect", "elo_diff"
    ),
    definition_version = rep("phase11-v1", 5L),
    definition = c(
      "Fold-local Phase 10 dynamic attack effect for the home team",
      "Fold-local Phase 10 dynamic defence effect for the home team",
      "Fold-local Phase 10 dynamic attack effect for the away team",
      "Fold-local Phase 10 dynamic defence effect for the away team",
      "Point-in-time Elo difference retained as a separate RF input"
    ),
    required = rep("true", 5L),
    source_id = c(rep("phase10_dynamic_goal_ability", 4L), "phase09_elo_open"),
    source_artifact_sha256 = c(rep(source_hash, 4L), elo_hash),
    availability_rule = rep("source date strictly before evidence_cutoff_exclusive", 5L),
    imputation_rule = rep("none; RF candidate fails closed when evidence is absent or imputed", 5L),
    missingness_rule = rep(
      "source presence, value presence, imputation, and active-fit status remain distinct", 5L
    ),
    allowed_max_source_lag_days = rep("-1", 5L),
    license_class = rep("open-or-derived-open", 5L),
    feature_set_id = rep("phase11_rf_dynamic_elo_open", 5L),
    active_status = rep("active", 5L),
    source_vintage = rep("phase10-fold-local-v1", 5L),
    derivation_rule = c(
      "fold-local dynamic attack evidence is inherited without transformation",
      "fold-local dynamic defence evidence is inherited without transformation",
      "fold-local dynamic attack evidence is inherited without transformation",
      "fold-local dynamic defence evidence is inherited without transformation",
      "point-in-time Elo difference is inherited without raw rating reconstruction"
    ),
    parent_artifact_sha256 = c(rep(source_hash, 4L), elo_hash),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  centroid_hashes <- .phase11_context_centroid_file_hashes()
  fixture_hash <- .phase11_file_sha256("data/benchmark/phase09/fixtures.csv")
  additions <- data.frame(
    schema_version = rep("1.0", 5L),
    panel_id = rep("open_core", 5L),
    feature_id = .phase11_context_feature_ids(),
    definition_version = rep("phase11-v1", 5L),
    definition = c(
      "Signed host-team indicator from checked fixture host metadata",
      "Neutral-venue indicator from checked fixture venue metadata",
      "Minimum days since either team's latest prior match before the cutoff",
      "Sum of home and away great-circle country-centroid travel proxies",
      "Tournament stage copied from checked fixture metadata"
    ),
    required = rep("true", 5L),
    source_id = c(
      "phase09_fixture_registry", "phase09_fixture_registry", "phase09_fixture_history",
      "phase09_fixture_history+natural_earth_centroids", "phase09_fixture_registry"
    ),
    source_artifact_sha256 = c(
      fixture_hash, fixture_hash, fixture_hash, centroid_hashes$combined, fixture_hash
    ),
    availability_rule = c(
      "checked fixture host metadata; no source date fabricated",
      "checked fixture neutral/venue metadata; no source date fabricated",
      "prior match dates strictly before evidence_cutoff_exclusive",
      paste0(
        "prior country-centroid proxy only; centroid artifact SHA-256=", centroid_hashes$centroid,
        "; metadata artifact SHA-256=", centroid_hashes$metadata,
        "; no stadium-level data"
      ),
      "checked fixture stage metadata; no source date fabricated"
    ),
    imputation_rule = rep(
      "none; strict open-context candidate fails closed when evidence is absent or imputed", 5L
    ),
    missingness_rule = rep(
      "source presence, value presence, imputation, derivation status, and active-fit status remain distinct", 5L
    ),
    allowed_max_source_lag_days = c("0", "0", "-1", "-1", "0"),
    license_class = rep("open-or-derived-open", 5L),
    feature_set_id = rep("phase11_rf_dynamic_elo_context_open", 5L),
    active_status = rep("active", 5L),
    source_vintage = c(
      "phase09-fixture-v1", "phase09-fixture-v1", "point-in-time history-v1",
      "Natural Earth 5.1.2 + point-in-time history-v1", "phase09-fixture-v1"
    ),
    derivation_rule = c(
      "signed host-team indicator: home=1, away=-1, non-playing host=0",
      "neutral venue indicator from checked neutral or venue_role metadata",
      "minimum days since latest prior match of either team; same-day rows excluded",
      "geosphere::distGeo from prior venue country, or prior host-country fallback, to current venue/host country",
      "stage copied from checked fixture metadata"
    ),
    parent_artifact_sha256 = c(
      fixture_hash, fixture_hash, fixture_hash, centroid_hashes$parent, fixture_hash
    ),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  features <- rbind(features, additions)
  features$row_sha256 <- .phase11_row_sha256(features, "row_sha256")
  features
}

#' Validate Phase 11 model registration rows, hashes, and sealed boundaries.
#'
#' @export
validate_hybrid_model_registry <- function(data) {
  .phase11_require_contracts()
  required <- c(
    "schema_version", "candidate_id", "model_family", "adapter_id", "adapter_version",
    "native_panel_id", "panel_id", "mode_id", "mean_model_id", "dependence_id",
    "tuning_protocol_id", "tuning_grid_id", "tuning_grid_sha256", "feature_set_id", "score_support_max", "open_fixture_count",
    "rich_fixture_count", "score_support_g", "open_mode_compatible", "research_only",
    "wc2026_sealed", "settings", "num.trees", "mtry", "min.node.size", "seed_policy",
    "seed_id", "home_away_tuning_relationship", "nb_dispersion_source", "home_theta",
    "away_theta", "ranger_package", "ranger_version", "ranger_provenance_id",
    "settings_sha256", "registration_sha256"
  )
  benchmark_contract_require_columns(data, required, "Phase 11 model registry")
  benchmark_contract_require_unique(data, "candidate_id", "Phase 11 model registry")
  if (!any(as.character(data$candidate_id) == "phase11_rf_dynamic_elo_open")) {
    stop("Phase 11 model registry must retain the open RF tracer", call. = FALSE)
  }
  if (any(as.integer(data$score_support_max) != 40L) ||
      any(as.integer(data$score_support_g) != 40L) ||
      any(as.integer(data$open_fixture_count) != 630L) ||
      any(as.integer(data$rich_fixture_count) != 609L)) {
    stop("Phase 11 model registry must preserve 630/609/G=40", call. = FALSE)
  }
  if (any(!vapply(data$research_only, .phase11_bool, logical(1), label = "research_only")) ||
      any(!vapply(data$wc2026_sealed, .phase11_bool, logical(1), label = "wc2026_sealed"))) {
    stop("Phase 11 candidates must remain research-only with WC2026 sealed", call. = FALSE)
  }
  if (any(as.character(data$native_panel_id) != as.character(data$panel_id))) {
    stop("Phase 11 model registry panel aliases drifted", call. = FALSE)
  }
  if (any(!as.character(data$model_family) %in% c(
    "random_forest_goal_means", "random_forest_goal_means_xg_gated",
    "random_forest_goal_means_structural_prior"
  )) ||
      any(as.character(data$adapter_id) != "phase11_hybrid_rf") ||
      any(as.character(data$ranger_package) != "ranger") ||
      any(as.character(data$ranger_version) != "0.18.0")) {
    stop("Phase 11 RF registry contains an unapproved adapter or runtime", call. = FALSE)
  }
  if (any(as.character(data$tuning_grid_id) != "phase11_rf_grid_v1") ||
      any(as.character(data$tuning_grid_sha256) != vapply(seq_len(nrow(data)), function(index) {
        .phase11_rf_tuning_grid_sha256(data[index, , drop = FALSE])
      }, character(1)))) {
    stop("Phase 11 RF registry tuning grid identity drifted", call. = FALSE)
  }
  .phase11_assert_hash(data, "settings_sha256", "Phase 11 model registry settings")
  .phase11_assert_hash(data, "registration_sha256", "Phase 11 model registry registration")
  context_rows <- data[grepl("context", as.character(data$candidate_id), fixed = TRUE) &
    !grepl("xg_gated", as.character(data$candidate_id), fixed = TRUE), , drop = FALSE]
  if (nrow(context_rows)) {
    expected_context <- .phase11_context_candidate_ids()
    if (!setequal(as.character(context_rows$candidate_id), expected_context) ||
        nrow(context_rows) != length(expected_context)) {
      stop("Phase 11 model registry must contain the full context bundle and five ablations", call. = FALSE)
    }
    required_context <- c(
      "context_feature_set_id", "removed_feature_id", "context_parent_hashes",
      "centroid_registry_sha256", "centroid_metadata_sha256"
    )
    benchmark_contract_require_columns(context_rows, required_context, "Phase 11 context model registry")
    if (any(as.character(context_rows$panel_id) != "open_core") ||
        any(as.character(context_rows$mode_id) != "open_default") ||
        any(as.character(context_rows$feature_set_id) != "phase11_rf_dynamic_elo_context_open") ||
        any(as.character(context_rows$context_feature_set_id) != "phase11_rf_dynamic_elo_context_open")) {
      stop("Phase 11 context models must remain open_default on open_core", call. = FALSE)
    }
    if (any(!grepl("^[0-9a-f]{64}#[0-9a-f]{64}$", tolower(as.character(context_rows$context_parent_hashes)))) ||
        any(!grepl("^[0-9a-f]{64}$", tolower(as.character(context_rows$centroid_registry_sha256)))) ||
        any(!grepl("^[0-9a-f]{64}$", tolower(as.character(context_rows$centroid_metadata_sha256))))) {
      stop("Phase 11 context model parent hashes are not canonical", call. = FALSE)
    }
    expected_removed <- c("", .phase11_context_feature_ids())
    actual_removed <- as.character(context_rows$removed_feature_id[match(expected_context, context_rows$candidate_id)])
    if (!identical(actual_removed, expected_removed)) {
      stop("Phase 11 context model registry removed-feature identities drifted", call. = FALSE)
    }
  }
  xg_rows <- data[as.character(data$candidate_id) == "phase11_rf_dynamic_elo_context_xg_gated_open", , drop = FALSE]
  if (nrow(xg_rows)) {
    required_xg <- c("panel_rule", "feature_rule", "gate_id", "gate_parent_sha256", "context_feature_set_id")
    benchmark_contract_require_columns(xg_rows, required_xg, "Phase 11 xG-gated model registry")
    if (as.character(xg_rows$panel_rule) != "open_core_when_gate_active" ||
        as.character(xg_rows$feature_rule) != "open_context_plus_xg_only_after_gate" ||
        as.character(xg_rows$gate_id) != "phase11_xg_gate_d12_v1" ||
        !grepl("^[0-9a-f]{64}$", tolower(as.character(xg_rows$gate_parent_sha256)))) {
      stop("Phase 11 xG candidate must carry the registered D-12 gate parent and activation rules", call. = FALSE)
    }
    if (as.character(xg_rows$panel_id) != "open_core" || as.character(xg_rows$mode_id) != "open_default") {
      stop("Phase 11 xG candidate must remain open_default on open_core", call. = FALSE)
    }
  }
  structural_rows <- data[as.character(data$candidate_id) == "phase11_structural_sparse_prior_open", , drop = FALSE]
  if (nrow(structural_rows)) {
    required_structural <- c(
      "panel_rule", "feature_rule", "structural_prior_manifest_sha256",
      "structural_snapshot_vintage_id", "prior_strength", "effective_count_formula",
      "settings_identity"
    )
    benchmark_contract_require_columns(
      structural_rows, required_structural, "Phase 11 structural-prior model registry"
    )
    manifest_path <- .phase11_protocol_path(
      "data/benchmark/phase11/structural_prior_manifest.csv"
    )
    expected_manifest_hash <- if (file.exists(manifest_path)) {
      .phase11_file_sha256("data/benchmark/phase11/structural_prior_manifest.csv")
    } else ""
    if (as.character(structural_rows$panel_rule) != "open_core" ||
        as.character(structural_rows$feature_rule) != "structural_prior_only_no_raw_fields" ||
        as.character(structural_rows$panel_id) != "open_core" ||
        as.character(structural_rows$mode_id) != "open_default" ||
        as.character(structural_rows$feature_set_id) != "phase11_rf_dynamic_elo_open" ||
        as.character(structural_rows$structural_snapshot_vintage_id) != "worldbank_wdi_2000_v1" ||
        as.numeric(structural_rows$prior_strength) != 4 ||
        !grepl("^[0-9a-f]{64}$", tolower(as.character(structural_rows$structural_prior_manifest_sha256))) ||
        (nzchar(expected_manifest_hash) &&
          !identical(tolower(as.character(structural_rows$structural_prior_manifest_sha256)), expected_manifest_hash)) ||
        !grepl("effective_match_count", as.character(structural_rows$effective_count_formula), fixed = TRUE) ||
        !nzchar(as.character(structural_rows$settings_identity))) {
      stop("Phase 11 structural-prior candidate has invalid registered prior identity", call. = FALSE)
    }
  }
  invisible(data)
}

#' Validate Phase 11 feature-contract rows and evidence semantics.
#'
#' @export
validate_hybrid_feature_contract <- function(data) {
  .phase11_require_contracts()
  required <- c(
    "schema_version", "panel_id", "feature_id", "definition_version", "definition",
    "required", "source_id", "source_artifact_sha256", "availability_rule",
    "imputation_rule", "missingness_rule", "allowed_max_source_lag_days", "license_class",
    "feature_set_id", "active_status", "row_sha256"
  )
  benchmark_contract_require_columns(data, required, "Phase 11 feature contract")
  benchmark_contract_require_unique(data, c("panel_id", "feature_id"), "Phase 11 feature contract")
  required_features <- c(
    "home_attack_effect", "home_defence_effect", "away_attack_effect",
    "away_defence_effect", "elo_diff"
  )
  if (!all(required_features %in% as.character(data$feature_id[data$panel_id == "open_core"]))) {
    stop("Phase 11 feature contract is missing the RF dynamic/Elo feature set", call. = FALSE)
  }
  context_features <- .phase11_context_feature_ids()
  if (!all(context_features %in% as.character(data$feature_id[data$panel_id == "open_core"]))) {
    stop("Phase 11 feature contract is missing the open-context feature set", call. = FALSE)
  }
  if (any(!grepl("^[0-9a-f]{64}$", tolower(as.character(data$source_artifact_sha256)))) ||
      any(!grepl("^[0-9a-f]{64}$", tolower(as.character(data$row_sha256))))) {
    stop("Phase 11 feature contract provenance hashes must be canonical SHA-256", call. = FALSE)
  }
  context_rows <- data[data$feature_id %in% context_features, , drop = FALSE]
  if (any(as.character(context_rows$feature_set_id) != "phase11_rf_dynamic_elo_context_open") ||
      any(as.character(context_rows$license_class) != "open-or-derived-open")) {
    stop("Phase 11 context feature contract rows have an invalid feature set or license", call. = FALSE)
  }
  if (!"parent_artifact_sha256" %in% names(context_rows)) {
    stop("Phase 11 context feature contract is missing parent artifact hashes", call. = FALSE)
  }
  travel <- context_rows[context_rows$feature_id == "travel_km", , drop = FALSE]
  if (nrow(travel) != 1L || !grepl("^[0-9a-f]{64}#[0-9a-f]{64}$", tolower(as.character(travel$parent_artifact_sha256)))) {
    stop("Phase 11 travel_km must carry centroid and metadata parent hashes", call. = FALSE)
  }
  .phase11_assert_hash(data, "row_sha256", "Phase 11 feature contract")
  invisible(data)
}

#' Load and validate the Phase 11 protocol files.
#'
#' @export
load_and_validate_hybrid_protocol <- function(
    protocol_dir = "data/benchmark/phase11"
) {
  root <- .phase11_protocol_root(".")
  directory <- if (grepl("^(/|[A-Za-z]:[/\\\\])", protocol_dir)) {
    normalizePath(protocol_dir, mustWork = TRUE)
  } else {
    normalizePath(file.path(root, protocol_dir), mustWork = TRUE)
  }
  model_registry <- .phase11_read_csv(file.path(directory, "model_registry.csv"))
  feature_contract <- .phase11_read_csv(file.path(directory, "feature_contract.csv"))
  validate_hybrid_model_registry(model_registry)
  validate_hybrid_feature_contract(feature_contract)
  result <- list(
    valid = TRUE,
    protocol_version = "phase11-hybrid-protocol-v1",
    model_registry = model_registry,
    feature_contract = feature_contract,
    ranger_provenance = file.path(directory, "ranger_provenance.csv")
  )
  optional <- c(
    "mode_registry", "xg_gate_manifest", "structural_prior_manifest",
    "manual_market_manifest", "context_ablation_registry"
  )
  for (name in optional) {
    path <- file.path(directory, paste0(name, ".csv"))
    if (file.exists(path)) result[[name]] <- utils::read.csv(
      path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"
    )
  }
  if ("xg_gate_manifest" %in% names(result)) {
    validate_phase11_xg_gate_manifest(result$xg_gate_manifest)
    xg_rows <- model_registry[as.character(model_registry$candidate_id) == "phase11_rf_dynamic_elo_context_xg_gated_open", , drop = FALSE]
    if (nrow(xg_rows) != 1L) stop("Phase 11 xG gate manifest requires one registered xG-gated model row", call. = FALSE)
    manifest_hash <- .phase11_file_sha256(file.path(directory, "xg_gate_manifest.csv"))
    if (!identical(tolower(as.character(xg_rows$gate_parent_sha256)), manifest_hash)) {
      stop("Phase 11 xG-gated model registry does not parent the checked gate manifest", call. = FALSE)
    }
  }
  if ("structural_prior_manifest" %in% names(result)) {
    if (!exists("load_structural_prior_snapshots", mode = "function")) {
      source(.phase11_protocol_path("R", "forecast", "structural_prior.R"), local = .GlobalEnv)
    }
    structural_error <- NULL
    tryCatch({
      validate_phase11_structural_prior_manifest(result$structural_prior_manifest)
      structural_row <- result$structural_prior_manifest[1L, , drop = FALSE]
      validate_phase11_structural_source_manifest(
        snapshot_path = as.character(structural_row$snapshot_path[[1L]]),
        metadata_path = as.character(structural_row$metadata_path[[1L]]),
        checksums_path = as.character(structural_row$checksums_path[[1L]]),
        evidence_cutoff_exclusive = as.Date(structural_row$evidence_cutoff_exclusive[[1L]]),
        registered_vintage_id = as.character(structural_row$snapshot_vintage_id[[1L]])
      )
    }, error = function(error) {
      structural_error <<- conditionMessage(error)
    })
    if (!is.null(structural_error)) {
      result$structural_prior_manifest_error <- paste(
        "Structural prior inactive:", structural_error
      )
    }
  }
  if (file.exists(file.path(directory, "country_centroids.csv")) &&
      file.exists(file.path(directory, "country_centroids_metadata.csv"))) {
    .phase11_protocol_source_if_missing <- function(relative_path, symbols) {
      missing_symbols <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
      if (!length(missing_symbols)) return(invisible(TRUE))
      source(.phase11_protocol_path(relative_path), local = .GlobalEnv)
      invisible(TRUE)
    }
    .phase11_protocol_source_if_missing(
      "R/forecast/context_features.R",
      c("load_phase11_country_centroids", "validate_phase11_country_centroids")
    )
    result$country_centroids <- load_phase11_country_centroids(
      file.path(directory, "country_centroids.csv"),
      file.path(directory, "country_centroids_metadata.csv")
    )
  }
  if ("context_ablation_registry" %in% names(result)) {
    validate_phase11_context_ablation_registry(result$context_ablation_registry)
  }
  class(result) <- c("validated_hybrid_protocol", "list")
  result
}

#' Return one validated Phase 11 registration row.
#'
#' @export
hybrid_registration <- function(protocol, candidate_id) {
  if (!inherits(protocol, "validated_hybrid_protocol") || !isTRUE(protocol$valid)) {
    stop("protocol must be a validated Phase 11 protocol", call. = FALSE)
  }
  candidate_id <- as.character(candidate_id)
  if (length(candidate_id) != 1L || is.na(candidate_id) || !nzchar(candidate_id)) {
    stop("candidate_id must be one registered Phase 11 identifier", call. = FALSE)
  }
  row <- protocol$model_registry[protocol$model_registry$candidate_id == candidate_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("unknown Phase 11 candidate_id", call. = FALSE)
  row
}

#' Write the current canonical Phase 11 Task 1 protocol files.
#'
#' @export
write_phase11_hybrid_protocol <- function(protocol_dir = "data/benchmark/phase11") {
  root <- .phase11_protocol_root(".")
  directory <- if (grepl("^(/|[A-Za-z]:[/\\\\])", protocol_dir)) {
    normalizePath(protocol_dir, mustWork = FALSE)
  } else {
    file.path(root, protocol_dir)
  }
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  write_phase11_xg_gate_manifest(file.path(directory, "xg_gate_manifest.csv"))
  structural_paths <- file.path(
    directory,
    c("structural_sources.csv", "structural_sources_metadata.csv", "structural_sources_checksums.csv")
  )
  if (all(file.exists(structural_paths)) && exists("write_phase11_structural_prior_manifest", mode = "function")) {
    write_phase11_structural_prior_manifest(
      file.path(directory, "structural_prior_manifest.csv"),
      snapshot_path = structural_paths[[1L]],
      metadata_path = structural_paths[[2L]],
      checksums_path = structural_paths[[3L]]
    )
  }
  utils::write.csv(
    canonical_phase11_feature_contract(), file.path(directory, "feature_contract.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  utils::write.csv(
    canonical_phase11_context_ablation_registry(), file.path(directory, "context_ablation_registry.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  utils::write.csv(
    canonical_phase11_model_registry_rows(), file.path(directory, "model_registry.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  load_and_validate_hybrid_protocol(protocol_dir)
}

write_hybrid_protocol <- write_phase11_hybrid_protocol
