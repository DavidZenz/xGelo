#' Canonical Phase 10 challenger protocol and fail-closed validators

.phase10_cache <- new.env(parent = emptyenv())

.phase10_project_root <- function(path = ".") {
  if (exists("benchmark_find_project_root", mode = "function")) {
    return(benchmark_find_project_root(path))
  }
  candidate <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Could not locate the xGelo project root", call. = FALSE)
    candidate <- parent
  }
}

.phase10_project_path <- function(...) file.path(.phase10_project_root("."), ...)

.phase10_sha256 <- function(value = NULL, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 10 protocol validation", call. = FALSE)
  }
  if (isTRUE(file)) return(digest::digest(value, algo = "sha256", file = TRUE))
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.phase10_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value[value == "TRUE"] <- "true"
  value[value == "FALSE"] <- "false"
  value
}

.phase10_row_sha256 <- function(data, hash_col) {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], .phase10_scalar, character(1))
    .phase10_sha256(paste(values, collapse = "|"))
  }, character(1))
}

.phase10_subset_sha256 <- function(data, fields) {
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], .phase10_scalar, character(1))
    .phase10_sha256(paste(values, collapse = "|"))
  }, character(1))
}

.phase10_canonical_table_sha256 <- function(data) {
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, , drop = FALSE], .phase10_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  .phase10_sha256(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"))
}

