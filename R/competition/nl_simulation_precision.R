# Sampling uncertainty for Bernoulli events counted across independent seeded
# tournament runs. These are pointwise Monte Carlo intervals, not model-error
# bounds or simultaneous coverage for every displayed event.

uefa_nl_mc_policy <- function() {
  confidence <- 0.95
  half_width <- 0.01
  z <- stats::qnorm((1 + confidence) / 2)
  list(schema_version = "nl-monte-carlo-policy-v1", confidence = confidence,
    max_pointwise_half_width = half_width,
    minimum_simulations = as.integer(ceiling(z^2 / (4 * half_width^2) - z^2)),
    recommended_simulations = 10000L, interval_method = "wilson_score",
    coverage_scope = "pointwise_sampling_only")
}

uefa_nl_mc_precision <- function(simulation_count) {
  n <- suppressWarnings(as.numeric(simulation_count))
  if (length(n) != 1L || !is.finite(n) || n < 1 || n != floor(n))
    stop("Monte Carlo simulation count must be one positive integer", call. = FALSE)
  policy <- uefa_nl_mc_policy()
  z <- stats::qnorm((1 + policy$confidence) / 2)
  worst <- z / (2 * sqrt(n + z^2))
  c(policy, list(simulation_count = n, worst_case_half_width = worst,
    sufficient = worst <= policy$max_pointwise_half_width,
    status = if (worst <= policy$max_pointwise_half_width) "production_precision" else "preview_only"))
}

uefa_nl_mc_require_publication <- function(simulation_count) {
  precision <- uefa_nl_mc_precision(simulation_count)
  if (!isTRUE(precision$sufficient)) stop(sprintf(
    "Nations League publication needs at least %d simulations for a 95%% pointwise Monte Carlo half-width <=1 percentage point; %d is preview-only (worst-case +/-%.2f points)",
    precision$minimum_simulations, precision$simulation_count, 100 * precision$worst_case_half_width), call. = FALSE)
  invisible(precision)
}

uefa_nl_mc_interval <- function(probability, simulation_count) {
  precision <- uefa_nl_mc_precision(simulation_count)
  p <- suppressWarnings(as.numeric(probability))
  known <- !is.na(p)
  if (any(known & (!is.finite(p) | p < 0 | p > 1)))
    stop("Monte Carlo probability must be unavailable or within [0,1]", call. = FALSE)
  n <- precision$simulation_count
  successes <- round(p * n)
  if (any(known & abs(p * n - successes) > 1e-6))
    stop("Monte Carlo probability does not represent a counted simulation event", call. = FALSE)
  estimate <- successes / n
  z <- stats::qnorm((1 + precision$confidence) / 2)
  denominator <- 1 + z^2 / n
  centre <- (estimate + z^2 / (2 * n)) / denominator
  width <- z * sqrt(estimate * (1 - estimate) / n + z^2 / (4 * n^2)) / denominator
  data.frame(estimate = estimate, count = successes, simulation_count = n,
    mc_standard_error = sqrt(estimate * (1 - estimate) / n),
    mc_lower_95 = pmax(0, centre - width), mc_upper_95 = pmin(1, centre + width),
    stringsAsFactors = FALSE)
}
