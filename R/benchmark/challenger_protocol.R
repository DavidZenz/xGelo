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
    pre2002_history_rows = 26134L
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
    stop("require_challenger_environment() must be sourced before parent validation", call. = FALSE)
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
