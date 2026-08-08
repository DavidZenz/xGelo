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
  path <- .phase11_protocol_path(relative_path)
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
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
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
  if (any(as.character(data$model_family) != "random_forest_goal_means") ||
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
  if (any(!grepl("^[0-9a-f]{64}$", tolower(as.character(data$source_artifact_sha256)))) ||
      any(!grepl("^[0-9a-f]{64}$", tolower(as.character(data$row_sha256))))) {
    stop("Phase 11 feature contract provenance hashes must be canonical SHA-256", call. = FALSE)
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
      path, stringsAsFactors = FALSE, check.names = FALSE
    )
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
  utils::write.csv(
    canonical_phase11_model_registry(), file.path(directory, "model_registry.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  utils::write.csv(
    canonical_phase11_feature_contract(), file.path(directory, "feature_contract.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  load_and_validate_hybrid_protocol(protocol_dir)
}

write_hybrid_protocol <- write_phase11_hybrid_protocol
