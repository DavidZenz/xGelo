#' Proper scoring rules for football forecasts

validate_probability_vector <- function(probabilities, tolerance = 1e-6, name = "probabilities") {
  probabilities <- as.numeric(probabilities)
  if (!length(probabilities) || any(!is.finite(probabilities))) {
    stop(name, " must contain finite values", call. = FALSE)
  }
  if (any(probabilities < 0 | probabilities > 1)) {
    stop(name, " must lie in [0, 1]", call. = FALSE)
  }
  if (abs(sum(probabilities) - 1) > tolerance) {
    stop(name, " must sum to one within tolerance", call. = FALSE)
  }
  probabilities
}

validate_observed_class <- function(observed, classes) {
  if (length(observed) != 1L || is.na(observed) || !observed %in% classes) {
    stop("observed must identify exactly one forecast class", call. = FALSE)
  }
  match(observed, classes)
}

#' Multiclass Brier score
#'
#' @param probabilities Named class probabilities.
#' @param observed Observed class name.
#' @return Sum of squared probability errors across classes.
#' @export
multiclass_brier <- function(probabilities, observed, tolerance = 1e-6) {
  classes <- names(probabilities)
  if (is.null(classes) || any(!nzchar(classes)) || anyDuplicated(classes)) {
    stop("probabilities must have unique class names", call. = FALSE)
  }
  probabilities <- validate_probability_vector(probabilities, tolerance)
  index <- validate_observed_class(observed, classes)
  actual <- numeric(length(probabilities))
  actual[index] <- 1
  sum((probabilities - actual)^2)
}

#' Ranked probability score
#'
#' The class order is fixed to home, draw, away for 1X2 forecasts. The score is
#' normalized by the number of non-trivial cumulative boundaries.
#' @export
ranked_probability_score <- function(probabilities, observed, order = c("home", "draw", "away"),
                                     tolerance = 1e-6) {
  if (is.null(names(probabilities)) || !setequal(names(probabilities), order)) {
    stop("probabilities must be named for every ordered class", call. = FALSE)
  }
  probabilities <- validate_probability_vector(probabilities[order], tolerance)
  index <- validate_observed_class(observed, order)
  actual <- numeric(length(order))
  actual[index] <- 1
  mean((cumsum(probabilities)[-length(order)] - cumsum(actual)[-length(order)])^2)
}

#' Logarithmic score
#' @export
log_score <- function(probabilities, observed, epsilon = 1e-15, tolerance = 1e-6) {
  classes <- names(probabilities)
  if (is.null(classes) || any(!nzchar(classes)) || anyDuplicated(classes)) {
    stop("probabilities must have unique class names", call. = FALSE)
  }
  probabilities <- validate_probability_vector(probabilities, tolerance)
  index <- validate_observed_class(observed, classes)
  -log(max(probabilities[index], epsilon))
}

#' Binary Brier score
#' @export
binary_brier <- function(probability, observed) {
  if (length(probability) != 1L || !is.finite(probability) || probability < 0 || probability > 1) {
    stop("probability must be one finite value in [0, 1]", call. = FALSE)
  }
  if (length(observed) != 1L || is.na(observed) || !observed %in% c(0, 1, FALSE, TRUE)) {
    stop("observed must be binary", call. = FALSE)
  }
  (probability - as.numeric(observed))^2
}

#' RPS for a discrete ordered distribution
#' @export
discrete_rps <- function(probabilities, observed, support = NULL, tolerance = 1e-6) {
  probabilities <- validate_probability_vector(probabilities, tolerance)
  if (is.null(support)) support <- seq_along(probabilities) - 1L
  if (length(support) != length(probabilities) || anyDuplicated(support)) {
    stop("support must contain one unique value per probability", call. = FALSE)
  }
  ordering <- order(support)
  support <- support[ordering]
  probabilities <- probabilities[ordering]
  index <- match(observed, support)
  if (is.na(index)) stop("observed value is absent from distribution support", call. = FALSE)
  actual <- numeric(length(support))
  actual[index] <- 1
  sum((cumsum(probabilities)[-length(probabilities)] - cumsum(actual)[-length(actual)])^2)
}

validate_scoreline_distribution <- function(distribution, tolerance = 1e-6) {
  required <- c("home_goals", "away_goals", "probability")
  missing <- setdiff(required, names(distribution))
  if (length(missing)) stop("scoreline distribution missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(distribution)) stop("scoreline distribution must not be empty", call. = FALSE)
  if (any(!is.finite(distribution$home_goals)) || any(!is.finite(distribution$away_goals)) ||
      any(distribution$home_goals < 0) || any(distribution$away_goals < 0)) {
    stop("scoreline goals must be finite non-negative values", call. = FALSE)
  }
  keys <- paste(distribution$home_goals, distribution$away_goals, sep = "-")
  if (anyDuplicated(keys)) stop("scoreline distribution contains duplicate cells", call. = FALSE)
  distribution$probability <- validate_probability_vector(
    distribution$probability, tolerance, "scoreline probabilities"
  )
  distribution
}

#' Derive goal marginals and binary markets from a complete joint distribution
#' @export
derive_binary_markets <- function(distribution, tolerance = 1e-6) {
  distribution <- validate_scoreline_distribution(distribution, tolerance)
  home_support <- seq.int(0L, max(distribution$home_goals))
  away_support <- seq.int(0L, max(distribution$away_goals))
  home <- vapply(home_support, function(x) sum(distribution$probability[distribution$home_goals == x]), numeric(1))
  away <- vapply(away_support, function(x) sum(distribution$probability[distribution$away_goals == x]), numeric(1))
  list(
    home_support = home_support,
    home_probabilities = home,
    away_support = away_support,
    away_probabilities = away,
    p_over_2_5 = sum(distribution$probability[distribution$home_goals + distribution$away_goals > 2]),
    p_btts = sum(distribution$probability[distribution$home_goals > 0 & distribution$away_goals > 0])
  )
}

#' Score a complete joint scoreline distribution
#' @export
score_scoreline_distribution <- function(distribution, observed_home, observed_away,
                                         epsilon = 1e-15, tolerance = 1e-6) {
  distribution <- validate_scoreline_distribution(distribution, tolerance)
  observed <- distribution$home_goals == observed_home & distribution$away_goals == observed_away
  if (!any(observed)) stop("observed scoreline cell is absent from distribution", call. = FALSE)
  markets <- derive_binary_markets(distribution, tolerance)
  observed_probability <- distribution$probability[observed]
  modal <- distribution[which.max(distribution$probability), , drop = FALSE]
  list(
    joint_log_score = -log(max(observed_probability, epsilon)),
    home_goal_rps = discrete_rps(markets$home_probabilities, observed_home, markets$home_support, tolerance),
    away_goal_rps = discrete_rps(markets$away_probabilities, observed_away, markets$away_support, tolerance),
    p_over_2_5 = markets$p_over_2_5,
    p_btts = markets$p_btts,
    exact_score_hit = as.integer(modal$home_goals == observed_home && modal$away_goals == observed_away)
  )
}
