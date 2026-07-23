#' Penalized-Poisson team mean models
#'
#' Sparse, identified team attack/defence means for the Phase 10 statistical
#' challenger benchmark. The module deliberately owns only model fitting and
#' prediction; benchmark scoring and market derivation remain shared services.

penalized_poisson_project_root <- function() {
  candidate <- if (basename(getwd()) == "testthat") file.path(getwd(), "../..") else getwd()
  normalizePath(candidate, mustWork = TRUE)
}

penalized_poisson_require_namespace <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    local_library <- file.path(
      penalized_poisson_project_root(), "data", "cache", "phase10-library"
    )
    if (dir.exists(local_library)) {
      .libPaths(unique(c(normalizePath(local_library, mustWork = TRUE), .libPaths())))
    }
  }
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(package, " is required for penalized-Poisson models", call. = FALSE)
  }
  invisible(TRUE)
}

penalized_poisson_sha256 <- function(value) {
  penalized_poisson_require_namespace("digest")
  digest::digest(value, algo = "sha256", serialize = TRUE)
}

penalized_poisson_elo_columns <- function() {
  c(
    "elo_diff", "elo_diff__value_present", "elo_diff__source_present",
    "elo_diff__source_date", "elo_diff__imputed", "elo_diff__imputation_reason"
  )
}

penalized_poisson_reject_raw_ratings <- function(data, label) {
  allowed <- c(penalized_poisson_elo_columns(), "signed_elo_diff")
  suspicious <- names(data)[grepl("elo|rating", names(data), ignore.case = TRUE)]
  forbidden <- setdiff(suspicious, allowed)
  if (length(forbidden)) {
    stop(
      label, " contains forbidden noncanonical raw rating columns: ",
      paste(forbidden, collapse = ", "), call. = FALSE
    )
  }
  invisible(TRUE)
}

penalized_poisson_validate_elo_contract <- function(data, label = "Elo evidence") {
  penalized_poisson_reject_raw_ratings(data, label)
  required <- c(penalized_poisson_elo_columns(), "evidence_cutoff_exclusive")
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(
      label, " is missing canonical elo_diff provenance companions: ",
      paste(missing, collapse = ", "), call. = FALSE
    )
  }
  elo <- suppressWarnings(as.numeric(data$elo_diff))
  value_present <- as.logical(data$elo_diff__value_present)
  source_present <- as.logical(data$elo_diff__source_present)
  imputed <- as.logical(data$elo_diff__imputed)
  reason <- as.character(data$elo_diff__imputation_reason)
  reason[is.na(reason)] <- ""
  source_date <- as.Date(data$elo_diff__source_date)
  cutoff <- as.Date(data$evidence_cutoff_exclusive)
  if (any(!is.finite(elo))) stop(label, " contains non-finite elo_diff values", call. = FALSE)
  if (any(is.na(value_present) | is.na(source_present) | is.na(imputed))) {
    stop(label, " contains invalid Elo provenance flags", call. = FALSE)
  }
  if (any(value_present & !source_present)) {
    stop(label, " value cannot masquerade without source provenance", call. = FALSE)
  }
  if (any(!value_present & !imputed)) {
    stop(label, " missing Elo values require explicit imputation", call. = FALSE)
  }
  if (any(imputed & !nzchar(trimws(reason)))) {
    stop(label, " imputed Elo values require an imputation reason", call. = FALSE)
  }
  if (any(source_present & (is.na(source_date) | is.na(cutoff) | source_date >= cutoff))) {
    stop(label, " source dates must be strictly before the evidence cutoff", call. = FALSE)
  }
  if (any(!source_present & !is.na(source_date))) {
    stop(label, " source-absent Elo evidence cannot retain a source date", call. = FALSE)
  }
  invisible(TRUE)
}

penalized_poisson_response_columns <- function(data) {
  home <- if ("home_goals" %in% names(data)) "home_goals" else "regulation_home_goals"
  away <- if ("away_goals" %in% names(data)) "away_goals" else "regulation_away_goals"
  if (!all(c(home, away) %in% names(data))) {
    stop("Penalized-Poisson history requires home and away goals", call. = FALSE)
  }
  c(home = home, away = away)
}

penalized_poisson_validate_team_ids <- function(team_ids, label) {
  team_ids <- as.character(team_ids)
  if (!length(team_ids) || any(is.na(team_ids) | !nzchar(team_ids))) {
    stop(label, " must contain non-empty team IDs", call. = FALSE)
  }
  if (anyDuplicated(team_ids)) stop(label, " must contain unique team IDs", call. = FALSE)
  team_ids
}

