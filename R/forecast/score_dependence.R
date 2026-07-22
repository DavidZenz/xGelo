#' Score-dependence corrections over one immutable mean structure

.dependence_require_means <- function(mu_home, mu_away) {
  values <- c(mu_home = mu_home, mu_away = mu_away)
  if (length(mu_home) != length(mu_away) || !length(mu_home) ||
      any(!is.finite(values)) || any(values <= 0)) {
    stop("mu_home and mu_away must be equal-length finite positive means", call. = FALSE)
  }
  invisible(TRUE)
}

.dependence_require_grid_arguments <- function(mu_home, mu_away, support_max,
                                               score_distribution_id) {
  .dependence_require_means(mu_home, mu_away)
  if (length(mu_home) != 1L) {
    stop("A score grid requires one home mean and one away mean", call. = FALSE)
  }
  if (length(support_max) != 1L || !is.finite(support_max) ||
      support_max != 40 || support_max != as.integer(support_max)) {
    stop("Score-dependence grids require the sealed support_max of 40", call. = FALSE)
  }
  score_distribution_id <- as.character(score_distribution_id)
  if (length(score_distribution_id) != 1L || is.na(score_distribution_id) ||
      !nzchar(score_distribution_id)) {
    stop("score_distribution_id must be one non-empty value", call. = FALSE)
  }
  invisible(TRUE)
}

.dependence_log_sum_exp <- function(values) {
  if (!length(values) || any(!is.finite(values))) {
    stop("Dependence log probabilities must be finite", call. = FALSE)
  }
  maximum <- max(values)
  maximum + log(sum(exp(values - maximum)))
}

.dependence_finalize_grid <- function(cells, log_probability,
                                      score_distribution_id, support_max,
                                      mu_home, mu_away) {
  if (length(log_probability) != nrow(cells) || any(!is.finite(log_probability))) {
    stop("Dependence grid contains nonfinite log probabilities", call. = FALSE)
  }
  log_mass <- .dependence_log_sum_exp(log_probability)
  probability <- exp(log_probability - log_mass)
  if (any(!is.finite(probability)) || any(probability < 0) ||
      !is.finite(sum(probability)) || sum(probability) <= 0) {
    stop("Dependence grid contains invalid probability cells", call. = FALSE)
  }
  probability <- probability / sum(probability)
  if (any(probability <= 0)) {
    stop("Dependence grid contains non-positive probability cells", call. = FALSE)
  }

  grid <- data.frame(
    score_distribution_id = as.character(score_distribution_id),
    home_goals = as.integer(cells$home_goals),
    away_goals = as.integer(cells$away_goals),
    probability = probability,
    support_max_home = as.integer(support_max),
    support_max_away = as.integer(support_max),
    raw_tail_mass = max(0, 1 - exp(log_mass)),
    normalized = TRUE,
    stringsAsFactors = FALSE
  )
  recovered <- c(
    home = sum(grid$home_goals * grid$probability),
    away = sum(grid$away_goals * grid$probability)
  )
  if (any(abs(recovered - c(home = mu_home, away = mu_away)) > 1e-10)) {
    stop("Truncated dependence grid does not preserve the supplied marginal means", call. = FALSE)
  }
  grid
}

.dependence_numeric_scalar <- function(value) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
    stop("Mean hash numeric fields must be finite scalars", call. = FALSE)
  }
  sprintf("%.17g", value)
}

