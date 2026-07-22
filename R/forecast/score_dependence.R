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