#' Build the full sparse attack/defence design
#'
#' @param history Match rows with stable home/away team IDs and goals.
#' @param registered_team_ids Complete registered team identity vector.
#' @return Sparse design, response, penalty factors, levels, and goal-row data.
#' @export
build_penalized_poisson_design <- function(history, registered_team_ids) {
  penalized_poisson_require_namespace("Matrix")
  if (!is.data.frame(history) || !nrow(history)) {
    stop("history must be a non-empty data frame", call. = FALSE)
  }
  required <- c("home_team_id", "away_team_id", "venue_role")
  missing <- setdiff(required, names(history))
  if (length(missing)) {
    stop("Penalized-Poisson history is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  team_levels <- penalized_poisson_validate_team_ids(
    registered_team_ids, "registered_team_ids"
  )
  observed_ids <- as.character(c(history$home_team_id, history$away_team_id))
  if (any(is.na(observed_ids) | !nzchar(observed_ids))) {
    stop("History team IDs must be non-empty", call. = FALSE)
  }
  unregistered <- setdiff(unique(observed_ids), team_levels)
  if (length(unregistered)) {
    stop(
      "History contains unregistered team IDs: ", paste(unregistered, collapse = ", "),
      call. = FALSE
    )
  }

  response_columns <- penalized_poisson_response_columns(history)
  response <- c(
    suppressWarnings(as.numeric(history[[response_columns[["home"]]]])),
    suppressWarnings(as.numeric(history[[response_columns[["away"]]]]))
  )
  if (any(!is.finite(response) | response < 0 | response != floor(response))) {
    stop("Penalized-Poisson goals must be finite non-negative counts", call. = FALSE)
  }

  n_matches <- nrow(history)
  n_rows <- 2L * n_matches
  n_teams <- length(team_levels)
  scoring_team_id <- c(as.character(history$home_team_id), as.character(history$away_team_id))
  defending_team_id <- c(as.character(history$away_team_id), as.character(history$home_team_id))
  venue <- c(as.integer(as.character(history$venue_role) == "home"), rep.int(0L, n_matches))
  signed_elo <- if ("elo_diff" %in% names(history)) {
    elo <- suppressWarnings(as.numeric(history$elo_diff))
    if (any(!is.finite(elo))) stop("elo_diff must be finite when supplied", call. = FALSE)
    c(elo, -elo)
  } else {
    rep.int(0, n_rows)
  }

  row_index <- seq_len(n_rows)
  venue_rows <- which(venue != 0L)
  sparse_i <- c(row_index, venue_rows, row_index, row_index)
  sparse_j <- c(
    rep.int(1L, n_rows),
    rep.int(2L, length(venue_rows)),
    2L + match(scoring_team_id, team_levels),
    2L + n_teams + match(defending_team_id, team_levels)
  )
  design <- Matrix::sparseMatrix(
    i = sparse_i,
    j = sparse_j,
    x = rep.int(1, length(sparse_i)),
    dims = c(n_rows, 2L + 2L * n_teams),
    dimnames = list(
      NULL,
      c(
        "intercept", "venue_home_non_neutral",
        paste0("attack__", team_levels), paste0("defence__", team_levels)
      )
    )
  )

  row_data <- data.frame(
    match_row = rep.int(seq_len(n_matches), 2L),
    goal_side = rep(c("home", "away"), each = n_matches),
    scoring_team_id = scoring_team_id,
    defending_team_id = defending_team_id,
    venue_home_non_neutral = venue,
    signed_elo_diff = signed_elo,
    stringsAsFactors = FALSE
  )
  if ("elo_diff" %in% names(history)) row_data$elo_diff <- signed_elo
  companion_columns <- setdiff(penalized_poisson_elo_columns(), "elo_diff")
  for (column in companion_columns) {
    if (column %in% names(history)) row_data[[column]] <- rep(history[[column]], 2L)
  }
  if ("evidence_cutoff_exclusive" %in% names(history)) {
    row_data$evidence_cutoff_exclusive <- rep(history$evidence_cutoff_exclusive, 2L)
  }
  prior_counts <- table(factor(observed_ids, levels = team_levels))

  structure(list(
    x = design,
    response = response,
    penalty_factor = c(0, 0, rep.int(1, 2L * n_teams)),
    team_levels = team_levels,
    row_data = row_data,
    prior_counts = stats::setNames(as.integer(prior_counts), team_levels),
    history = history
  ), class = "penalized_poisson_design")
}

penalized_poisson_lambda_path <- function(lambda) {
  lambda <- as.numeric(lambda)
  if (length(lambda) != 1L || !is.finite(lambda) || lambda <= 0) {
    stop("lambda must be one positive finite value", call. = FALSE)
  }
  sort(unique(c(lambda * (1 + 1e-6), lambda)), decreasing = TRUE)
}

#' Fit ridge-shrunk team attack and defence means
#'
#' @param design Output from `build_penalized_poisson_design()`.
#' @param lambda Positive team ridge penalty.
#' @param observation_weights One positive match weight per source match.
#' @return Identified fitted team-mean model.
#' @export
fit_penalized_team_means <- function(design, lambda, observation_weights = NULL) {
  penalized_poisson_require_namespace("glmnet")
  if (!inherits(design, "penalized_poisson_design")) {
    stop("design must come from build_penalized_poisson_design()", call. = FALSE)
  }
  lambda_path <- penalized_poisson_lambda_path(lambda)
  n_matches <- nrow(design$row_data) / 2L
  if (is.null(observation_weights)) observation_weights <- rep.int(1, n_matches)
  observation_weights <- as.numeric(observation_weights)
  if (
    length(observation_weights) != n_matches ||
      any(!is.finite(observation_weights) | observation_weights <= 0)
  ) {
    stop("observation_weights must contain one positive finite value per match", call. = FALSE)
  }
  observation_weights <- observation_weights / mean(observation_weights)
  goal_row_weights <- rep(observation_weights, 2L)

  fitted <- tryCatch(
    glmnet::glmnet(
      x = design$x,
      y = design$response,
      family = "poisson",
      alpha = 0,
      lambda = lambda_path,
      weights = goal_row_weights,
      penalty.factor = design$penalty_factor,
      intercept = FALSE,
      standardize = FALSE,
      control = list(thresh = 1e-10, maxit = 1000000L)
    ),
    error = function(error) {
      structure(list(error = conditionMessage(error)), class = "penalized_poisson_fit_error")
    }
  )
  if (inherits(fitted, "penalized_poisson_fit_error")) {
    stop("Penalized-Poisson ridge fit failed: ", fitted$error, call. = FALSE)
  }
  if (length(fitted$jerr) != 1L || fitted$jerr != 0L) {
    stop("Penalized-Poisson ridge fit did not converge", call. = FALSE)
  }

  selected_lambda <- min(lambda_path)
  coefficient_matrix <- as.matrix(stats::coef(fitted, s = selected_lambda))
  coefficient_values <- coefficient_matrix[, 1L]
  names(coefficient_values) <- rownames(coefficient_matrix)
  values <- coefficient_values[colnames(design$x)]
  if (any(!is.finite(values))) {
    stop("Penalized-Poisson ridge fit returned non-finite coefficients", call. = FALSE)
  }
  n_teams <- length(design$team_levels)
  attack <- stats::setNames(values[2L + seq_len(n_teams)], design$team_levels)
  defence <- stats::setNames(values[2L + n_teams + seq_len(n_teams)], design$team_levels)
  attack_mean <- mean(attack)
  defence_mean <- mean(defence)
  coefficients_raw <- list(
    intercept = unname(values[[1L]]),
    venue = unname(values[[2L]]),
    attack = attack,
    defence = defence
  )
  coefficients_centered <- list(
    intercept = unname(values[[1L]] + attack_mean + defence_mean),
    venue = unname(values[[2L]]),
    attack = attack - attack_mean,
    defence = defence - defence_mean
  )

  raw_eta <- as.numeric(design$x %*% values)
  centered_eta <- coefficients_centered$intercept +
    unname(coefficients_centered$attack[design$row_data$scoring_team_id]) +
    unname(coefficients_centered$defence[design$row_data$defending_team_id]) +
    coefficients_centered$venue * design$row_data$venue_home_non_neutral
  if (
    any(!is.finite(raw_eta)) || any(!is.finite(centered_eta)) ||
      max(abs(raw_eta - centered_eta)) > 1e-10
  ) {
    stop("Centered team coefficients changed fitted linear predictors", call. = FALSE)
  }

  prior_counts <- design$prior_counts[design$team_levels]
  shrinkage_weights <- prior_counts / (prior_counts + selected_lambda)
  result <- list(
    model_id = "poisson_team_ridge",
    model_family = "penalized_poisson",
    glmnet_fit = fitted,
    lambda = selected_lambda,
    team_levels = design$team_levels,
    coefficients_raw = coefficients_raw,
    coefficients_centered = coefficients_centered,
    prior_counts = prior_counts,
    shrinkage_weights = stats::setNames(as.numeric(shrinkage_weights), design$team_levels),
    fit_row_count = n_matches,
    converged = TRUE,
    convergence_status = "converged",
    fallback_status = "none",
    package_version = as.character(utils::packageVersion("glmnet")),
    observation_weights = goal_row_weights,
    raw_linear_predictor = raw_eta,
    centered_linear_predictor = centered_eta
  )
  result$team_fit_sha256 <- penalized_poisson_sha256(list(
    lambda = result$lambda,
    team_levels = result$team_levels,
    coefficients = result$coefficients_centered,
    fit_row_count = result$fit_row_count
  ))
  structure(result, class = "penalized_poisson_team_fit")
}

penalized_poisson_team_evidence <- function(fit, team_ids) {
  known <- team_ids %in% fit$team_levels
  counts <- rep.int(0L, length(team_ids))
  weights <- rep.int(0, length(team_ids))
  counts[known] <- as.integer(fit$prior_counts[team_ids[known]])
  weights[known] <- as.numeric(fit$shrinkage_weights[team_ids[known]])
  list(
    prior_count = counts,
    shrinkage_weight = weights,
    cold_start_status = ifelse(counts == 0L, "cold_start_global", "ridge_shrunk")
  )
}

penalized_poisson_effect <- function(fit, coefficients, team_ids) {
  result <- rep.int(0, length(team_ids))
  known <- team_ids %in% names(coefficients) &
    team_ids %in% names(fit$prior_counts) &
    as.integer(fit$prior_counts[team_ids]) > 0L
  known[is.na(known)] <- FALSE
  result[known] <- unname(coefficients[team_ids[known]])
  result
}

#' Fit the nested Elo increment over fixed team-model offsets
#'
#' @param minimal_fit Output from `fit_penalized_team_means()`.
#' @param design The exact design used for the minimal fit.
#' @param lambda Positive Elo lasso penalty.
#' @return The minimal fit plus an attributable, possibly zero, Elo increment.
#' @export
fit_penalized_elo_offset <- function(minimal_fit, design, lambda) {
  penalized_poisson_require_namespace("glmnet")
  if (!inherits(minimal_fit, "penalized_poisson_team_fit")) {
    stop("minimal_fit must come from fit_penalized_team_means()", call. = FALSE)
  }
  if (!inherits(design, "penalized_poisson_design")) {
    stop("design must come from build_penalized_poisson_design()", call. = FALSE)
  }
  if (nrow(design$row_data) != length(minimal_fit$centered_linear_predictor)) {
    stop("minimal_fit and design do not describe the same goal rows", call. = FALSE)
  }
  penalized_poisson_validate_elo_contract(design$row_data, "Penalized-Poisson Elo design")
  lambda_path <- penalized_poisson_lambda_path(lambda)
  elo_predictor <- as.numeric(design$row_data$elo_diff)
  elo_design <- cbind(
    elo_diff = elo_predictor,
    `.excluded_technical_column` = rep.int(0, length(elo_predictor))
  )
  fitted <- tryCatch(
    glmnet::glmnet(
      x = elo_design,
      y = design$response,
      family = "poisson",
      alpha = 1,
      lambda = lambda_path,
      weights = minimal_fit$observation_weights,
      offset = minimal_fit$centered_linear_predictor,
      penalty.factor = c(1, 1),
      exclude = 2L,
      intercept = FALSE,
      standardize = FALSE,
      control = list(thresh = 1e-10, maxit = 1000000L)
    ),
    error = function(error) {
      structure(list(error = conditionMessage(error)), class = "penalized_poisson_fit_error")
    }
  )
  if (inherits(fitted, "penalized_poisson_fit_error")) {
    stop("Penalized-Poisson Elo fit failed: ", fitted$error, call. = FALSE)
  }
  if (length(fitted$jerr) != 1L || fitted$jerr != 0L) {
    stop("Penalized-Poisson Elo fit did not converge", call. = FALSE)
  }
  selected_lambda <- min(lambda_path)
  coefficient_matrix <- as.matrix(stats::coef(fitted, s = selected_lambda))
  elo_coefficient <- unname(coefficient_matrix["elo_diff", 1L])
  if (!is.finite(elo_coefficient)) {
    stop("Penalized-Poisson Elo fit returned a non-finite coefficient", call. = FALSE)
  }
  if (abs(elo_coefficient) <= 1e-12) elo_coefficient <- 0

  augmented <- minimal_fit
  augmented$model_id <- "poisson_team_ridge_elo"
  augmented$elo_glmnet_fit <- fitted
  augmented$elo_lambda <- selected_lambda
  augmented$elo_coefficient <- elo_coefficient
  augmented$active_predictors <- if (elo_coefficient == 0) character() else "elo_diff"
  augmented$dropped_predictors_with_reason <- if (elo_coefficient == 0) {
    "elo_diff: lasso coefficient selected to zero"
  } else {
    character()
  }
  class(augmented) <- c("penalized_poisson_elo_fit", class(minimal_fit))
  augmented
}

penalized_poisson_require_columns <- function(data, required, label) {
  if (!is.data.frame(data)) stop(label, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(label, " is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

penalized_poisson_date_column <- function(data) {
  if ("actual_completion_date" %in% names(data)) "actual_completion_date" else "date"
}

penalized_poisson_observation_weights <- function(history, cutoff) {
  if (exists("benchmark_observation_weights", mode = "function", inherits = TRUE)) {
    weight_function <- get("benchmark_observation_weights", mode = "function", inherits = TRUE)
  } else {
    weight_environment <- new.env(parent = baseenv())
    sys.source(
      file.path(penalized_poisson_project_root(), "R", "benchmark", "weights.R"),
      envir = weight_environment
    )
    weight_function <- weight_environment$benchmark_observation_weights
  }
  weight_function(history, cutoff)
}

penalized_poisson_score_means <- function(mu_home, mu_away, observed, support_max) {
  if (!exists("derive_benchmark_markets", mode = "function", inherits = TRUE) ||
      !exists("ranked_probability_score", mode = "function", inherits = TRUE)) {
    stop("Shared benchmark market and proper-score functions must be loaded", call. = FALSE)
  }
  grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
  grid$probability <- stats::dpois(grid$home_goals, mu_home) *
    stats::dpois(grid$away_goals, mu_away)
  grid$probability <- grid$probability / sum(grid$probability)
  markets <- derive_benchmark_markets(grid)
  probabilities <- c(
    home = markets$p_home, draw = markets$p_draw, away = markets$p_away
  )
  probabilities <- pmax(0, pmin(1, probabilities))
  probabilities <- probabilities / sum(probabilities)
  names(probabilities) <- c("home", "draw", "away")
  ranked_probability_score(
    probabilities, observed
  )
}

penalized_poisson_select_largest_tie <- function(values, scores) {
  if (any(!is.finite(scores))) stop("Hyperparameter objective is non-finite", call. = FALSE)
  best <- min(scores)
  max(values[abs(scores - best) <= 1e-12])
}

#' Select team and Elo penalties using only completed prior tournaments
#'
#' @return One immutable settings row for each of the frozen and updating tracks.
#' @export
select_penalized_poisson_hyperparameters <- function(
    history, outer_edition_id, tournaments, tuning_editions, tuning_grid,
    tournament_map, support_max = 40L
) {
  penalized_poisson_require_columns(
    history,
    c(
      "match_id", "edition_id", "home_team_id", "away_team_id", "venue_role",
      "elo_diff", "evidence_cutoff_exclusive"
    ),
    "Penalized-Poisson tuning history"
  )
  penalized_poisson_reject_raw_ratings(history, "Penalized-Poisson tuning history")
  penalized_poisson_validate_elo_contract(history, "Penalized-Poisson tuning history")
  if (anyDuplicated(history$match_id) || any(is.na(history$match_id) | !nzchar(history$match_id))) {
    stop("Tuning history match_id must be unique and nonmissing", call. = FALSE)
  }
  penalized_poisson_require_columns(tournament_map, c("match_id", "tournament"), "Tournament map")
  if (!setequal(names(tournament_map), c("match_id", "tournament"))) {
    stop("Tournament map may expose only match_id and tournament", call. = FALSE)
  }
  if (anyDuplicated(tournament_map$match_id) ||
      any(is.na(tournament_map$match_id) | !nzchar(tournament_map$match_id))) {
    stop("Tournament map match_id must be unique for a one-to-one join", call. = FALSE)
  }
  if (!setequal(as.character(history$match_id), as.character(tournament_map$match_id))) {
    stop("Tournament map must provide complete unmatched-free match coverage", call. = FALSE)
  }
  mapped_tournament <- as.character(tournament_map$tournament)[
    match(as.character(history$match_id), as.character(tournament_map$match_id))
  ]
  if (any(is.na(mapped_tournament) | !nzchar(mapped_tournament))) {
    stop("Tournament map must provide complete nonmissing tournament coverage", call. = FALSE)
  }
  history$tournament <- mapped_tournament

  penalized_poisson_require_columns(
    tournaments, c("edition_id", "opener_date", "final_date"), "Tournament registry"
  )
  outer <- tournaments[as.character(tournaments$edition_id) == outer_edition_id, , drop = FALSE]
  if (nrow(outer) != 1L) stop("outer_edition_id must identify one tournament", call. = FALSE)
  outer_opener <- as.Date(outer$opener_date)
  penalized_poisson_require_columns(
    tuning_editions,
    c(
      "outer_edition_id", "inner_edition_id", "inner_final_date",
      "outer_opener_date", "objective_track", "eligible_match_ids_sha256"
    ),
    "Tuning-edition registry"
  )
  tuning_rows <- tuning_editions[
    as.character(tuning_editions$outer_edition_id) == outer_edition_id,
    , drop = FALSE
  ]
  if (!nrow(tuning_rows)) stop("No tuning editions are registered for the outer edition", call. = FALSE)
  if (any(as.Date(tuning_rows$inner_final_date) >= outer_opener) ||
      any(as.Date(tuning_rows$outer_opener_date) != outer_opener)) {
    stop("Tuning editions must finish strictly before the outer opener", call. = FALSE)
  }
  if (any(as.character(tuning_rows$objective_track) != "updating")) {
    stop("Tuning-edition objective_track must be updating", call. = FALSE)
  }
  registry_hashes <- tolower(as.character(tuning_rows$eligible_match_ids_sha256))
  if (any(!grepl("^[0-9a-f]{64}$", registry_hashes))) {
    stop("Tuning-edition eligible match hashes must be canonical SHA-256", call. = FALSE)
  }

  inner_ids <- as.character(tuning_rows$inner_edition_id)
  date_column <- penalized_poisson_date_column(history)
  completion_date <- as.Date(history[[date_column]])
  eligible <- completion_date < outer_opener & as.character(history$edition_id) %in% inner_ids
  eligible_history <- history[eligible, , drop = FALSE]
  if (!nrow(eligible_history)) stop("No strictly prior tuning history is available", call. = FALSE)
  if (!setequal(unique(as.character(eligible_history$edition_id)), inner_ids)) {
    stop("Tuning history does not completely cover registered inner editions", call. = FALSE)
  }
  registered_team_ids <- sort(unique(c(
    as.character(eligible_history$home_team_id),
    as.character(eligible_history$away_team_id)
  )))

  value_column <- if ("parameter_value" %in% names(tuning_grid)) {
    "parameter_value"
  } else {
    "value"
  }
  penalized_poisson_require_columns(
    tuning_grid, c("parameter_id", value_column), "Tuning grid"
  )
  grid_value <- suppressWarnings(as.numeric(tuning_grid[[value_column]]))
  team_values <- grid_value[tuning_grid$parameter_id == "team_ridge_lambda"]
  elo_values <- grid_value[tuning_grid$parameter_id == "elo_lasso_lambda"]
  if (!length(team_values) || !length(elo_values) ||
      any(!is.finite(c(team_values, elo_values)) | c(team_values, elo_values) <= 0)) {
    stop("Tuning grid must contain positive team and Elo penalties", call. = FALSE)
  }
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max < 1L) {
    stop("support_max must be one positive integer", call. = FALSE)
  }

  assessment_rows <- lapply(inner_ids, function(inner_id) {
    rows <- eligible_history[eligible_history$edition_id == inner_id, , drop = FALSE]
    rows[order(as.Date(rows[[date_column]]), as.character(rows$match_id)), , drop = FALSE]
  })
  names(assessment_rows) <- inner_ids
  fit_cache <- new.env(parent = emptyenv())
  evaluate_team <- function(team_lambda) {
    tournament_scores <- numeric(length(inner_ids))
    for (edition_index in seq_along(inner_ids)) {
      assessment <- assessment_rows[[edition_index]]
      fixture_scores <- numeric(nrow(assessment))
      for (fixture_index in seq_len(nrow(assessment))) {
        cutoff <- as.Date(assessment[[date_column]][fixture_index])
        training <- eligible_history[
          as.Date(eligible_history[[date_column]]) < cutoff,
          , drop = FALSE
        ]
        if (!nrow(training)) {
          fixture_scores[fixture_index] <- NA_real_
          next
        }
        design <- build_penalized_poisson_design(training, registered_team_ids)
        minimal <- fit_penalized_team_means(
          design,
          lambda = team_lambda,
          observation_weights = penalized_poisson_observation_weights(training, cutoff)
        )
        cache_key <- paste(format(team_lambda, digits = 17), assessment$match_id[fixture_index], sep = "::")
        assign(cache_key, list(fit = minimal, design = design), envir = fit_cache)
        prediction <- predict_penalized_poisson_means(minimal, assessment[fixture_index, , drop = FALSE])
        response_columns <- penalized_poisson_response_columns(assessment)
        home_goals <- assessment[[response_columns[["home"]]]][fixture_index]
        away_goals <- assessment[[response_columns[["away"]]]][fixture_index]
        observed <- if (home_goals > away_goals) "home" else if (home_goals == away_goals) "draw" else "away"
        fixture_scores[fixture_index] <- penalized_poisson_score_means(
          prediction$mu_home, prediction$mu_away, observed, support_max
        )
      }
      tournament_scores[edition_index] <- mean(fixture_scores, na.rm = TRUE)
    }
    mean(tournament_scores[is.finite(tournament_scores)])
  }
  team_scores <- vapply(team_values, evaluate_team, numeric(1))
  selected_team <- penalized_poisson_select_largest_tie(team_values, team_scores)

  evaluate_elo <- function(elo_lambda) {
    tournament_scores <- numeric(length(inner_ids))
    for (edition_index in seq_along(inner_ids)) {
      assessment <- assessment_rows[[edition_index]]
      fixture_scores <- numeric(nrow(assessment))
      for (fixture_index in seq_len(nrow(assessment))) {
        cutoff <- as.Date(assessment[[date_column]][fixture_index])
        training <- eligible_history[
          as.Date(eligible_history[[date_column]]) < cutoff,
          , drop = FALSE
        ]
        if (!nrow(training)) {
          fixture_scores[fixture_index] <- NA_real_
          next
        }
        cache_key <- paste(format(selected_team, digits = 17), assessment$match_id[fixture_index], sep = "::")
        cached <- get(cache_key, envir = fit_cache, inherits = FALSE)
        augmented <- fit_penalized_elo_offset(cached$fit, cached$design, elo_lambda)
        prediction <- predict_penalized_poisson_means(
          augmented, assessment[fixture_index, , drop = FALSE]
        )
        response_columns <- penalized_poisson_response_columns(assessment)
        home_goals <- assessment[[response_columns[["home"]]]][fixture_index]
        away_goals <- assessment[[response_columns[["away"]]]][fixture_index]
        observed <- if (home_goals > away_goals) "home" else if (home_goals == away_goals) "draw" else "away"
        fixture_scores[fixture_index] <- penalized_poisson_score_means(
          prediction$mu_home, prediction$mu_away, observed, support_max
        )
      }
      tournament_scores[edition_index] <- mean(fixture_scores, na.rm = TRUE)
    }
    mean(tournament_scores[is.finite(tournament_scores)])
  }
  elo_scores <- vapply(elo_values, evaluate_elo, numeric(1))
  selected_elo <- penalized_poisson_select_largest_tie(elo_values, elo_scores)

  eligible_hash <- penalized_poisson_sha256(sort(as.character(eligible_history$match_id)))
  grid_hash <- penalized_poisson_sha256(tuning_grid)
  protocol_hash <- penalized_poisson_sha256(list(
    objective = "equal_tournament_updating_rps_prior_editions_only",
    sequence = c("team_ridge_lambda", "elo_lasso_lambda"),
    tie_break = "largest_penalty",
    support_max = support_max,
    inner_editions = inner_ids
  ))
  settings_hash <- penalized_poisson_sha256(list(
    outer_edition_id = outer_edition_id,
    team_ridge_lambda = selected_team,
    elo_lasso_lambda = selected_elo,
    eligible_match_ids_sha256 = eligible_hash,
    tuning_grid_sha256 = grid_hash,
    tuning_protocol_sha256 = protocol_hash
  ))
  data.frame(
    outer_edition_id = outer_edition_id,
    track_id = c("frozen", "updating"),
    team_ridge_lambda = selected_team,
    elo_lasso_lambda = selected_elo,
    team_selection_rps = team_scores[match(selected_team, team_values)],
    elo_selection_rps = elo_scores[match(selected_elo, elo_values)],
    eligible_match_ids_sha256 = eligible_hash,
    tuning_grid_sha256 = grid_hash,
    tuning_protocol_sha256 = protocol_hash,
    settings_sha256 = settings_hash,
    max_inner_final_date = max(as.Date(tuning_rows$inner_final_date)),
    objective_track = "updating",
    evidence_cutoff_exclusive = outer_opener,
    stringsAsFactors = FALSE
  )
}

#' Predict complete penalized-Poisson means with cold-start evidence
#'
#' @param fit Output from `fit_penalized_team_means()`.
#' @param fixtures Assessment fixtures keyed by stable team IDs.
#' @return Fixture means plus prior-count, shrinkage, and cold-start evidence.
#' @export
predict_penalized_poisson_means <- function(fit, fixtures) {
  if (!inherits(fit, "penalized_poisson_team_fit")) {
    stop("fit must come from fit_penalized_team_means()", call. = FALSE)
  }
  if (!is.data.frame(fixtures) || !nrow(fixtures)) {
    stop("fixtures must be a non-empty data frame", call. = FALSE)
  }
  required <- c("fixture_id", "home_team_id", "away_team_id", "venue_role")
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) {
    stop("Prediction fixtures are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  home_ids <- as.character(fixtures$home_team_id)
  away_ids <- as.character(fixtures$away_team_id)
  if (any(is.na(home_ids) | !nzchar(home_ids) | is.na(away_ids) | !nzchar(away_ids))) {
    stop("Prediction fixture team IDs must be non-empty", call. = FALSE)
  }
  if (inherits(fit, "penalized_poisson_elo_fit")) {
    penalized_poisson_validate_elo_contract(fixtures, "Penalized-Poisson Elo fixtures")
  }

  centered <- fit$coefficients_centered
  home_attack <- penalized_poisson_effect(fit, centered$attack, home_ids)
  home_defence <- penalized_poisson_effect(fit, centered$defence, away_ids)
  away_attack <- penalized_poisson_effect(fit, centered$attack, away_ids)
  away_defence <- penalized_poisson_effect(fit, centered$defence, home_ids)
  venue_home <- as.integer(as.character(fixtures$venue_role) == "home")
  home_eta <- centered$intercept + home_attack + home_defence + centered$venue * venue_home
  away_eta <- centered$intercept + away_attack + away_defence
  if (inherits(fit, "penalized_poisson_elo_fit")) {
    elo_diff <- as.numeric(fixtures$elo_diff)
    home_eta <- home_eta + fit$elo_coefficient * elo_diff
    away_eta <- away_eta - fit$elo_coefficient * elo_diff
  }
  mu_home <- exp(home_eta)
  mu_away <- exp(away_eta)
  if (any(!is.finite(mu_home) | mu_home <= 0 | !is.finite(mu_away) | mu_away <= 0)) {
    stop("Penalized-Poisson prediction produced invalid means", call. = FALSE)
  }

  home_evidence <- penalized_poisson_team_evidence(fit, home_ids)
  away_evidence <- penalized_poisson_team_evidence(fit, away_ids)
  data.frame(
    fixture_id = as.character(fixtures$fixture_id),
    mu_home = mu_home,
    mu_away = mu_away,
    home_prior_count = home_evidence$prior_count,
    away_prior_count = away_evidence$prior_count,
    home_shrinkage_weight = home_evidence$shrinkage_weight,
    away_shrinkage_weight = away_evidence$shrinkage_weight,
    home_cold_start_status = home_evidence$cold_start_status,
    away_cold_start_status = away_evidence$cold_start_status,
    home_attack_effect = home_attack,
    home_defence_effect = home_defence,
    away_attack_effect = away_attack,
    away_defence_effect = home_defence,
    away_goal_defence_effect = away_defence,
    stringsAsFactors = FALSE
  )
}

#' Create immutable fit and chronology evidence for the nested candidate
#'
#' @export
penalized_poisson_manifest <- function(
    fit, settings, history, fixtures, candidate_id, outer_edition_id
) {
  if (!inherits(fit, "penalized_poisson_elo_fit")) {
    stop("fit must be the nested Elo candidate", call. = FALSE)
  }
  penalized_poisson_require_columns(
    settings,
    c(
      "track_id", "team_ridge_lambda", "elo_lasso_lambda",
      "eligible_match_ids_sha256", "tuning_grid_sha256",
      "tuning_protocol_sha256", "settings_sha256", "evidence_cutoff_exclusive"
    ),
    "Penalized-Poisson settings"
  )
  if (any(as.character(settings$outer_edition_id) != outer_edition_id)) {
    stop("settings do not belong to the requested outer edition", call. = FALSE)
  }
  predictions <- predict_penalized_poisson_means(fit, fixtures)
  cold_start <- predictions$home_cold_start_status == "cold_start_global" |
    predictions$away_cold_start_status == "cold_start_global"
  date_column <- penalized_poisson_date_column(history)
  fit_max_date <- max(as.Date(history[[date_column]]))
  source_dates <- as.Date(history$elo_diff__source_date)
  source_dates <- source_dates[!is.na(source_dates)]
  max_feature_source_date <- if (length(source_dates)) max(source_dates) else as.Date(NA)
  cutoff <- as.Date(settings$evidence_cutoff_exclusive)
  if (any(is.na(cutoff)) || fit_max_date >= min(cutoff) ||
      (!is.na(max_feature_source_date) && max_feature_source_date >= min(cutoff))) {
    stop("Manifest fit and feature evidence must be strictly prior to the cutoff", call. = FALSE)
  }
  active <- paste(fit$active_predictors, collapse = ",")
  dropped <- paste(fit$dropped_predictors_with_reason, collapse = "; ")
  data.frame(
    candidate_id = candidate_id,
    outer_edition_id = outer_edition_id,
    track_id = as.character(settings$track_id),
    team_ridge_lambda = as.numeric(settings$team_ridge_lambda),
    elo_lasso_lambda = as.numeric(settings$elo_lasso_lambda),
    eligible_match_ids_sha256 = as.character(settings$eligible_match_ids_sha256),
    tuning_grid_sha256 = as.character(settings$tuning_grid_sha256),
    tuning_protocol_sha256 = as.character(settings$tuning_protocol_sha256),
    settings_sha256 = as.character(settings$settings_sha256),
    team_fit_sha256 = fit$team_fit_sha256,
    active_predictors = active,
    dropped_predictors_with_reason = dropped,
    cold_start_fixture_count = sum(cold_start),
    fit_max_date = fit_max_date,
    max_feature_source_date = max_feature_source_date,
    evidence_cutoff_exclusive = cutoff,
    glmnet_version = fit$package_version,
    convergence_status = fit$convergence_status,
    stringsAsFactors = FALSE
  )
}