.phase10_read_csv <- function(path) {
  if (!file.exists(path)) stop("Phase 10 protocol file is missing: ", basename(path), call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
}

.phase10_assert_exact <- function(actual, expected, label) {
  if (!identical(names(actual), names(expected))) {
    stop(label, " Phase 10 schema or column order drift", call. = FALSE)
  }
  if (!identical(dim(actual), dim(expected))) {
    stop(label, " Phase 10 row cardinality drift", call. = FALSE)
  }
  exact_character <- function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  }
  actual[] <- lapply(actual, exact_character)
  expected[] <- lapply(expected, exact_character)
  if (!identical(actual, expected)) {
    mismatch <- which(as.matrix(actual) != as.matrix(expected), arr.ind = TRUE)
    detail <- if (nrow(mismatch)) {
      paste0(" at row ", mismatch[1, 1], ", column ", names(actual)[mismatch[1, 2]])
    } else ""
    stop(label, " Phase 10 canonical content or order drift", detail, call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_validate_hash <- function(data, hash_col, label, fields = NULL) {
  if (!hash_col %in% names(data)) stop(label, " Phase 10 hash column is missing", call. = FALSE)
  actual <- tolower(.phase10_scalar(data[[hash_col]]))
  if (any(!grepl("^[0-9a-f]{64}$", actual))) {
    stop(label, " Phase 10 contains noncanonical SHA-256 values", call. = FALSE)
  }
  expected <- if (is.null(fields)) .phase10_row_sha256(data, hash_col) else .phase10_subset_sha256(data, fields)
  bad <- which(actual != expected)
  if (length(bad)) stop(label, " Phase 10 hash mismatch at row ", bad[1], call. = FALSE)
  invisible(TRUE)
}

#' Return immutable Phase 10 protocol identities and ordering
#'
#' @return Named list of exact constants.
#' @export
phase10_protocol_constants <- function() {
  list(
    schema_version = "phase10-challenger-protocol-v1",
    phase09_bundle_sha256 = "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069",
    phase09_registry_sha256 = "a3d21b90568aec86f44cefe2964555cb5565e1ab4e205489f42009a3ec489255",
    phase09_checksum_self_sha256 = "4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309",
    phase09_parent_graph_sha256 = "19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584",
    candidate_ids = c(
      "poisson_team_ridge", "poisson_team_ridge_elo",
      "dynamic_goal_ability", "dynamic_goal_ability_elo",
      "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
      "open_nb_elo_only_ablation"
    ),
    outer_edition_ids = c(
      "wc2002", "euro2004", "wc2006", "euro2008", "wc2010", "euro2012",
      "wc2014", "euro2016", "wc2018", "euro2020", "wc2022", "euro2024"
    ),
    pre2002_edition_ids = c("wc1994", "euro1996", "wc1998", "euro2000"),
    score_support_max = 40L,
    pre2002_history_rows = 26134L,
    storage_pilot_compressed_bytes = 27170610,
    storage_pilot_content_sha256 = "eb13096422d8482a4ca1450277e31ff516b09a932529d9248e4c0be265075f1f",
    storage_pilot_available_bytes = 17110360064
  )
}

.canonical_phase10_model_registry <- function() {
  constants <- phase10_protocol_constants()
  candidate_id <- constants$candidate_ids
  registry <- data.frame(
    schema_version = rep("1.0", 7L),
    candidate_id = candidate_id,
    model_family = c(
      "penalized_poisson", "penalized_poisson", "dynamic_poisson", "dynamic_poisson",
      "penalized_poisson_dependence", "penalized_poisson_dependence", "negative_binomial_ablation"
    ),
    adapter_id = c(
      "penalized_poisson", "penalized_poisson", "dynamic_goal_ability", "dynamic_goal_ability",
      "penalized_poisson_dc", "penalized_poisson_bivpois", "open_nb_elo_only_ablation"
    ),
    adapter_version = rep("phase10-v1", 7L),
    native_panel_id = rep("open_core", 7L),
    mean_model_id = c(
      "poisson_team_ridge_v1", "poisson_team_ridge_elo_v1",
      "dynamic_goal_ability_v1", "dynamic_goal_ability_elo_v1",
      "poisson_team_ridge_elo_v1", "poisson_team_ridge_elo_v1",
      "open_nb_elo_only_v1"
    ),
    dependence_id = c("independent", "independent", "independent", "independent", "dixon_coles", "bivariate_poisson", "independent"),
    mean_parent_candidate_id = c("", "poisson_team_ridge", "", "dynamic_goal_ability", "poisson_team_ridge_elo", "poisson_team_ridge_elo", "open_nb_incumbent"),
    nested_parent_candidate_id = c("", "poisson_team_ridge", "", "dynamic_goal_ability", "poisson_team_ridge_elo", "poisson_team_ridge_elo", "open_nb_incumbent"),
    tuning_protocol_id = c("nested_ridge_v1", "nested_ridge_elo_v1", "dynamic_pseudo_exposure_v1", "dynamic_pseudo_exposure_elo_v1", "nested_ridge_elo_dc_v1", "nested_ridge_elo_bivpois_v1", "fixed_incumbent_ablation_v1"),
    feature_set_id = c("team_venue", "team_venue_elo", "dynamic_state", "dynamic_state_elo", "team_venue_elo", "team_venue_elo", "incumbent_elo_only"),
    score_support_max = rep("40", 7L),
    open_mode_compatible = rep("true", 7L),
    complexity_rank = as.character(1:7),
    settings = c(
      "ridge_team_blocks=true;venue_unpenalized=true;cold_start=global_log_mean",
      "mean_parent=poisson_team_ridge;elo_offset_lasso=true;zero_elo_recovers_parent=true",
      "date_batch_updates=true;half_life_days=730;fixed_pseudo_exposure=true",
      "mean_parent=dynamic_goal_ability;elo_term=true;date_batch_updates=true",
      "mean_parent=poisson_team_ridge_elo;rho_scope=outer_fold_global;positivity_intersection=true",
      "mean_parent=poisson_team_ridge_elo;q_scope=outer_fold_global;kappa=q_min_mu=true",
      "parent=open_nb_incumbent;retained=elo_diff;inactive_xg_form=true"
    ),
    phase09_parent_bundle_sha256 = rep(constants$phase09_bundle_sha256, 7L),
    phase09_parent_registry_sha256 = rep(constants$phase09_registry_sha256, 7L),
    phase09_checksum_self_sha256 = rep(constants$phase09_checksum_self_sha256, 7L),
    phase09_parent_graph_sha256 = rep(constants$phase09_parent_graph_sha256, 7L),
    settings_sha256 = "",
    registration_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  settings_fields <- c(
    "candidate_id", "adapter_id", "adapter_version", "mean_model_id", "dependence_id",
    "tuning_protocol_id", "feature_set_id", "score_support_max", "settings"
  )
  registry$settings_sha256 <- .phase10_subset_sha256(registry, settings_fields)
  registry$registration_sha256 <- .phase10_row_sha256(registry, "registration_sha256")
  registry
}

.canonical_phase10_feature_contract <- function() {
  inherited <- .phase10_read_csv(.phase10_project_path("data", "benchmark", "phase09", "feature_contract.csv"))
  source_hash <- .phase10_sha256(.phase10_project_path("data", "processed", "elo_matches.csv"), file = TRUE)
  additions <- data.frame(
    schema_version = rep("1.0", 8L),
    panel_id = rep("open_core", 8L),
    feature_id = c(
      "attack_prior_match_count", "defence_prior_match_count", "team_shrinkage_weight",
      "team_cold_start", "dynamic_state_age_days", "dynamic_state_exposure",
      "dependence_parameter", "xg_form_inactive_status"
    ),
    definition_version = rep("phase10-v1", 8L),
    definition = c(
      "Strictly prior attack-side match count used for ridge shrinkage evidence",
      "Strictly prior defence-side match count used for ridge shrinkage evidence",
      "Registered ridge or pseudo-exposure shrinkage weight at prediction boundary",
      "Explicit sparse or unseen-team cold-start indicator",
      "Days since latest strictly prior dynamic-state evidence",
      "Decayed dynamic-state exposure plus fixed global pseudo-exposure",
      "Fold-global prior-fitted dependence parameter with provenance",
      "Explicit inactive status for zero-coverage xG and form predictors"
    ),
    required = rep("true", 8L),
    source_id = c(rep("international_goal_history_open", 6L), "phase10_prior_fold_fit", "phase09_zero_coverage_audit"),
    source_artifact_sha256 = c(rep(source_hash, 6L), phase10_protocol_constants()$phase09_parent_graph_sha256, phase10_protocol_constants()$phase09_checksum_self_sha256),
    availability_rule = c(rep("source date strictly before evidence_cutoff_exclusive", 6L), "estimated only from completed editions before outer opener", "inherited Phase 9 coverage remains source absent and inactive"),
    imputation_rule = c(rep("finite global-prior fallback with explicit imputed flag", 6L), "none; candidate fails when prior fit is unavailable", "formula-compatible zero with explicit inactive reason"),
    missingness_rule = rep("source presence, value presence, imputation, and active-fit status remain distinct", 8L),
    allowed_max_source_lag_days = rep("-1", 8L),
    license_class = rep("open-or-derived-open", 8L),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  additions$row_sha256 <- .phase10_row_sha256(additions, "row_sha256")
  result <- rbind(inherited, additions)
  rownames(result) <- NULL
  result
}

.phase10_grid_values <- function(start, stop) {
  values <- 10^seq(start, stop, by = 0.5)
  vapply(values, function(value) {
    text <- format(value, digits = 15, scientific = FALSE, trim = TRUE)
    if (grepl(".", text, fixed = TRUE)) text <- sub("0+$", "", text)
    sub("\\.$", "", text)
  }, character(1))
}

#' Build the exact ordered 33-row Phase 10 tuning grid
#'
#' @return Canonical all-character tuning-grid data frame.
#' @export
canonical_phase10_tuning_grid <- function() {
  values <- c(.phase10_grid_values(-4, 2), .phase10_grid_values(-5, 1), as.character(c(2, 4, 8, 16, 32)), "", "")
  parameter_id <- c(rep("team_ridge_lambda", 13L), rep("elo_lasso_lambda", 13L), rep("dynamic_pseudo_exposure", 5L), "dixon_coles_rho", "bivariate_q")
  grid <- data.frame(
    schema_version = rep("1.0", 33L),
    grid_order = as.character(seq_len(33L)),
    parameter_id = parameter_id,
    parameter_family = c(rep("discrete", 31L), "bounded_continuous", "bounded_continuous"),
    candidate_scope = c(rep("penalized_poisson_mean", 26L), rep("dynamic_goal_ability", 5L), "dixon_coles", "bivariate_poisson"),
    parameter_value = values,
    lower_bound = c(rep("", 31L), "positivity_intersection", "0"),
    upper_bound = c(rep("", 31L), "positivity_intersection", "0.95"),
    lower_inclusive = c(rep("", 31L), "false", "true"),
    upper_inclusive = c(rep("", 31L), "false", "false"),
    half_life_days = c(rep("", 26L), rep("730", 5L), "", ""),
    interior_epsilon = c(rep("", 31L), "0.00000001", ""),
    optimizer_tolerance = c(rep("", 32L), "0.00000001"),
    selection_objective = rep("equal_tournament_updating_rps_prior_editions_only", 33L),
    tie_break = c(rep("largest_penalty", 26L), rep("largest_pseudo_exposure", 5L), "closest_to_zero", "smallest_q"),
    settings_sha256 = "",
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  settings_fields <- setdiff(names(grid), c("settings_sha256", "row_sha256"))
  grid$settings_sha256 <- .phase10_subset_sha256(grid, settings_fields)
  grid$row_sha256 <- .phase10_row_sha256(grid, "row_sha256")
  grid
}

.phase10_edition_catalog <- function() {
  pre <- data.frame(
    edition_id = c("wc1994", "euro1996", "wc1998", "euro2000"),
    competition = c("FIFA World Cup", "UEFA Euro", "FIFA World Cup", "UEFA Euro"),
    opener_date = c("1994-06-17", "1996-06-08", "1998-06-10", "2000-06-10"),
    final_date = c("1994-07-17", "1996-06-30", "1998-07-12", "2000-07-02"),
    source = "pre2002_diagnostic",
    expected_fixture_count = c(52L, 31L, 64L, 31L),
    stringsAsFactors = FALSE
  )
  tournaments <- utils::read.csv(
    .phase10_project_path("data", "benchmark", "phase09", "tournaments.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase09 <- data.frame(
    edition_id = tournaments$edition_id,
    competition = ifelse(tournaments$competition_id == "world_cup", "FIFA World Cup", "UEFA Euro"),
    opener_date = as.character(tournaments$opener_date),
    final_date = as.character(tournaments$final_date),
    source = "phase09_assessment",
    expected_fixture_count = as.integer(tournaments$expected_fixture_count),
    stringsAsFactors = FALSE
  )
  rbind(pre, phase09)
}

.phase10_match_id_facts <- function() {
  cache_key <- "match_id_facts"
  if (exists(cache_key, .phase10_cache, inherits = FALSE)) return(get(cache_key, .phase10_cache))
  history <- utils::read.csv(
    .phase10_project_path("data", "processed", "elo_matches.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  history$date <- as.Date(history$date)
  catalog <- .phase10_edition_catalog()
  facts <- lapply(seq_len(nrow(catalog)), function(index) {
    edition <- catalog[index, , drop = FALSE]
    rows <- history[
      history$tournament == edition$competition &
        history$date >= as.Date(edition$opener_date) & history$date <= as.Date(edition$final_date),
      , drop = FALSE
    ]
    ids <- sort(unique(as.character(rows$match_id[nzchar(as.character(rows$match_id))])), method = "radix")
    if (length(ids) != edition$expected_fixture_count) {
      stop("Phase 10 chronology source fixture count drift for ", edition$edition_id, call. = FALSE)
    }
    data.frame(
      edition_id = edition$edition_id,
      inner_fixture_count = as.character(length(ids)),
      eligible_match_ids_sha256 = .phase10_sha256(paste(ids, collapse = "|")),
      stringsAsFactors = FALSE
    )
  })
  facts <- do.call(rbind, facts)
  assign(cache_key, facts, .phase10_cache)
  facts
}

#' Build the complete 114-row prior-edition relation
#'
#' @return Canonical all-character chronology data frame.
#' @export
canonical_phase10_tuning_relations <- function() {
  catalog <- .phase10_edition_catalog()
  facts <- .phase10_match_id_facts()
  outer_ids <- phase10_protocol_constants()$outer_edition_ids
  outer <- catalog[match(outer_ids, catalog$edition_id), , drop = FALSE]
  relations <- do.call(rbind, lapply(seq_len(nrow(outer)), function(index) {
    eligible <- catalog[as.Date(catalog$final_date) < as.Date(outer$opener_date[index]), , drop = FALSE]
    eligible <- eligible[order(as.Date(eligible$final_date), eligible$edition_id, method = "radix"), , drop = FALSE]
    data.frame(
      schema_version = "1.0",
      relation_order = "",
      outer_edition_id = outer$edition_id[index],
      outer_opener_date = outer$opener_date[index],
      inner_edition_id = eligible$edition_id,
      inner_opener_date = eligible$opener_date,
      inner_final_date = eligible$final_date,
      inner_source = eligible$source,
      inner_fixture_count = facts$inner_fixture_count[match(eligible$edition_id, facts$edition_id)],
      eligible_match_ids_sha256 = facts$eligible_match_ids_sha256[match(eligible$edition_id, facts$edition_id)],
      objective_track = "updating",
      relation_sha256 = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  relations$relation_order <- as.character(seq_len(nrow(relations)))
  relations$relation_sha256 <- .phase10_row_sha256(relations, "relation_sha256")
  rownames(relations) <- NULL
  if (nrow(relations) != 114L) stop("Phase 10 canonical chronology must contain exactly 114 relations", call. = FALSE)
  relations
}

#' Reconstruct and verify the exact accepted Phase 9 parent identity
#'
#' @return Validated immutable parent facts.
#' @export
validate_phase09_parent_identity <- function() {
  if (exists("phase09_parent", .phase10_cache, inherits = FALSE)) return(get("phase09_parent", .phase10_cache))
  if (!exists("require_challenger_environment", mode = "function")) {
    source(.phase10_project_path("R", "benchmark", "challenger_preflight.R"), local = globalenv())
  }
  if (!exists("require_challenger_environment", mode = "function")) {
    stop("require_challenger_environment() is unavailable for parent validation", call. = FALSE)
  }
  constants <- phase10_protocol_constants()
  environment <- require_challenger_environment("data/benchmark/phase10/glmnet_provenance.csv")
  registry_path <- .phase10_project_path("data", "benchmark", "phase09", "model_registry.csv")
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  registry$schema_version <- as.character(registry$schema_version)
  registry$schema_version[registry$schema_version == "1"] <- "1.0"
  registry_sha256 <- canonical_benchmark_sha256(registry, "model_id")
  bundle_root <- .phase10_project_path(
    "outputs", "benchmarks", "rolling_tournaments", "phase09-baselines-frozen"
  )
  checksum <- utils::read.csv(
    file.path(bundle_root, "manifests", "checksum_manifest.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  run_manifest <- utils::read.csv(
    file.path(bundle_root, "run_manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE
  )
  checksum_registry <- checksum$canonical_content_sha256[checksum$artifact == "model_registry"]
  if (length(checksum_registry) != 1L || !identical(registry_sha256, checksum_registry) ||
      !identical(registry_sha256, as.character(run_manifest$model_registry_sha256))) {
    stop("Phase 9 durable model-registry parent identity drift", call. = FALSE)
  }
  facts <- list(
    valid = TRUE,
    bundle_sha256 = environment$phase09_bundle_sha256,
    model_registry_sha256 = registry_sha256,
    checksum_self_sha256 = environment$phase09_checksum_self_sha256,
    parent_graph_sha256 = environment$phase09_parent_graph_sha256
  )
  expected <- unname(c(
    constants$phase09_bundle_sha256, constants$phase09_registry_sha256,
    constants$phase09_checksum_self_sha256, constants$phase09_parent_graph_sha256
  ))
  actual <- unname(c(facts$bundle_sha256, facts$model_registry_sha256, facts$checksum_self_sha256, facts$parent_graph_sha256))
  if (!identical(actual, expected)) stop("Phase 9 exact immutable parent identity drift", call. = FALSE)
  assign("phase09_parent", facts, .phase10_cache)
  facts
}

.phase10_validate_model_registry <- function(data) {
  expected <- .canonical_phase10_model_registry()
  if (!identical(names(data), names(expected))) stop("Model registry Phase 10 schema drift", call. = FALSE)
  settings_fields <- c(
    "candidate_id", "adapter_id", "adapter_version", "mean_model_id", "dependence_id",
    "tuning_protocol_id", "feature_set_id", "score_support_max", "settings"
  )
  .phase10_validate_hash(data, "settings_sha256", "Model registry", settings_fields)
  .phase10_validate_hash(data, "registration_sha256", "Model registry")
  .phase10_assert_exact(data, expected, "Model registry")
}

.phase10_validate_feature_contract <- function(data) {
  expected <- .canonical_phase10_feature_contract()
  if (!identical(names(data), names(expected))) stop("Feature contract Phase 10 schema drift", call. = FALSE)
  .phase10_validate_hash(data, "row_sha256", "Feature contract")
  .phase10_assert_exact(data, expected, "Feature contract")
}

.phase10_validate_tuning_grid <- function(data) {
  expected <- canonical_phase10_tuning_grid()
  if (!identical(names(data), names(expected))) stop("Tuning grid Phase 10 schema drift", call. = FALSE)
  settings_fields <- setdiff(names(data), c("settings_sha256", "row_sha256"))
  .phase10_validate_hash(data, "settings_sha256", "Tuning grid", settings_fields)
  .phase10_validate_hash(data, "row_sha256", "Tuning grid")
  .phase10_assert_exact(data, expected, "Tuning grid")
}

.phase10_validate_tuning_relations <- function(data) {
  expected <- canonical_phase10_tuning_relations()
  if (!identical(names(data), names(expected))) stop("Tuning relation Phase 10 schema drift", call. = FALSE)
  .phase10_validate_hash(data, "relation_sha256", "Tuning relation")
  .phase10_assert_exact(data, expected, "Tuning relation")
}

.phase10_validate_task1_files <- function(protocol_dir = "data/benchmark/phase10") {
  files <- c(
    model_registry = "model_registry.csv", feature_contract = "feature_contract.csv",
    tuning_editions = "tuning_editions.csv", tuning_grid = "tuning_grid.csv"
  )
  tables <- lapply(file.path(protocol_dir, files), .phase10_read_csv)
  names(tables) <- names(files)
  .phase10_validate_model_registry(tables$model_registry)
  .phase10_validate_feature_contract(tables$feature_contract)
  .phase10_validate_tuning_relations(tables$tuning_editions)
  .phase10_validate_tuning_grid(tables$tuning_grid)
  c(list(valid = TRUE), tables)
}

.phase10_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

.write_phase10_task1_protocol <- function(protocol_dir = "data/benchmark/phase10") {
  .phase10_write_csv(.canonical_phase10_model_registry(), file.path(protocol_dir, "model_registry.csv"))
  .phase10_write_csv(.canonical_phase10_feature_contract(), file.path(protocol_dir, "feature_contract.csv"))
  .phase10_write_csv(canonical_phase10_tuning_relations(), file.path(protocol_dir, "tuning_editions.csv"))
  .phase10_write_csv(canonical_phase10_tuning_grid(), file.path(protocol_dir, "tuning_grid.csv"))
  .phase10_validate_task1_files(protocol_dir)
}

.phase10_zero_coverage_facts <- function() {
  cache_key <- "zero_coverage_facts"
  if (exists(cache_key, .phase10_cache, inherits = FALSE)) return(get(cache_key, .phase10_cache))
  path <- .phase10_project_path(
    "outputs", "benchmarks", "rolling_tournaments", "phase09-baselines-frozen",
    "manifests", "feature_coverage.csv"
  )
  coverage <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  features <- c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
  rows <- coverage[coverage$panel_id == "open_core" & coverage$feature_id %in% features, , drop = FALSE]
  expected_rows <- 4L * 5040L
  if (nrow(rows) != expected_rows || !setequal(rows$feature_id, features) ||
      any(as.logical(rows$source_present)) || any(as.logical(rows$value_present)) ||
      any(!as.logical(rows$imputed)) || any(as.logical(rows$active_in_fit)) ||
      any(rows$imputation_reason != "missing_source_row")) {
    stop("Phase 10 ablation zero-coverage parent evidence drift", call. = FALSE)
  }
  facts <- list(
    valid = TRUE,
    rows = nrow(rows),
    rows_per_feature = as.integer(table(factor(rows$feature_id, levels = features))),
    sha256 = .phase10_sha256(path, file = TRUE)
  )
  expected_sha <- "07ff58a4c559ddd04ee873e911efbd7014bdae9b4417e3f6db4a21d3d99c9f29"
  if (!identical(facts$sha256, expected_sha)) {
    stop("Phase 10 ablation coverage artifact SHA-256 drift", call. = FALSE)
  }
  assign(cache_key, facts, .phase10_cache)
  facts
}

.canonical_phase10_ablation_registry <- function() {
  evidence <- .phase10_zero_coverage_facts()
  registry <- data.frame(
    schema_version = rep("1.0", 6L),
    node_order = as.character(1:6),
    ablation_id = c(
      "open_nb_incumbent", "open_nb_elo_only_ablation", "attack_xg",
      "defence_xg", "xgd", "form"
    ),
    parent_candidate_id = c("", rep("open_nb_incumbent", 5L)),
    feature_block_id = c("full_incumbent", "elo_only", "attack_xg", "defence_xg", "xgd", "form"),
    retained_features = c(
      "elo_diff|xgf_ewma_diff|xga_ewma_diff|xgd_ewma_diff|form_index_diff",
      "elo_diff", "elo_diff|xga_ewma_diff|xgd_ewma_diff|form_index_diff",
      "elo_diff|xgf_ewma_diff|xgd_ewma_diff|form_index_diff",
      "elo_diff|xgf_ewma_diff|xga_ewma_diff|form_index_diff",
      "elo_diff|xgf_ewma_diff|xga_ewma_diff|xgd_ewma_diff"
    ),
    removed_features = c("", "xgf_ewma_diff|xga_ewma_diff|xgd_ewma_diff|form_index_diff", "xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff"),
    activation_status = c("reference_parent", "scored", rep("not_activated_zero_coverage", 4L)),
    activation_reason = c(
      "phase09_registered_full_incumbent", "registered_level_one_ablation",
      rep("phase09_open_core_source_and_value_coverage_zero", 4L)
    ),
    source_present = c("false", "false", rep("false", 4L)),
    value_present = c("false", "false", rep("false", 4L)),
    imputed = c("true", "true", rep("true", 4L)),
    active_in_fit = c("true", "true", rep("false", 4L)),
    complexity_rank = c("5", "1", "4", "4", "4", "4"),
    coverage_evidence_rows = rep(as.character(evidence$rows), 6L),
    coverage_evidence_sha256 = rep(evidence$sha256, 6L),
    settings_sha256 = "",
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  settings_fields <- setdiff(names(registry), c("settings_sha256", "row_sha256"))
  registry$settings_sha256 <- .phase10_subset_sha256(registry, settings_fields)
  registry$row_sha256 <- .phase10_row_sha256(registry, "row_sha256")
  registry
}

.phase10_sort_json <- function(value) {
  if (!is.list(value)) return(value)
  named <- !is.null(names(value)) && length(names(value)) && all(nzchar(names(value)))
  if (named) value <- value[sort(names(value), method = "radix")]
  lapply(value, .phase10_sort_json)
}

.phase10_canonical_json <- function(protocol) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required for Phase 10 selection protocol validation", call. = FALSE)
  }
  protocol$protocol_sha256 <- NULL
  as.character(jsonlite::toJSON(
    .phase10_sort_json(protocol), auto_unbox = TRUE, null = "null", na = "null",
    digits = 17, pretty = FALSE, force = TRUE
  ))
}

.phase10_protocol_sha256 <- function(protocol) .phase10_sha256(.phase10_canonical_json(protocol))

#' Build the canonical research-only Phase 10 selection protocol
#'
#' @return Nested list with exact rules and self-checksum.
#' @export
canonical_phase10_selection_protocol <- function() {
  protocol <- list(
    schema_version = "1.0",
    protocol_version = "phase10-d11-d16-v1",
    protocol_sha256 = "",
    primary_metric = list(
      id = "tournament_weighted_rps", direction = "lower",
      delta_direction = "challenger_minus_reference", primary_track = "updating"
    ),
    thresholds = list(
      dependence_meaningful_rps_delta = list(operator = "<=", value = -0.001),
      practical_tie = list(operator = "abs<=", value = 0.0005),
      simpler_noninferiority = list(operator = "<=", value = 0.001),
      brier_relative = list(operator = "<=", value = 0.01),
      log_relative = list(operator = "<=", value = 0.01),
      calibration = list(operator = "<=", value = 0.01),
      maximum_fold_regression = list(operator = "<=", value = 0.015),
      fold_wins = list(operator = ">=", value = 8L),
      world_cup_wins = list(operator = ">=", value = 2L),
      euro_wins = list(operator = ">=", value = 2L)
    ),
    fold_breadth = list(
      development_editions = as.list(phase10_protocol_constants()$outer_edition_ids),
      edition_count = 12L, world_cup_count = 6L, euro_count = 6L,
      tournament_weighting = "equal", ties_count_as_wins = FALSE
    ),
    shortlist = list(
      slots = as.list(c("best_proper_score", "simplest_non_inferior", "dependence_representative")),
      non_exclusive = TRUE,
      best_proper_score_rule = "lowest_valid_tournament_weighted_updating_rps",
      simplest_rule = "lowest_complexity_rank_within_noninferiority_and_without_veto",
      dependence_rule = "best_valid_dependence_rps_with_dixon_coles_practical_tie_preference"
    ),
    supporting_vetoes = as.list(c("brier_relative", "log_relative", "calibration", "maximum_fold_regression")),
    dependence = list(
      shared_mean_parent = "poisson_team_ridge_elo",
      ordered_candidates = as.list(c("poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois")),
      practical_tie_preference = "poisson_team_ridge_elo_dc",
      no_meaningful_gain_preference = "poisson_team_ridge_elo"
    ),
    ablation = list(
      root = "open_nb_incumbent", scored_child = "open_nb_elo_only_ablation",
      inactive_children = as.list(c("attack_xg", "defence_xg", "xgd", "form")),
      inactive_reason = "phase09_open_core_source_and_value_coverage_zero"
    ),
    governance = list(
      scope = "research_shortlist_only", decision_authority = "phase12",
      downstream_decision_surface = "absent", evaluator_callback = "unreachable"
    ),
    source_paths = as.list(c(
      "data/benchmark/phase10/model_registry.csv",
      "data/benchmark/phase10/ablation_registry.csv",
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/scores/benchmark_summaries.csv"
    ))
  )
  protocol$protocol_sha256 <- .phase10_protocol_sha256(protocol)
  protocol
}

.phase10_recursive_strings <- function(value, prefix = "") {
  results <- character()
  if (!is.null(names(value))) {
    keys <- names(value)
    results <- c(results, paste0(prefix, keys))
  }
  if (is.list(value)) {
    for (index in seq_along(value)) {
      name <- if (!is.null(names(value)) && nzchar(names(value)[index])) names(value)[index] else as.character(index)
      results <- c(results, .phase10_recursive_strings(value[[index]], paste0(prefix, name, ".")))
    }
  } else if (is.character(value)) {
    results <- c(results, value)
  }
  results
}

.phase10_validate_no_decision_surface <- function(protocol) {
  values <- tolower(.phase10_recursive_strings(protocol))
  forbidden <- "promot|release|final[_ .-]?holdout|eligible[_ .-]?for[_ .-]?final|wc.?2026|world cup 2026"
  bad <- values[grepl(forbidden, values, perl = TRUE)]
  if (length(bad)) stop("Phase 10 selection protocol contains forbidden decision surface: ", bad[1], call. = FALSE)
  invisible(TRUE)
}

.phase10_threshold_vector <- function(protocol) {
  rules <- protocol$thresholds
  values <- c(
    dependence_rps_gain = rules$dependence_meaningful_rps_delta$value,
    practical_tie = rules$practical_tie$value,
    simpler_noninferiority = rules$simpler_noninferiority$value,
    brier_relative = rules$brier_relative$value,
    log_relative = rules$log_relative$value,
    calibration = rules$calibration$value,
    maximum_fold_regression = rules$maximum_fold_regression$value,
    fold_wins = rules$fold_wins$value,
    world_cup_wins = rules$world_cup_wins$value,
    euro_wins = rules$euro_wins$value
  )
  as.numeric(values) |> stats::setNames(names(values))
}

.phase10_validate_selection_protocol <- function(protocol) {
  if (!is.list(protocol)) stop("Phase 10 selection protocol must be a JSON object", call. = FALSE)
  .phase10_validate_no_decision_surface(protocol)
  actual_hash <- tolower(as.character(protocol$protocol_sha256))
  if (length(actual_hash) != 1L || !grepl("^[0-9a-f]{64}$", actual_hash) ||
      !identical(actual_hash, .phase10_protocol_sha256(protocol))) {
    stop("Phase 10 selection protocol SHA-256 mismatch", call. = FALSE)
  }
  expected <- canonical_phase10_selection_protocol()
  if (!identical(.phase10_canonical_json(protocol), .phase10_canonical_json(expected))) {
    stop("Phase 10 selection protocol canonical content or order drift", call. = FALSE)
  }
  slots <- unname(unlist(protocol$shortlist$slots, use.names = FALSE))
  if (!identical(slots, c("best_proper_score", "simplest_non_inferior", "dependence_representative"))) {
    stop("Phase 10 shortlist order drift", call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_validate_ablation_registry <- function(data) {
  expected <- .canonical_phase10_ablation_registry()
  if (!identical(names(data), names(expected))) stop("Ablation registry Phase 10 schema drift", call. = FALSE)
  settings_fields <- setdiff(names(data), c("settings_sha256", "row_sha256"))
  .phase10_validate_hash(data, "settings_sha256", "Ablation registry", settings_fields)
  .phase10_validate_hash(data, "row_sha256", "Ablation registry")
  if (anyDuplicated(data$ablation_id)) stop("Ablation registry Phase 10 duplicate node", call. = FALSE)
  for (node in data$ablation_id) {
    seen <- character()
    current <- node
    repeat {
      parent <- data$parent_candidate_id[match(current, data$ablation_id)]
      if (!length(parent) || is.na(parent) || !nzchar(parent) || !parent %in% data$ablation_id) break
      if (parent %in% seen || identical(parent, node)) stop("Ablation registry Phase 10 graph cycle", call. = FALSE)
      seen <- c(seen, parent)
      current <- parent
    }
  }
  .phase10_assert_exact(data, expected, "Ablation registry")
}

.phase10_storage_columns <- function() {
  c(
    "schema_version", "pilot_format", "fixture_count", "track_count", "distribution_count",
    "support_max", "rows_per_distribution", "pilot_row_count", "compressed_bytes",
    "score_projection_factor", "score_projection", "headroom_fraction", "headroom_floor_bytes",
    "one_bundle_projection", "bundle_copy_count", "filesystem_headroom_multiplier",
    "minimum_free_bytes", "worker_ceiling", "measured_available_bytes", "schema_sha256",
    "generator_sha256", "content_sha256", "deterministic_replay_sha256",
    "cardinality_valid", "formula_valid", "free_space_pass", "row_sha256"
  )
}

.phase10_storage_schema_sha256 <- function() {
  schema <- paste(c(
    "score_distribution_id:character", "home_goals:integer", "away_goals:integer",
    "probability:numeric", "support_max_home:integer", "support_max_away:integer",
    "raw_tail_mass:numeric", "normalized:logical"
  ), collapse = "|")
  .phase10_sha256(schema)
}

.phase10_storage_generator_sha256 <- function() {
  .phase10_sha256(paste(c(
    "phase10-storage-pilot-v1", "seed=1009001", "fixtures=630", "tracks=frozen|updating",
    "support=0:40x0:40", "raw=runif-normalized-per-distribution", "csv=write.table-quote",
    "gzip=level9", "ids=sha256(seed|track|fixture)"
  ), collapse = "|"))
}

.phase10_available_bytes <- function(path = ".") {
  output <- suppressWarnings(system2("df", c("-Pk", normalizePath(path, mustWork = TRUE)), stdout = TRUE, stderr = TRUE))
  if (length(output) < 2L) stop("Phase 10 storage preflight could not measure free space", call. = FALSE)
  fields <- strsplit(trimws(output[length(output)]), "[[:space:]]+")[[1]]
  kilobytes <- suppressWarnings(as.numeric(fields[4]))
  if (!is.finite(kilobytes) || kilobytes < 0) stop("Phase 10 storage preflight free-space result is invalid", call. = FALSE)
  kilobytes * 1024
}

.phase10_write_storage_pilot <- function(path) {
  set.seed(1009001L)
  connection <- gzfile(path, open = "wb", compression = 9)
  on.exit(close(connection), add = TRUE)
  tracks <- c("frozen", "updating")
  grid <- expand.grid(home_goals = 0:40, away_goals = 0:40)
  first <- TRUE
  for (track in tracks) {
    for (fixture in seq_len(630L)) {
      raw <- stats::runif(nrow(grid), min = 1e-9, max = 1)
      id <- paste0(
        "phase10_storage_pilot__", track, "__",
        .phase10_sha256(paste(1009001L, track, fixture, sep = "|")), "__score"
      )
      rows <- data.frame(
        score_distribution_id = id,
        home_goals = grid$home_goals,
        away_goals = grid$away_goals,
        probability = raw / sum(raw),
        support_max_home = 40L,
        support_max_away = 40L,
        raw_tail_mass = (fixture %% 17L + 1L) * 1e-12,
        normalized = TRUE,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      utils::write.table(
        rows, connection, sep = ",", row.names = FALSE, col.names = first,
        append = !first, na = "", quote = TRUE, qmethod = "double"
      )
      first <- FALSE
    }
  }
  invisible(path)
}

#' Measure the exact deterministic G=40 Phase 10 storage partition
#'
#' @param output_path Optional durable storage-preflight CSV path.
#' @return One-row all-character preflight record.
#' @export
measure_challenger_partition_storage <- function(
    output_path = NULL
) {
  first <- tempfile("phase10-storage-pilot-", fileext = ".csv.gz")
  second <- tempfile("phase10-storage-replay-", fileext = ".csv.gz")
  on.exit(unlink(c(first, second), force = TRUE), add = TRUE)
  .phase10_write_storage_pilot(first)
  .phase10_write_storage_pilot(second)
  first_hash <- .phase10_sha256(first, file = TRUE)
  second_hash <- .phase10_sha256(second, file = TRUE)
  first_bytes <- as.numeric(file.info(first)$size)
  second_bytes <- as.numeric(file.info(second)$size)
  if (!identical(first_hash, second_hash) || !identical(first_bytes, second_bytes)) {
    stop("Phase 10 storage pilot is not byte-deterministic", call. = FALSE)
  }
  score_projection <- 7 * first_bytes
  one_bundle <- score_projection + max(1024^3, ceiling(0.25 * score_projection))
  minimum_free <- ceiling(3 * one_bundle * 1.10)
  available <- .phase10_available_bytes(.phase10_project_root("."))
  record <- data.frame(
    schema_version = "1.0",
    pilot_format = "production_score_distributions_csv_gzip_level9",
    fixture_count = "630",
    track_count = "2",
    distribution_count = "1260",
    support_max = "40",
    rows_per_distribution = "1681",
    pilot_row_count = "2118060",
    compressed_bytes = format(first_bytes, scientific = FALSE, trim = TRUE),
    score_projection_factor = "7",
    score_projection = format(score_projection, scientific = FALSE, trim = TRUE),
    headroom_fraction = "0.25",
    headroom_floor_bytes = format(1024^3, scientific = FALSE, trim = TRUE),
    one_bundle_projection = format(one_bundle, scientific = FALSE, trim = TRUE),
    bundle_copy_count = "3",
    filesystem_headroom_multiplier = "1.10",
    minimum_free_bytes = format(minimum_free, scientific = FALSE, trim = TRUE),
    worker_ceiling = "2",
    measured_available_bytes = format(available, scientific = FALSE, trim = TRUE),
    schema_sha256 = .phase10_storage_schema_sha256(),
    generator_sha256 = .phase10_storage_generator_sha256(),
    content_sha256 = first_hash,
    deterministic_replay_sha256 = second_hash,
    cardinality_valid = "true",
    formula_valid = "true",
    free_space_pass = if (available >= minimum_free) "true" else "false",
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  record$row_sha256 <- .phase10_row_sha256(record, "row_sha256")
  if (!is.null(output_path)) .phase10_write_csv(record, output_path)
  record
}

#' Validate the measured storage record and current free-space hard gate
#'
#' @param storage One-row preflight data frame.
#' @return `TRUE`, invisibly, or an error.
#' @export
validate_challenger_storage_preflight <- function(storage) {
  if (!is.data.frame(storage) || nrow(storage) != 1L || !identical(names(storage), .phase10_storage_columns())) {
    stop("Phase 10 storage preflight schema or row drift", call. = FALSE)
  }
  storage[] <- lapply(storage, .phase10_scalar)
  .phase10_validate_hash(storage, "row_sha256", "Storage preflight")
  number <- function(field) suppressWarnings(as.numeric(storage[[field]]))
  fixture_count <- number("fixture_count")
  track_count <- number("track_count")
  support_max <- number("support_max")
  distributions <- number("distribution_count")
  rows_per <- number("rows_per_distribution")
  pilot_rows <- number("pilot_row_count")
  bytes <- number("compressed_bytes")
  score_projection <- number("score_projection")
  one_bundle <- number("one_bundle_projection")
  minimum_free <- number("minimum_free_bytes")
  cardinality_valid <- identical(distributions, fixture_count * track_count) &&
    identical(rows_per, (support_max + 1)^2) && identical(pilot_rows, distributions * rows_per) &&
    identical(pilot_rows, 2118060)
  expected_score <- 7 * bytes
  expected_bundle <- expected_score + max(1024^3, ceiling(0.25 * expected_score))
  expected_minimum <- ceiling(3 * expected_bundle * 1.10)
  formula_valid <- identical(number("score_projection_factor"), 7) &&
    identical(score_projection, expected_score) && identical(number("headroom_fraction"), 0.25) &&
    identical(number("headroom_floor_bytes"), 1024^3) && identical(one_bundle, expected_bundle) &&
    identical(number("bundle_copy_count"), 3) &&
    identical(number("filesystem_headroom_multiplier"), 1.10) &&
    identical(minimum_free, expected_minimum) && identical(number("worker_ceiling"), 2)
  constants <- phase10_protocol_constants()
  hashes_valid <- identical(storage$schema_sha256, .phase10_storage_schema_sha256()) &&
    identical(storage$generator_sha256, .phase10_storage_generator_sha256()) &&
    identical(storage$content_sha256, storage$deterministic_replay_sha256) &&
    identical(storage$content_sha256, constants$storage_pilot_content_sha256) &&
    identical(bytes, constants$storage_pilot_compressed_bytes) &&
    identical(number("measured_available_bytes"), constants$storage_pilot_available_bytes)
  current_available <- .phase10_available_bytes(.phase10_project_root("."))
  current_pass <- current_available >= minimum_free
  if (!cardinality_valid || !formula_valid || !hashes_valid ||
      !identical(storage$cardinality_valid, "true") || !identical(storage$formula_valid, "true") ||
      !identical(storage$free_space_pass, "true") || !isTRUE(current_pass)) {
    stop("Phase 10 storage cardinality, hash, projection formula, or free-space gate failed", call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_validate_task2_files <- function(protocol_dir = "data/benchmark/phase10") {
  ablation <- .phase10_read_csv(file.path(protocol_dir, "ablation_registry.csv"))
  selection_path <- file.path(protocol_dir, "selection_protocol.json")
  if (!file.exists(selection_path)) stop("Phase 10 protocol file is missing: selection_protocol.json", call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Phase 10 protocol", call. = FALSE)
  selection <- jsonlite::read_json(selection_path, simplifyVector = FALSE)
  storage <- .phase10_read_csv(file.path(protocol_dir, "storage_preflight.csv"))
  .phase10_validate_ablation_registry(ablation)
  .phase10_validate_selection_protocol(selection)
  validate_challenger_storage_preflight(storage)
  list(valid = TRUE, ablation_registry = ablation, selection = selection, storage = storage)
}

.phase10_write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE, digits = 17, null = "null")
  invisible(path)
}

.write_phase10_task2_protocol <- function(protocol_dir = "data/benchmark/phase10", storage = NULL) {
  .phase10_write_csv(.canonical_phase10_ablation_registry(), file.path(protocol_dir, "ablation_registry.csv"))
  .phase10_write_json(canonical_phase10_selection_protocol(), file.path(protocol_dir, "selection_protocol.json"))
  if (!is.null(storage)) .phase10_write_csv(storage, file.path(protocol_dir, "storage_preflight.csv"))
  invisible(TRUE)
}

#' Load and validate the complete Phase 10 challenger protocol
#'
#' @param protocol_dir Directory containing all canonical Phase 10 artifacts.
#' @param validate_parent Reconstruct the immutable Phase 9 parent; false is for isolated mutation tests only.
#' @return Validated protocol facts for later adapters and runners.
#' @export
load_and_validate_challenger_protocol <- function(
    protocol_dir = "data/benchmark/phase10", validate_parent = TRUE
) {
  task1 <- .phase10_validate_task1_files(protocol_dir)
  task2 <- .phase10_validate_task2_files(protocol_dir)
  parent <- if (isTRUE(validate_parent)) validate_phase09_parent_identity() else NULL
  slots <- unname(unlist(task2$selection$shortlist$slots, use.names = FALSE))
  list(
    valid = TRUE,
    parent = parent,
    model_registry = task1$model_registry,
    feature_contract = task1$feature_contract,
    tuning_editions = task1$tuning_editions,
    tuning_grid = task1$tuning_grid,
    ablation_registry = task2$ablation_registry,
    selection = task2$selection,
    storage = task2$storage,
    shortlist_slots = slots,
    thresholds = .phase10_threshold_vector(task2$selection)
  )
}

#' Execute the read-only four-edition pre-2002 numerical grid diagnostic
#'
#' @return Diagnostic facts including immutable before/after grid hashes.
#' @export
run_pre2002_grid_diagnostic <- function() {
  validate_phase09_parent_identity()
  protocol_dir <- .phase10_project_path("data", "benchmark", "phase10")
  validated <- .phase10_validate_task1_files(protocol_dir)
  before <- .phase10_canonical_table_sha256(validated$tuning_grid)
  constants <- phase10_protocol_constants()
  history <- utils::read.csv(
    .phase10_project_path("data", "processed", "elo_matches.csv"),
    stringsAsFactors = FALSE, check.names = FALSE,
    nrows = constants$pre2002_history_rows
  )
  history$date <- as.Date(history$date)
  if (nrow(history) != constants$pre2002_history_rows || any(history$date >= as.Date("2002-01-01"))) {
    stop("Pre-2002 diagnostic history boundary drift", call. = FALSE)
  }
  catalog <- .phase10_edition_catalog()
  diagnostic <- catalog[catalog$edition_id %in% constants$pre2002_edition_ids, , drop = FALSE]
  rows <- do.call(rbind, lapply(seq_len(nrow(diagnostic)), function(index) {
    history[
      history$tournament == diagnostic$competition[index] &
        history$date >= as.Date(diagnostic$opener_date[index]) &
        history$date <= as.Date(diagnostic$final_date[index]),
      , drop = FALSE
    ]
  }))
  if (!all(is.finite(rows$home_score)) || !all(is.finite(rows$away_score))) {
    stop("Pre-2002 diagnostic contains nonfinite goals", call. = FALSE)
  }
  mu_home <- pmax(0.05, ave(rows$home_score, rows$tournament, FUN = mean))
  mu_away <- pmax(0.05, ave(rows$away_score, rows$tournament, FUN = mean))
  epsilon <- 1e-8
  rho_lower <- max(c(-1 / mu_home, -1 / mu_away)) + epsilon
  rho_upper <- min(c(1 / (mu_home * mu_away), 1)) - epsilon
  grid <- validated$tuning_grid
  finite_reach <- vapply(seq_len(nrow(grid)), function(index) {
    id <- grid$parameter_id[index]
    if (id == "dixon_coles_rho") return(is.finite(rho_lower) && is.finite(rho_upper) && rho_lower < rho_upper)
    if (id == "bivariate_q") return(0 >= 0 && 0 < 0.95 && is.finite(0.95))
    value <- suppressWarnings(as.numeric(grid$parameter_value[index]))
    is.finite(value) && value > 0
  }, logical(1))
  after_tables <- .phase10_validate_task1_files(protocol_dir)
  after <- .phase10_canonical_table_sha256(after_tables$tuning_grid)
  list(
    valid = all(finite_reach) && identical(before, after),
    edition_ids = constants$pre2002_edition_ids,
    max_evidence_date = max(rows$date),
    assessment_rows_absent = all(rows$date < as.Date("2002-01-01")),
    finite_reach = finite_reach,
    dixon_coles_interval = c(lower = rho_lower, upper = rho_upper),
    grid_sha256_before = before,
    grid_sha256_after = after
  )
}
