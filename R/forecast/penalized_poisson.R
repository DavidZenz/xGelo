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
  structure(list(
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
    raw_linear_predictor = raw_eta,
    centered_linear_predictor = centered_eta
  ), class = "penalized_poisson_team_fit")
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

  centered <- fit$coefficients_centered
  home_attack <- penalized_poisson_effect(fit, centered$attack, home_ids)
  home_defence <- penalized_poisson_effect(fit, centered$defence, away_ids)
  away_attack <- penalized_poisson_effect(fit, centered$attack, away_ids)
  away_defence <- penalized_poisson_effect(fit, centered$defence, home_ids)
  venue_home <- as.integer(as.character(fixtures$venue_role) == "home")
  home_eta <- centered$intercept + home_attack + home_defence + centered$venue * venue_home
  away_eta <- centered$intercept + away_attack + away_defence
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
