#' Phase 11 registered random-forest goal-mean challenger

.hybrid_rf_root <- function(path = ".") {
  if (exists(".phase11_protocol_root", mode = "function")) {
    return(.phase11_protocol_root(path))
  }
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

.hybrid_rf_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- file.path(.hybrid_rf_root("."), relative_path)
  if (!file.exists(path)) stop("Phase 11 RF dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing_after <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing_after)) {
    stop("Phase 11 RF dependency did not define: ", paste(missing_after, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

hybrid_rf_feature_ids <- function() {
  c(
    "home_attack_effect", "home_defence_effect",
    "away_attack_effect", "away_defence_effect", "elo_diff"
  )
}

.hybrid_rf_registration_row <- function(registration = NULL, candidate_id = "phase11_rf_dynamic_elo_open") {
  .hybrid_rf_source_if_missing(
    "R/benchmark/hybrid_protocol.R",
    c("canonical_phase11_model_registry", "hybrid_registration")
  )
  if (is.null(registration)) registration <- canonical_phase11_model_registry()
  if (inherits(registration, "validated_hybrid_protocol")) {
    registration <- hybrid_registration(registration, candidate_id)
  }
  if (!is.data.frame(registration) || nrow(registration) != 1L) {
    stop("RF registration must contain exactly one model row", call. = FALSE)
  }
  if (!identical(as.character(registration$candidate_id[[1L]]), as.character(candidate_id))) {
    stop("RF registration candidate_id does not match the requested candidate", call. = FALSE)
  }
  registration
}

hybrid_rf_registered_setting_identity <- function(registration = NULL) {
  registration <- .hybrid_rf_registration_row(registration)
  if (exists("validate_hybrid_model_registry", mode = "function")) {
    validate_hybrid_model_registry(registration)
  }
  fields <- if (exists(".phase11_model_settings_fields", mode = "function")) {
    .phase11_model_settings_fields()
  } else {
    c(
      "candidate_id", "adapter_id", "adapter_version", "mean_model_id", "dependence_id",
      "tuning_protocol_id", "feature_set_id", "rf_feature_set_id", "score_support_max",
      "settings", "num.trees", "mtry", "min.node.size", "seed_policy", "seed_id",
      "home_away_tuning_relationship", "nb_dispersion_source", "home_theta", "away_theta",
      "ranger_package", "ranger_version", "ranger_provenance_id"
    )
  }
  missing <- setdiff(fields, names(registration))
  if (length(missing)) stop("RF registration is missing settings fields: ", paste(missing, collapse = ", "), call. = FALSE)
  settings_hash <- if (exists(".phase11_model_settings_sha256", mode = "function")) {
    .phase11_model_settings_sha256(registration)
  } else {
    digest::digest(
      paste(vapply(registration[1L, fields, drop = FALSE], as.character, character(1)), collapse = "|"),
      algo = "sha256", serialize = FALSE
    )
  }
  registration_hash <- if (exists(".phase11_row_sha256", mode = "function")) {
    .phase11_row_sha256(registration, "registration_sha256")[[1L]]
  } else {
    digest::digest(
      paste(vapply(registration[1L, setdiff(names(registration), "registration_sha256"), drop = FALSE], as.character, character(1)), collapse = "|"),
      algo = "sha256", serialize = FALSE
    )
  }
  list(
    candidate_id = as.character(registration$candidate_id[[1L]]),
    settings_sha256 = settings_hash,
    registration_sha256 = registration_hash,
    num.trees = as.integer(registration$`num.trees`[[1L]]),
    mtry = as.integer(registration$mtry[[1L]]),
    min.node.size = as.integer(registration$`min.node.size`[[1L]]),
    seed_policy = as.character(registration$seed_policy[[1L]]),
    seed_id = as.character(registration$seed_id[[1L]]),
    feature_set_id = as.character(registration$feature_set_id[[1L]]),
    rf_feature_set_id = as.character(registration$rf_feature_set_id[[1L]]),
    score_support_max = as.integer(registration$score_support_max[[1L]]),
    home_theta = as.numeric(registration$home_theta[[1L]]),
    away_theta = as.numeric(registration$away_theta[[1L]]),
    home_away_tuning_relationship = as.character(registration$home_away_tuning_relationship[[1L]]),
    nb_dispersion_source = as.character(registration$nb_dispersion_source[[1L]]),
    ranger_package = as.character(registration$ranger_package[[1L]]),
    ranger_version = as.character(registration$ranger_version[[1L]]),
    ranger_provenance_id = as.character(registration$ranger_provenance_id[[1L]])
  )
}

hybrid_rf_settings_sha256 <- function(registration = NULL) {
  hybrid_rf_registered_setting_identity(registration)$settings_sha256
}

.hybrid_rf_setting_value <- function(settings, names, default) {
  found <- intersect(names, names(settings))
  if (!length(found)) return(list(value = default, explicit = FALSE))
  value <- settings[[found[[1L]]]]
  if (length(value) != 1L || is.na(value)) stop("RF setting must be one non-missing value: ", found[[1L]], call. = FALSE)
  list(value = value, explicit = TRUE)
}

.hybrid_rf_compare_setting <- function(value, expected, label, numeric = FALSE) {
  same <- if (isTRUE(numeric)) {
    isTRUE(all.equal(as.numeric(value), as.numeric(expected), tolerance = 0, check.attributes = FALSE))
  } else {
    identical(as.character(value), as.character(expected))
  }
  if (!same) stop("RF setting is not registered for this candidate: ", label, call. = FALSE)
  invisible(TRUE)
}

#' Resolve only the immutable RF settings registered for the candidate.
#'
#' Explicit runtime overrides are rejected when they differ from the registry;
#' this prevents a fit from silently using a different tuning or NB contract.
#' @export
hybrid_rf_registered_settings <- function(settings = list(), registration = NULL, candidate_id = "phase11_rf_dynamic_elo_open") {
  if (is.null(settings)) settings <- list()
  if (!is.list(settings)) stop("RF settings must be a named list", call. = FALSE)
  if (length(settings) && (is.null(names(settings)) || any(!nzchar(names(settings))))) {
    stop("RF settings must have names", call. = FALSE)
  }
  registration <- .hybrid_rf_registration_row(registration, candidate_id)
  identity <- hybrid_rf_registered_setting_identity(registration)

  support <- .hybrid_rf_setting_value(settings, c("support_max", "score_support_max"), identity$score_support_max)
  feature_set <- .hybrid_rf_setting_value(settings, c("feature_set_id", "rf_feature_set_id"), identity$feature_set_id)
  trees <- .hybrid_rf_setting_value(settings, c("num.trees", "num_trees"), identity$`num.trees`)
  mtry <- .hybrid_rf_setting_value(settings, c("mtry"), identity$mtry)
  node_size <- .hybrid_rf_setting_value(settings, c("min.node.size", "min_node_size"), identity$`min.node.size`)
  seed <- .hybrid_rf_setting_value(settings, c("seed", "seed_id"), as.integer(identity$seed_id))
  home_theta <- .hybrid_rf_setting_value(settings, c("home_theta"), identity$home_theta)
  away_theta <- .hybrid_rf_setting_value(settings, c("away_theta"), identity$away_theta)
  seed_policy <- .hybrid_rf_setting_value(settings, c("seed_policy"), identity$seed_policy)
  relationship <- .hybrid_rf_setting_value(
    settings, c("home_away_tuning_relationship"), identity$home_away_tuning_relationship
  )
  dispersion_source <- .hybrid_rf_setting_value(
    settings, c("nb_dispersion_source"), identity$nb_dispersion_source
  )
  ranger_version <- .hybrid_rf_setting_value(settings, c("ranger_version"), identity$ranger_version)
  ranger_provenance_id <- .hybrid_rf_setting_value(
    settings, c("ranger_provenance_id"), identity$ranger_provenance_id
  )

  if (support$explicit) .hybrid_rf_compare_setting(support$value, identity$score_support_max, "score_support_max", TRUE)
  if (feature_set$explicit) .hybrid_rf_compare_setting(feature_set$value, identity$feature_set_id)
  if (trees$explicit) .hybrid_rf_compare_setting(trees$value, identity$`num.trees`, "num.trees", TRUE)
  if (mtry$explicit) .hybrid_rf_compare_setting(mtry$value, identity$mtry, "mtry", TRUE)
  if (node_size$explicit) .hybrid_rf_compare_setting(node_size$value, identity$`min.node.size`, "min.node.size", TRUE)
  if (seed$explicit) .hybrid_rf_compare_setting(seed$value, as.integer(identity$seed_id), "seed_id", TRUE)
  if (home_theta$explicit) .hybrid_rf_compare_setting(home_theta$value, identity$home_theta, "home_theta", TRUE)
  if (away_theta$explicit) .hybrid_rf_compare_setting(away_theta$value, identity$away_theta, "away_theta", TRUE)
  if (seed_policy$explicit) .hybrid_rf_compare_setting(seed_policy$value, identity$seed_policy, "seed_policy")
  if (relationship$explicit) .hybrid_rf_compare_setting(relationship$value, identity$home_away_tuning_relationship, "home_away_tuning_relationship")
  if (dispersion_source$explicit) .hybrid_rf_compare_setting(dispersion_source$value, identity$nb_dispersion_source, "nb_dispersion_source")
  if (ranger_version$explicit) .hybrid_rf_compare_setting(ranger_version$value, identity$ranger_version, "ranger_version")
  if (ranger_provenance_id$explicit) .hybrid_rf_compare_setting(ranger_provenance_id$value, identity$ranger_provenance_id, "ranger_provenance_id")

  resolved <- list(
    candidate_id = identity$candidate_id,
    support_max = identity$score_support_max,
    num.trees = identity$`num.trees`,
    mtry = identity$mtry,
    min.node.size = identity$`min.node.size`,
    seed = as.integer(identity$seed_id),
    seed_id = identity$seed_id,
    seed_policy = identity$seed_policy,
    feature_set_id = identity$feature_set_id,
    rf_feature_set_id = identity$rf_feature_set_id,
    home_theta = identity$home_theta,
    away_theta = identity$away_theta,
    home_away_tuning_relationship = identity$home_away_tuning_relationship,
    nb_dispersion_source = identity$nb_dispersion_source,
    ranger_package = identity$ranger_package,
    ranger_version = identity$ranger_version,
    ranger_provenance_id = identity$ranger_provenance_id,
    registration_sha256 = identity$registration_sha256,
    settings_sha256 = identity$settings_sha256,
    provenance_path = if ("provenance_path" %in% names(settings)) {
      as.character(settings$provenance_path[[1L]])
    } else {
      "data/benchmark/phase11/ranger_provenance.csv"
    },
    distribution_id_prefix = if ("distribution_id_prefix" %in% names(settings)) {
      as.character(settings$distribution_id_prefix[[1L]])
    } else {
      identity$candidate_id
    }
  )
  if (!nzchar(resolved$provenance_path) || !nzchar(resolved$distribution_id_prefix)) {
    stop("RF provenance_path and distribution_id_prefix must be non-empty", call. = FALSE)
  }
  resolved
}

.hybrid_rf_date_column <- function(data, label) {
  candidates <- c("actual_completion_date", "date", "match_date", "result_date")
  available <- intersect(candidates, names(data))
  if (!length(available)) stop(label, " requires a registered chronology date column", call. = FALSE)
  available[[1L]]
}

.hybrid_rf_goal_columns <- function(data, label) {
  if (all(c("home_goals", "away_goals") %in% names(data))) {
    return(c(home = "home_goals", away = "away_goals"))
  }
  if (all(c("regulation_home_goals", "regulation_away_goals") %in% names(data))) {
    return(c(home = "regulation_home_goals", away = "regulation_away_goals"))
  }
  stop(label, " requires home_goals/away_goals responses", call. = FALSE)
}

.hybrid_rf_bool_vector <- function(value, label, n) {
  if (length(value) != n) stop(label, " has the wrong row count", call. = FALSE)
  if (is.logical(value)) result <- value else {
    normalized <- tolower(trimws(as.character(value)))
    result <- ifelse(normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA))
  }
  if (anyNA(result)) stop(label, " must contain only true/false values", call. = FALSE)
  result
}

#' Validate that every RF feature is point-in-time, present, and unimputed.
#' @export
hybrid_rf_validate_evidence <- function(data, cutoff, feature_ids = hybrid_rf_feature_ids(), label = "RF data") {
  if (!is.data.frame(data) || !nrow(data)) stop(label, " must contain rows", call. = FALSE)
  cutoff <- as.Date(cutoff)
  if (length(cutoff) == 1L) cutoff <- rep(cutoff, nrow(data))
  if (length(cutoff) != nrow(data) || anyNA(cutoff)) stop(label, " chronology cutoff is incomplete", call. = FALSE)
  missing_values <- setdiff(feature_ids, names(data))
  companion_suffixes <- c("__source_date", "__source_present", "__value_present", "__imputed", "__imputation_reason")
  missing_companions <- unlist(lapply(feature_ids, function(feature) {
    setdiff(paste0(feature, companion_suffixes), names(data))
  }), use.names = FALSE)
  if (length(missing_values) || length(missing_companions)) {
    stop(label, " is missing registered feature evidence: ", paste(c(missing_values, missing_companions), collapse = ", "), call. = FALSE)
  }
  for (feature in feature_ids) {
    values <- suppressWarnings(as.numeric(data[[feature]]))
    if (any(!is.finite(values))) stop(label, " contains non-finite ", feature, call. = FALSE)
    source_date <- as.Date(data[[paste0(feature, "__source_date")]])
    if (anyNA(source_date) || any(source_date >= cutoff)) {
      stop(label, " violates chronology for ", feature, call. = FALSE)
    }
    source_present <- .hybrid_rf_bool_vector(data[[paste0(feature, "__source_present")]], paste0(feature, " source presence"), nrow(data))
    value_present <- .hybrid_rf_bool_vector(data[[paste0(feature, "__value_present")]], paste0(feature, " value presence"), nrow(data))
    imputed <- .hybrid_rf_bool_vector(data[[paste0(feature, "__imputed")]], paste0(feature, " imputation"), nrow(data))
    if (any(!source_present) || any(!value_present) || any(imputed)) {
      stop(label, " fails closed because ", feature, " evidence is absent or imputed", call. = FALSE)
    }
  }
  invisible(list(max_source_date = max(unlist(lapply(feature_ids, function(feature) {
    as.Date(data[[paste0(feature, "__source_date")]])
  })), na.rm = TRUE)))
}

.hybrid_rf_environment <- function(settings) {
  .hybrid_rf_source_if_missing(
    "R/benchmark/challenger_preflight.R",
    c("require_hybrid_environment")
  )
  require_hybrid_environment(settings$provenance_path, offline = TRUE)
}

.hybrid_rf_numeric_frame <- function(data, feature_ids, label) {
  result <- data[, feature_ids, drop = FALSE]
  for (feature in feature_ids) result[[feature]] <- suppressWarnings(as.numeric(result[[feature]]))
  if (any(!is.finite(as.matrix(result)))) stop(label, " contains non-finite RF predictors", call. = FALSE)
  result
}

#' Fit independent ranger forests for home and away goals.
#'
#' The exact project-local ranger 0.18.0 runtime is required before either
#' forest is fitted.  No 1X2 classifier or alternate random-forest package is
#' used by this adapter.
#' @export
fit_hybrid_two_goal_rf <- function(history, cutoff, settings = list(), registration = NULL) {
  registration <- .hybrid_rf_registration_row(registration)
  settings <- hybrid_rf_registered_settings(settings, registration)
  environment <- .hybrid_rf_environment(settings)
  if (!is.data.frame(history) || !nrow(history)) stop("RF history must contain rows", call. = FALSE)
  date_col <- .hybrid_rf_date_column(history, "RF history")
  response <- .hybrid_rf_goal_columns(history, "RF history")
  cutoff <- as.Date(cutoff)
  if (length(cutoff) != 1L || is.na(cutoff)) stop("RF cutoff must be one non-missing date", call. = FALSE)
  dates <- as.Date(history[[date_col]])
  if (anyNA(dates)) stop("RF history chronology contains missing dates", call. = FALSE)
  training_index <- dates < cutoff
  if (!any(training_index)) stop("RF history has no rows before the exclusive cutoff", call. = FALSE)
  training <- history[training_index, , drop = FALSE]
  hybrid_rf_validate_evidence(training, as.Date(training[[date_col]]), label = "RF training history")
  goals <- training[, unname(response), drop = FALSE]
  for (column in names(goals)) goals[[column]] <- suppressWarnings(as.numeric(goals[[column]]))
  if (any(!is.finite(as.matrix(goals))) || any(as.matrix(goals) < 0)) {
    stop("RF training goals must be finite non-negative values", call. = FALSE)
  }
  feature_ids <- hybrid_rf_feature_ids()
  predictors <- .hybrid_rf_numeric_frame(training, feature_ids, "RF training history")
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
  source_dates <- unlist(lapply(feature_ids, function(feature) {
    as.Date(training[[paste0(feature, "__source_date")]])
  }))
  fit_columns <- unique(c("fixture_id", date_col, unname(response), feature_ids))
  fit_data_sha256 <- digest::digest(training[, fit_columns, drop = FALSE], algo = "sha256", serialize = TRUE)
  structure(list(
    model_id = "phase11_rf_dynamic_elo_open_v1",
    candidate_id = settings$candidate_id,
    model_family = "random_forest_goal_means",
    panel_id = "open_core",
    home_model = home_model,
    away_model = away_model,
    feature_ids = feature_ids,
    active_predictors = feature_ids,
    dropped_predictors = character(),
    training_dates = dates[training_index],
    fit_training_dates = dates[training_index],
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
    max_feature_source_date = max(source_dates),
    convergence_status = "converged",
    fallback_status = "none",
    fit_data_sha256 = fit_data_sha256,
    seed_home = settings$seed,
    seed_away = settings$seed + 1L
  ), class = "hybrid_two_goal_rf")
}

#' Predict independent home and away goal means from a registered RF fit.
#' @export
predict_hybrid_rf_means <- function(fit, fixtures, settings = list()) {
  if (!inherits(fit, "hybrid_two_goal_rf") || !is.list(fit)) stop("fit must be a hybrid_two_goal_rf", call. = FALSE)
  settings <- hybrid_rf_registered_settings(settings, fit$registration)
  environment <- .hybrid_rf_environment(settings)
  if (!is.data.frame(fixtures) || !nrow(fixtures) || !"fixture_id" %in% names(fixtures)) {
    stop("RF prediction fixtures require fixture_id rows", call. = FALSE)
  }
  if (anyDuplicated(as.character(fixtures$fixture_id))) stop("RF prediction fixture_id values must be unique", call. = FALSE)
  cutoff_col <- if ("evidence_cutoff_exclusive" %in% names(fixtures)) {
    "evidence_cutoff_exclusive"
  } else if ("actual_completion_date" %in% names(fixtures)) {
    "actual_completion_date"
  } else {
    stop("RF prediction fixtures require evidence_cutoff_exclusive", call. = FALSE)
  }
  cutoffs <- as.Date(fixtures[[cutoff_col]])
  if (anyNA(cutoffs)) stop("RF prediction fixtures have missing evidence cutoffs", call. = FALSE)
  hybrid_rf_validate_evidence(fixtures, cutoffs, label = "RF prediction fixtures")
  feature_ids <- fit$feature_ids
  if (!identical(feature_ids, hybrid_rf_feature_ids())) stop("RF fit feature set is not the registered Phase 11 feature set", call. = FALSE)
  predictor_data <- .hybrid_rf_numeric_frame(fixtures, feature_ids, "RF prediction fixtures")
  home_means <- as.numeric(stats::predict(fit$home_model, data = predictor_data)$predictions)
  away_means <- as.numeric(stats::predict(fit$away_model, data = predictor_data)$predictions)
  home_means <- pmax(home_means, .Machine$double.eps)
  away_means <- pmax(away_means, .Machine$double.eps)
  if (any(!is.finite(home_means) | !is.finite(away_means))) stop("RF prediction produced non-finite goal means", call. = FALSE)
  identity_columns <- intersect(
    c("fixture_id", "edition_id", "track_id", "boundary_id", "home_team_id", "away_team_id",
      "venue_role", "actual_completion_date", "evidence_cutoff_exclusive"),
    names(fixtures)
  )
  output <- fixtures[, identity_columns, drop = FALSE]
  for (feature in feature_ids) output[[feature]] <- fixtures[[feature]]
  companions <- unlist(lapply(feature_ids, function(feature) paste0(feature, c(
    "__source_date", "__source_present", "__value_present", "__imputed", "__imputation_reason"
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
  output$environment_offline_replay <- isTRUE(environment$offline_replay)
  output$mean_prediction_hash <- vapply(seq_len(nrow(output)), function(index) {
    digest::digest(
      paste(as.character(output$fixture_id[index]), format(home_means[index], digits = 17), format(away_means[index], digits = 17), sep = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  rownames(output) <- NULL
  output
}

#' Convert RF goal means into independent negative-binomial score grids.
#' @export
hybrid_rf_nb_score_distributions <- function(means, support_max = 40L, settings = list()) {
  if (!is.data.frame(means) || !nrow(means)) stop("RF means must contain rows", call. = FALSE)
  if (!all(c("fixture_id", "mu_home", "mu_away") %in% names(means))) stop("RF means require fixture_id, mu_home, and mu_away", call. = FALSE)
  settings <- hybrid_rf_registered_settings(settings)
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max != settings$support_max || support_max != 40L) {
    stop("RF score distributions must use the sealed G=40 support", call. = FALSE)
  }
  if (anyDuplicated(as.character(means$fixture_id))) stop("RF means fixture_id values must be unique", call. = FALSE)
  home_means <- suppressWarnings(as.numeric(means$mu_home))
  away_means <- suppressWarnings(as.numeric(means$mu_away))
  if (any(!is.finite(home_means) | home_means <= 0 | !is.finite(away_means) | away_means <= 0)) {
    stop("RF means must be finite and strictly positive", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for RF distribution identities", call. = FALSE)
  if (!exists("benchmark_one_distribution", mode = "function")) {
    .hybrid_rf_source_if_missing("R/benchmark/baselines.R", c("benchmark_one_distribution"))
  }
  goals <- 0:support_max
  distributions <- lapply(seq_len(nrow(means)), function(index) {
    home_probability <- stats::dnbinom(goals, size = settings$home_theta, mu = home_means[index])
    away_probability <- stats::dnbinom(goals, size = settings$away_theta, mu = away_means[index])
    raw_tail <- max(0, 1 - sum(home_probability) * sum(away_probability))
    id <- paste0(settings$distribution_id_prefix, "__", as.character(means$fixture_id[index]), "__score")
    grid <- benchmark_one_distribution(id, home_probability, away_probability, raw_tail, support_max)
    grid$mean_parent_id <- as.character(means$fixture_id[index])
    grid$settings_sha256 <- settings$settings_sha256
    grid$registration_sha256 <- settings$registration_sha256
    grid$ranger_provenance_id <- settings$ranger_provenance_id
    grid
  })
  result <- do.call(rbind, distributions)
  rownames(result) <- NULL
  result
}