#' Hash model means without binding a dependence implementation
#'
#' @param predictions Rows containing outer fold, track, boundary, fixture, and
#'   the two registered marginal means. A dependence identity, when present, is
#'   deliberately ignored.
#' @return A canonical SHA-256 string.
#' @export
statistical_mean_prediction_hash <- function(predictions) {
  required <- c(
    "outer_edition_id", "track_id", "boundary_id", "fixture_id",
    "mu_home", "mu_away"
  )
  if (!is.data.frame(predictions)) stop("Mean predictions must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(predictions))
  if (length(missing)) {
    stop("Mean predictions missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!nrow(predictions)) stop("Mean predictions must not be empty", call. = FALSE)
  identity <- required[seq_len(4L)]
  if (any(vapply(predictions[identity], function(x) {
    values <- as.character(x)
    any(is.na(values) | !nzchar(values))
  }, logical(1)))) {
    stop("Mean prediction identities must be complete", call. = FALSE)
  }
  .dependence_require_means(predictions$mu_home, predictions$mu_away)
  if (anyDuplicated(predictions[identity])) {
    stop("Mean predictions contain duplicate fixture identities", call. = FALSE)
  }
  ordering <- do.call(order, c(lapply(predictions[identity], as.character),
                               list(na.last = TRUE, method = "radix")))
  canonical <- predictions[ordering, required, drop = FALSE]
  rows <- vapply(seq_len(nrow(canonical)), function(i) {
    paste(
      c(
        vapply(canonical[i, identity, drop = FALSE], as.character, character(1)),
        .dependence_numeric_scalar(canonical$mu_home[i]),
        .dependence_numeric_scalar(canonical$mu_away[i])
      ),
      collapse = "|"
    )
  }, character(1))
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for score-dependence hashes", call. = FALSE)
  }
  digest::digest(
    paste(c(paste(required, collapse = "|"), rows), collapse = "\n"),
    algo = "sha256", serialize = FALSE
  )
}

#' Independent Poisson reference grid
#' @export
independent_poisson_grid <- function(mu_home, mu_away, support_max = 40L,
                                     score_distribution_id = "independent") {
  .dependence_require_grid_arguments(
    mu_home, mu_away, support_max, score_distribution_id
  )
  cells <- expand.grid(
    home_goals = 0:as.integer(support_max),
    away_goals = 0:as.integer(support_max)
  )
  log_probability <- stats::dpois(cells$home_goals, mu_home, log = TRUE) +
    stats::dpois(cells$away_goals, mu_away, log = TRUE)
  .dependence_finalize_grid(
    cells, log_probability, score_distribution_id, support_max,
    mu_home, mu_away
  )
}

.dixon_coles_rho_bounds <- function(mu_home, mu_away, epsilon = 1e-12) {
  .dependence_require_means(mu_home, mu_away)
  if (length(epsilon) != 1L || !is.finite(epsilon) || epsilon <= 0) {
    stop("Dixon-Coles bound epsilon must be finite and positive", call. = FALSE)
  }
  lower <- max(c(-1 / mu_home, -1 / mu_away)) + epsilon
  upper <- min(c(1 / (mu_home * mu_away), 1)) - epsilon
  if (!is.finite(lower) || !is.finite(upper) || lower >= upper) {
    stop("Dixon-Coles means do not admit a feasible rho interval", call. = FALSE)
  }
  c(lower = lower, upper = upper)
}

#' Dixon-Coles low-score-corrected Poisson grid
#' @export
dixon_coles_grid <- function(mu_home, mu_away, rho, support_max = 40L,
                             score_distribution_id = "dixon_coles") {
  .dependence_require_grid_arguments(
    mu_home, mu_away, support_max, score_distribution_id
  )
  if (length(rho) != 1L || !is.finite(rho)) {
    stop("rho must be one finite value", call. = FALSE)
  }
  bounds <- .dixon_coles_rho_bounds(mu_home, mu_away)
  if (rho <= bounds[["lower"]] || rho >= bounds[["upper"]]) {
    stop("rho lies outside the feasible positive Dixon-Coles interval", call. = FALSE)
  }

  cells <- expand.grid(
    home_goals = 0:as.integer(support_max),
    away_goals = 0:as.integer(support_max)
  )
  tau <- rep(1, nrow(cells))
  tau[cells$home_goals == 0L & cells$away_goals == 0L] <-
    1 - mu_home * mu_away * rho
  tau[cells$home_goals == 0L & cells$away_goals == 1L] <- 1 + mu_home * rho
  tau[cells$home_goals == 1L & cells$away_goals == 0L] <- 1 + mu_away * rho
  tau[cells$home_goals == 1L & cells$away_goals == 1L] <- 1 - rho
  if (any(!is.finite(tau)) || any(tau <= 0)) {
    stop("rho creates non-positive Dixon-Coles cells", call. = FALSE)
  }
  log_probability <- stats::dpois(cells$home_goals, mu_home, log = TRUE) +
    stats::dpois(cells$away_goals, mu_away, log = TRUE) + log(tau)
  .dependence_finalize_grid(
    cells, log_probability, score_distribution_id, support_max,
    mu_home, mu_away
  )
}

.bivariate_poisson_log_cell <- function(home_goals, away_goals,
                                        lambda_home, lambda_away, kappa) {
  shared <- 0:min(home_goals, away_goals)
  terms <- (home_goals - shared) * log(lambda_home) -
    lgamma(home_goals - shared + 1) +
    (away_goals - shared) * log(lambda_away) -
    lgamma(away_goals - shared + 1) +
    shared * log(kappa) - lgamma(shared + 1)
  -(lambda_home + lambda_away + kappa) + .dependence_log_sum_exp(terms)
}

#' Bivariate-Poisson shared-component grid with fixed supplied marginals
#' @export
bivariate_poisson_grid <- function(mu_home, mu_away, q, support_max = 40L,
                                   score_distribution_id = "bivariate_poisson") {
  .dependence_require_grid_arguments(
    mu_home, mu_away, support_max, score_distribution_id
  )
  if (length(q) != 1L || !is.finite(q) || q < 0 || q >= 1) {
    stop("q must be one finite value in [0, 1)", call. = FALSE)
  }
  if (q == 0) {
    return(independent_poisson_grid(
      mu_home, mu_away, support_max, score_distribution_id
    ))
  }

  kappa <- q * min(mu_home, mu_away)
  lambda_home <- mu_home - kappa
  lambda_away <- mu_away - kappa
  if (any(!is.finite(c(kappa, lambda_home, lambda_away))) ||
      kappa <= 0 || lambda_home <= 0 || lambda_away <= 0) {
    stop("q creates invalid bivariate-Poisson component intensities", call. = FALSE)
  }
  cells <- expand.grid(
    home_goals = 0:as.integer(support_max),
    away_goals = 0:as.integer(support_max)
  )
  log_probability <- vapply(seq_len(nrow(cells)), function(i) {
    .bivariate_poisson_log_cell(
      cells$home_goals[i], cells$away_goals[i],
      lambda_home, lambda_away, kappa
    )
  }, numeric(1))
  .dependence_finalize_grid(
    cells, log_probability, score_distribution_id, support_max,
    mu_home, mu_away
  )
}

.dependence_require_columns <- function(data, required, label) {
  if (!is.data.frame(data)) stop(label, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(label, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

.dependence_sha256 <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for score-dependence hashes", call. = FALSE)
  }
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.dependence_canonical_scalar <- function(value) {
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (is.numeric(value)) {
    return(ifelse(is.na(value), "", vapply(value, function(x) {
      if (!is.finite(x)) stop("Dependence evidence cannot contain nonfinite values", call. = FALSE)
      sprintf("%.17g", x)
    }, character(1))))
  }
  result <- as.character(value)
  result[is.na(result)] <- ""
  result
}

.dependence_row_sha256 <- function(data, hash_col) {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(i) {
    values <- vapply(data[i, fields, drop = FALSE], .dependence_canonical_scalar, character(1))
    .dependence_sha256(paste(values, collapse = "|"))
  }, character(1))
}

.dependence_history_date_column <- function(history) {
  if ("actual_completion_date" %in% names(history)) {
    "actual_completion_date"
  } else if ("date" %in% names(history)) {
    "date"
  } else {
    stop("Dependence history requires actual_completion_date or date", call. = FALSE)
  }
}

.dependence_training_hash <- function(history, date_column) {
  fields <- c(
    "match_id", "edition_id", date_column, "home_goals", "away_goals",
    "mu_home", "mu_away"
  )
  rows <- history[, fields, drop = FALSE]
  ordering <- order(
    as.Date(rows[[date_column]]), as.character(rows$match_id),
    na.last = TRUE, method = "radix"
  )
  rows <- rows[ordering, , drop = FALSE]
  canonical <- vapply(seq_len(nrow(rows)), function(i) {
    paste(
      vapply(rows[i, , drop = FALSE], .dependence_canonical_scalar, character(1)),
      collapse = "|"
    )
  }, character(1))
  .dependence_sha256(paste(c(paste(fields, collapse = "|"), canonical), collapse = "\n"))
}

.dependence_validate_tuning <- function(history, outer_edition_id,
                                        outer_opener_date, tuning_editions) {
  outer_edition_id <- as.character(outer_edition_id)
  if (length(outer_edition_id) != 1L || is.na(outer_edition_id) ||
      !nzchar(outer_edition_id)) {
    stop("outer_edition_id must identify one outer fold", call. = FALSE)
  }
  outer_opener_date <- as.Date(outer_opener_date)
  if (length(outer_opener_date) != 1L || is.na(outer_opener_date)) {
    stop("outer_opener_date must be one valid date", call. = FALSE)
  }
  .dependence_require_columns(
    tuning_editions,
    c("outer_edition_id", "inner_edition_id", "outer_opener_date"),
    "Dependence tuning editions"
  )
  final_column <- if ("inner_final_date" %in% names(tuning_editions)) {
    "inner_final_date"
  } else if ("inner_completion_date" %in% names(tuning_editions)) {
    "inner_completion_date"
  } else {
    stop("Dependence tuning editions require an inner final date", call. = FALSE)
  }
  rows <- tuning_editions[
    as.character(tuning_editions$outer_edition_id) == outer_edition_id,
    , drop = FALSE
  ]
  if (!nrow(rows)) stop("No prior tuning editions are registered for the outer fold", call. = FALSE)
  inner_ids <- as.character(rows$inner_edition_id)
  if (any(is.na(inner_ids) | !nzchar(inner_ids)) || anyDuplicated(inner_ids) ||
      outer_edition_id %in% inner_ids) {
    stop("Dependence tuning editions require unique strictly prior inner folds", call. = FALSE)
  }
  inner_final <- as.Date(rows[[final_column]])
  registered_opener <- as.Date(rows$outer_opener_date)
  if (any(is.na(inner_final)) || any(inner_final >= outer_opener_date) ||
      any(is.na(registered_opener)) || any(registered_opener != outer_opener_date)) {
    stop("Dependence chronology requires every inner edition strictly before the outer opener", call. = FALSE)
  }
  if ("objective_track" %in% names(rows) &&
      any(as.character(rows$objective_track) != "updating")) {
    stop("Dependence tuning objective_track must be updating", call. = FALSE)
  }
  if ("eligible_match_ids_sha256" %in% names(rows)) {
    hashes <- tolower(as.character(rows$eligible_match_ids_sha256))
    if (any(!grepl("^[0-9a-f]{64}$", hashes))) {
      stop("Dependence tuning eligible-match hashes must be canonical SHA-256", call. = FALSE)
    }
  }

  date_column <- .dependence_history_date_column(history)
  dates <- as.Date(history[[date_column]])
  eligible <- history[
    !is.na(dates) & dates < outer_opener_date &
      as.character(history$edition_id) %in% inner_ids,
    , drop = FALSE
  ]
  if (!nrow(eligible) || !setequal(unique(as.character(eligible$edition_id)), inner_ids)) {
    stop("Dependence fitting history must completely cover all registered prior editions", call. = FALSE)
  }
  for (inner_id in inner_ids) {
    edition <- eligible[as.character(eligible$edition_id) == inner_id, , drop = FALSE]
    registry_index <- match(inner_id, inner_ids)
    if (any(as.Date(edition[[date_column]]) > inner_final[registry_index])) {
      stop("Dependence history extends beyond a registered inner final date", call. = FALSE)
    }
    if ("inner_fixture_count" %in% names(rows)) {
      expected_count <- suppressWarnings(as.integer(rows$inner_fixture_count[registry_index]))
      if (is.na(expected_count) || nrow(edition) != expected_count) {
        stop("Dependence eligible match count differs from tuning_editions.csv", call. = FALSE)
      }
    }
    if ("eligible_match_ids_sha256" %in% names(rows)) {
      ids <- sort(unique(as.character(edition$match_id)), method = "radix")
      actual_hash <- .dependence_sha256(paste(ids, collapse = "|"))
      if (!identical(actual_hash, tolower(as.character(
        rows$eligible_match_ids_sha256[registry_index]
      )))) {
        stop("Dependence eligible match IDs differ from tuning_editions.csv", call. = FALSE)
      }
    }
  }
  ordering <- order(
    as.Date(eligible[[date_column]]), as.character(eligible$match_id),
    na.last = TRUE, method = "radix"
  )
  eligible <- eligible[ordering, , drop = FALSE]
  rownames(eligible) <- NULL
  list(
    history = eligible,
    tuning_rows = rows,
    inner_ids = inner_ids,
    inner_final = inner_final,
    date_column = date_column,
    outer_edition_id = outer_edition_id,
    outer_opener_date = outer_opener_date
  )
}

.dependence_dixon_coles_log_likelihood <- function(history, rho) {
  tau <- rep(1, nrow(history))
  home <- as.integer(history$home_goals)
  away <- as.integer(history$away_goals)
  mu_home <- as.numeric(history$mu_home)
  mu_away <- as.numeric(history$mu_away)
  tau[home == 0L & away == 0L] <- 1 - mu_home[home == 0L & away == 0L] *
    mu_away[home == 0L & away == 0L] * rho
  tau[home == 0L & away == 1L] <- 1 + mu_home[home == 0L & away == 1L] * rho
  tau[home == 1L & away == 0L] <- 1 + mu_away[home == 1L & away == 0L] * rho
  tau[home == 1L & away == 1L] <- 1 - rho
  if (any(!is.finite(tau)) || any(tau <= 0)) return(-Inf)
  sum(
    stats::dpois(home, mu_home, log = TRUE) +
      stats::dpois(away, mu_away, log = TRUE) + log(tau)
  )
}

.dependence_bivariate_log_likelihood <- function(history, q) {
  if (!is.finite(q) || q < 0 || q >= 0.95) return(-Inf)
  home <- as.integer(history$home_goals)
  away <- as.integer(history$away_goals)
  mu_home <- as.numeric(history$mu_home)
  mu_away <- as.numeric(history$mu_away)
  if (q == 0) {
    return(sum(
      stats::dpois(home, mu_home, log = TRUE) +
        stats::dpois(away, mu_away, log = TRUE)
    ))
  }
  values <- vapply(seq_len(nrow(history)), function(i) {
    kappa <- q * min(mu_home[i], mu_away[i])
    .bivariate_poisson_log_cell(
      home[i], away[i], mu_home[i] - kappa, mu_away[i] - kappa, kappa
    )
  }, numeric(1))
  sum(values)
}

#' Estimate one prior-only global dependence parameter per outer fold
#'
#' @return Two rows: one Dixon-Coles rho and one bivariate-Poisson q. Track and
#'   fixture identities are intentionally absent because parameters are frozen
#'   fold-global values.
#' @export
fit_fold_dependence_parameters <- function(
    history, outer_edition_id, outer_opener_date, tuning_editions,
    support_max = 40L
) {
  .dependence_require_columns(
    history,
    c(
      "match_id", "edition_id", "home_goals", "away_goals",
      "mu_home", "mu_away"
    ),
    "Dependence fitting history"
  )
  if (!nrow(history) || anyDuplicated(history$match_id) ||
      any(is.na(history$match_id) | !nzchar(as.character(history$match_id)))) {
    stop("Dependence fitting history requires unique nonmissing match IDs", call. = FALSE)
  }
  if (length(support_max) != 1L || !is.finite(support_max) ||
      support_max != 40 || support_max != as.integer(support_max)) {
    stop("Dependence fitting requires the sealed support_max of 40", call. = FALSE)
  }
  validated <- .dependence_validate_tuning(
    history, outer_edition_id, outer_opener_date, tuning_editions
  )
  training <- validated$history
  .dependence_require_means(training$mu_home, training$mu_away)
  training_goals <- c(training$home_goals, training$away_goals)
  if (any(!is.finite(training_goals)) || any(training_goals < 0) ||
      any(training_goals != as.integer(training_goals)) ||
      any(training_goals > support_max)) {
    stop("Eligible dependence goals must be finite counts within support 0:40", call. = FALSE)
  }

  rho_bounds <- .dixon_coles_rho_bounds(training$mu_home, training$mu_away)
  rho_span <- diff(rho_bounds)
  rho_search <- c(
    lower = rho_bounds[["lower"]] + rho_span * 1e-10,
    upper = rho_bounds[["upper"]] - rho_span * 1e-10
  )
  rho_fit <- stats::optimize(
    function(value) -.dependence_dixon_coles_log_likelihood(training, value),
    interval = rho_search
  )
  q_bounds <- c(lower = 0, upper = 0.95)
  q_fit <- stats::optimize(
    function(value) -.dependence_bivariate_log_likelihood(training, value),
    interval = c(q_bounds[["lower"]] + 1e-12, q_bounds[["upper"]] - 1e-12)
  )
  if (any(!is.finite(c(rho_fit$minimum, rho_fit$objective,
                       q_fit$minimum, q_fit$objective)))) {
    stop("Dependence parameter optimization did not converge to finite evidence", call. = FALSE)
  }

  training_ids <- sort(as.character(training$match_id), method = "radix")
  eligible_hash <- .dependence_sha256(paste(training_ids, collapse = "|"))
  training_hash <- .dependence_training_hash(training, validated$date_column)
  mean_rows <- data.frame(
    outer_edition_id = validated$outer_edition_id,
    track_id = "prior_tuning",
    boundary_id = paste0(validated$outer_edition_id, "__dependence_fit"),
    fixture_id = as.character(training$match_id),
    mu_home = as.numeric(training$mu_home),
    mu_away = as.numeric(training$mu_away),
    stringsAsFactors = FALSE
  )
  mean_hash <- statistical_mean_prediction_hash(mean_rows)
  training_dates <- as.Date(training[[validated$date_column]])
  result <- data.frame(
    outer_edition_id = validated$outer_edition_id,
    dependence_id = c("dixon_coles", "bivariate_poisson"),
    parameter_name = c("rho", "q"),
    parameter = c(rho_fit$minimum, q_fit$minimum),
    lower_bound = c(rho_bounds[["lower"]], q_bounds[["lower"]]),
    upper_bound = c(rho_bounds[["upper"]], q_bounds[["upper"]]),
    objective = c(rho_fit$objective, q_fit$objective),
    training_count = nrow(training),
    training_min_date = min(training_dates),
    training_max_date = max(training_dates),
    eligible_match_ids_sha256 = eligible_hash,
    training_data_sha256 = training_hash,
    mean_prediction_hash = mean_hash,
    eligible_edition_ids = paste(sort(validated$inner_ids, method = "radix"), collapse = "|"),
    training_match_ids = paste(training_ids, collapse = "|"),
    optimization_status = "converged",
    fallback_status = "none",
    stringsAsFactors = FALSE
  )
  result <- result[order(result$dependence_id, method = "radix"), , drop = FALSE]
  rownames(result) <- NULL
  result
}

#' Require exact shared mean identity before dependence grids are emitted
#'
#' @return TRUE invisibly.
#' @export
validate_shared_mean_hash <- function(siblings) {
  required <- c(
    "outer_edition_id", "dependence_id", "track_id", "fixture_id",
    "mean_prediction_hash"
  )
  .dependence_require_columns(siblings, required, "Dependence sibling rows")
  if (!nrow(siblings)) stop("Dependence sibling rows must not be empty", call. = FALSE)
  expected <- c("independent", "dixon_coles", "bivariate_poisson")
  if (any(!as.character(siblings$dependence_id) %in% expected)) {
    stop("Dependence sibling rows contain an unknown dependence family", call. = FALSE)
  }
  hashes <- tolower(as.character(siblings$mean_prediction_hash))
  if (any(!grepl("^[0-9a-f]{64}$", hashes))) {
    stop("Dependence sibling mean hashes must be canonical SHA-256", call. = FALSE)
  }
  siblings$mean_prediction_hash <- hashes
  identity <- c("outer_edition_id", "track_id")
  if ("boundary_id" %in% names(siblings)) identity <- c(identity, "boundary_id")
  identity <- c(identity, "fixture_id")
  keys <- do.call(paste, c(lapply(siblings[identity], as.character), sep = "|"))
  for (rows in split(siblings, keys)) {
    if (nrow(rows) != length(expected) || anyDuplicated(rows$dependence_id) ||
        !setequal(as.character(rows$dependence_id), expected) ||
        length(unique(rows$mean_prediction_hash)) != 1L) {
      stop("Dependence siblings must share one exact mean hash before grid generation", call. = FALSE)
    }
  }
  if ("parameter" %in% names(siblings)) {
    parameter_keys <- paste(
      as.character(siblings$outer_edition_id),
      as.character(siblings$dependence_id), sep = "|"
    )
    invalid <- vapply(split(siblings, parameter_keys), function(rows) {
      values <- as.numeric(rows$parameter)
      any(!is.finite(values)) || length(unique(values)) != 1L
    }, logical(1))
    if (any(invalid)) {
      stop("Dependence parameter must be one fold-global value, not track-specific", call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' Emit deterministic fold dependence evidence
#'
#' @export
score_dependence_manifest <- function(fit, history, outer_edition_id) {
  required <- c(
    "outer_edition_id", "dependence_id", "parameter", "lower_bound",
    "upper_bound", "objective", "training_count", "training_min_date",
    "training_max_date", "eligible_match_ids_sha256", "training_data_sha256",
    "mean_prediction_hash", "training_match_ids", "optimization_status",
    "fallback_status"
  )
  .dependence_require_columns(fit, required, "Dependence parameter fit")
  if ("track_id" %in% names(fit)) {
    stop("Dependence parameter fit must not contain track-specific rows", call. = FALSE)
  }
  outer_edition_id <- as.character(outer_edition_id)
  rows <- fit[as.character(fit$outer_edition_id) == outer_edition_id, , drop = FALSE]
  expected <- c("bivariate_poisson", "dixon_coles")
  if (nrow(rows) != 2L || anyDuplicated(rows$dependence_id) ||
      !setequal(as.character(rows$dependence_id), expected)) {
    stop("Dependence manifest requires one fitted row per outer-fold family", call. = FALSE)
  }
  if (any(rows$parameter <= rows$lower_bound | rows$parameter >= rows$upper_bound) ||
      any(rows$optimization_status != "converged") ||
      any(rows$fallback_status != "none")) {
    stop("Dependence manifest requires bounded converged fits without fallback", call. = FALSE)
  }
  .dependence_require_columns(history, c("match_id", "edition_id"), "Dependence manifest history")
  if (anyDuplicated(history$match_id)) {
    stop("Dependence manifest history contains duplicate match IDs", call. = FALSE)
  }
  training_ids <- strsplit(as.character(rows$training_match_ids[[1L]]), "|", fixed = TRUE)[[1L]]
  if (any(as.character(rows$training_match_ids) != rows$training_match_ids[[1L]]) ||
      !setequal(training_ids, as.character(history$match_id[history$match_id %in% training_ids]))) {
    stop("Dependence manifest cannot reconcile its prior training IDs", call. = FALSE)
  }
  training <- history[match(training_ids, as.character(history$match_id)), , drop = FALSE]
  date_column <- .dependence_history_date_column(training)
  if (!identical(
    .dependence_training_hash(training, date_column),
    as.character(rows$training_data_sha256[[1L]])
  )) {
    stop("Dependence manifest prior training evidence hash mismatch", call. = FALSE)
  }

  manifest <- rows[, c(
    "outer_edition_id", "dependence_id", "parameter", "lower_bound",
    "upper_bound", "objective", "training_count", "training_min_date",
    "training_max_date", "eligible_match_ids_sha256", "training_data_sha256",
    "mean_prediction_hash", "optimization_status", "fallback_status"
  ), drop = FALSE]
  manifest$package_versions <- paste0(
    "digest=", as.character(utils::packageVersion("digest")), ";stats=",
    as.character(utils::packageVersion("stats"))
  )
  manifest$r_version <- R.version.string
  manifest$manifest_sha256 <- ""
  manifest$manifest_sha256 <- .dependence_row_sha256(manifest, "manifest_sha256")
  manifest <- manifest[order(manifest$dependence_id, method = "radix"), , drop = FALSE]
  rownames(manifest) <- NULL
  manifest
}
