#' Registered Phase 09 benchmark baseline adapters

benchmark_baseline_date_column <- function(data) {
  candidates <- c("actual_completion_date", "date")
  found <- candidates[candidates %in% names(data)]
  if (!length(found)) stop("Benchmark training data require a date column", call. = FALSE)
  found[[1]]
}

benchmark_baseline_response_columns <- function(data) {
  home <- if ("home_goals" %in% names(data)) "home_goals" else "regulation_home_goals"
  away <- if ("away_goals" %in% names(data)) "away_goals" else "regulation_away_goals"
  if (!all(c(home, away) %in% names(data))) stop("Benchmark training data require home and away goals", call. = FALSE)
  c(home = home, away = away)
}

benchmark_baseline_training_rows <- function(history, cutoff = NULL) {
  if (!is.data.frame(history) || !nrow(history)) stop("Benchmark history must be a non-empty data frame", call. = FALSE)
  date_col <- benchmark_baseline_date_column(history)
  history[[date_col]] <- as.Date(history[[date_col]])
  if (!is.null(cutoff)) history <- history[!is.na(history[[date_col]]) & history[[date_col]] < as.Date(cutoff), , drop = FALSE]
  response <- benchmark_baseline_response_columns(history)
  keep <- is.finite(suppressWarnings(as.numeric(history[[response[["home"]]]]))) &
    is.finite(suppressWarnings(as.numeric(history[[response[["away"]]]])))
  history <- history[keep, , drop = FALSE]
  if (!nrow(history)) stop("No eligible benchmark history remains before the cutoff", call. = FALSE)
  history
}

benchmark_score_outcome <- function(home_goals, away_goals) {
  ifelse(home_goals > away_goals, "home", ifelse(home_goals == away_goals, "draw", "away"))
}

benchmark_fit_control <- function(history, cutoff, support_max, uniform) {
  history <- benchmark_baseline_training_rows(history, cutoff)
  date_col <- benchmark_baseline_date_column(history)
  response <- benchmark_baseline_response_columns(history)
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max < 0L) stop("support_max must be non-negative", call. = FALSE)
  weights <- if (uniform) {
    rep(1, nrow(history))
  } else {
    weight_cutoff <- if (is.null(cutoff)) max(as.Date(history[[date_col]])) + 1L else as.Date(cutoff)
    benchmark_observation_weights(history, weight_cutoff)
  }
  home <- as.integer(history[[response[["home"]]]])
  away <- as.integer(history[[response[["away"]]]])
  observed_outcome <- benchmark_score_outcome(home, away)
  outcomes <- c("home", "draw", "away")
  outcome_mass <- if (uniform) {
    setNames(rep(1 / 3, 3), outcomes)
  } else {
    totals <- vapply(outcomes, function(x) sum(weights[observed_outcome == x]), numeric(1)) + 0.5
    totals / sum(totals)
  }
  grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
  grid$outcome <- benchmark_score_outcome(grid$home_goals, grid$away_goals)
  grid$conditional_weight <- 0.5
  inside <- home <= support_max & away <= support_max
  if (any(inside)) {
    index <- match(
      paste(home[inside], away[inside]),
      paste(grid$home_goals, grid$away_goals)
    )
    additions <- rowsum(weights[inside], index, reorder = FALSE)
    grid$conditional_weight[as.integer(rownames(additions))] <-
      grid$conditional_weight[as.integer(rownames(additions))] + additions[, 1]
  }
  conditional_total <- ave(grid$conditional_weight, grid$outcome, FUN = sum)
  grid$probability <- grid$conditional_weight / conditional_total * outcome_mass[grid$outcome]
  omitted <- if (sum(weights) > 0) sum(weights[!inside]) / sum(weights) else 0
  structure(list(
    model_id = if (uniform) "uniform_1x2" else "expanding_1x2",
    model_family = "empirical_control",
    panel_id = "open_core",
    support_max = support_max,
    score_grid = grid[, c("home_goals", "away_goals", "probability")],
    raw_tail_mass = omitted,
    outcome_mass = outcome_mass,
    training_dates = as.Date(history[[date_col]]),
    fit_row_count = nrow(history),
    active_predictors = "score_history",
    dropped_predictors = character(),
    converged = TRUE,
    convergence_status = "not_applicable",
    fallback_status = "none",
    recursive_elo_weighting = "not_applicable"
  ), class = "benchmark_baseline_fit")
}

#' Fit the exact one-third outcome control
#' @export
fit_uniform_1x2 <- function(history, cutoff = NULL, support_max = 40L, ...) {
  benchmark_fit_control(history, cutoff, support_max, uniform = TRUE)
}

#' Fit the weighted expanding empirical control
#' @export
fit_expanding_1x2 <- function(history, cutoff = NULL, support_max = 40L, ...) {
  benchmark_fit_control(history, cutoff, support_max, uniform = FALSE)
}

benchmark_glm_nb <- function(formula, data, weights, label) {
  if (!requireNamespace("MASS", quietly = TRUE)) stop("MASS is required for registered negative-binomial baselines", call. = FALSE)
  fit <- tryCatch(
    do.call(MASS::glm.nb, list(
      formula = formula, data = data, weights = as.numeric(weights),
      control = stats::glm.control(maxit = 50)
    )),
    error = function(error) structure(list(error = conditionMessage(error)), class = "benchmark_nb_error")
  )
  if (inherits(fit, "benchmark_nb_error")) stop(label, " negative-binomial fit failed: ", fit$error, call. = FALSE)
  if (!isTRUE(fit$converged) || !is.finite(fit$theta) || fit$theta <= 0) {
    stop(label, " negative-binomial fit did not converge", call. = FALSE)
  }
  fit
}

benchmark_numeric_predictors <- function(data, candidates) {
  available <- intersect(candidates, names(data))
  active <- available[vapply(data[available], function(value) {
    value <- suppressWarnings(as.numeric(value))
    finite <- value[is.finite(value)]
    length(finite) > 1L && stats::sd(finite) > 0
  }, logical(1))]
  list(active = active, dropped = setdiff(candidates, active))
}

benchmark_fit_two_sided_nb <- function(history, cutoff, candidates, model_id, panel_id, observation_weights = NULL) {
  history <- benchmark_baseline_training_rows(history, cutoff)
  date_col <- benchmark_baseline_date_column(history)
  response <- benchmark_baseline_response_columns(history)
  predictors <- benchmark_numeric_predictors(history, candidates)
  if (!length(predictors$active)) stop(model_id, " has no active registered predictors", call. = FALSE)
  model_data <- history[, unique(c(unname(response), predictors$active)), drop = FALSE]
  for (column in c(unname(response), predictors$active)) model_data[[column]] <- suppressWarnings(as.numeric(model_data[[column]]))
  complete <- stats::complete.cases(model_data)
  model_data <- model_data[complete, , drop = FALSE]
  history <- history[complete, , drop = FALSE]
  if (nrow(model_data) < length(predictors$active) + 5L) stop(model_id, " has insufficient complete rows", call. = FALSE)
  if (is.null(observation_weights)) {
    weight_cutoff <- if (is.null(cutoff)) max(as.Date(history[[date_col]])) + 1L else as.Date(cutoff)
    observation_weights <- benchmark_observation_weights(history, weight_cutoff)
  } else {
    observation_weights <- as.numeric(observation_weights)[complete]
    if (length(observation_weights) != nrow(model_data)) stop("observation_weights length mismatch", call. = FALSE)
    observation_weights <- observation_weights / mean(observation_weights)
  }
  home_formula <- stats::reformulate(predictors$active, response = response[["home"]])
  away_formula <- stats::reformulate(predictors$active, response = response[["away"]])
  home_fit <- benchmark_glm_nb(home_formula, model_data, observation_weights, paste(model_id, "home"))
  away_fit <- benchmark_glm_nb(away_formula, model_data, observation_weights, paste(model_id, "away"))
  structure(list(
    model_id = model_id, model_family = "negative_binomial", panel_id = panel_id,
    home_model = home_fit, away_model = away_fit,
    active_predictors = predictors$active,
    dropped_predictors = predictors$dropped,
    training_dates = as.Date(history[[date_col]]), fit_row_count = nrow(history),
    converged = TRUE, convergence_status = "converged", fallback_status = "none",
    recursive_elo_weighting = "not_applied"
  ), class = "benchmark_baseline_fit")
}

#' Fit the D-12 point-in-time Elo-only negative-binomial baseline
#' @export
fit_elo_goal_nb <- function(history, cutoff = NULL, observation_weights = NULL, ...) {
  history <- benchmark_baseline_training_rows(history, cutoff)
  if (!all(c("elo_diff", "venue_role") %in% names(history))) {
    stop("Elo-only NB requires elo_diff and venue_role", call. = FALSE)
  }
  response <- benchmark_baseline_response_columns(history)
  date_col <- benchmark_baseline_date_column(history)
  n <- nrow(history)
  long <- rbind(
    data.frame(
      goals = as.numeric(history[[response[["home"]]]]),
      elo_difference_for_team = as.numeric(history$elo_diff),
      venue_advantage_for_team = as.integer(history$venue_role == "home")
    ),
    data.frame(
      goals = as.numeric(history[[response[["away"]]]]),
      elo_difference_for_team = -as.numeric(history$elo_diff),
      venue_advantage_for_team = as.integer(history$venue_role == "away")
    )
  )
  weights <- if (is.null(observation_weights)) {
    weight_cutoff <- if (is.null(cutoff)) max(as.Date(history[[date_col]])) + 1L else as.Date(cutoff)
    benchmark_observation_weights(history, weight_cutoff)
  } else {
    as.numeric(observation_weights)
  }
  if (length(weights) != n || any(!is.finite(weights) | weights <= 0)) stop("observation_weights length mismatch", call. = FALSE)
  weights <- rep(weights / mean(weights), 2L)
  model <- benchmark_glm_nb(
    goals ~ elo_difference_for_team + venue_advantage_for_team,
    long, weights, "elo_goal_nb"
  )
  structure(list(
    model_id = "elo_goal_nb", model_family = "negative_binomial", panel_id = "open_core",
    team_model = model,
    active_predictors = c("elo_difference_for_team", "venue_advantage_for_team"),
    dropped_predictors = character(), training_dates = as.Date(history[[date_col]]),
    fit_row_count = n, converged = TRUE, convergence_status = "converged",
    fallback_status = "none", recursive_elo_weighting = "not_applied"
  ), class = "benchmark_baseline_fit")
}

#' Fit the registered open-data incumbent
#' @export
fit_open_nb_incumbent <- function(history, cutoff = NULL, observation_weights = NULL, ...) {
  if (!exists("baseline_goal_predictors", mode = "function")) source("R/forecast/poisson.R")
  benchmark_fit_two_sided_nb(
    history, cutoff, baseline_goal_predictors(), "open_nb_incumbent", "open_core", observation_weights
  )
}

#' Fit the registered feature-rich production incumbent
#' @export
fit_production_hybrid_nb <- function(history, cutoff = NULL, observation_weights = NULL, ...) {
  if (!exists("hybrid_goal_predictors", mode = "function")) source("R/forecast/poisson.R")
  benchmark_fit_two_sided_nb(
    history, cutoff, hybrid_goal_predictors(), "production_hybrid_nb", "feature_rich", observation_weights
  )
}

benchmark_registry_logical <- function(value) {
  isTRUE(value) || identical(tolower(as.character(value)), "true")
}

#' Dispatch one immutable registered baseline fit
#' @export
fit_registered_baseline <- function(
    registration, history, cutoff = NULL, frozen_registry = NULL,
    support_max = NULL, observation_weights = NULL
) {
  if (!is.data.frame(registration) || nrow(registration) != 1L) stop("registration must contain exactly one model row", call. = FALSE)
  if (benchmark_registry_logical(registration$fold_specific_tuning_allowed)) {
    stop("Fold-specific tuning is forbidden by D-14", call. = FALSE)
  }
  if (!is.null(frozen_registry)) {
    frozen <- frozen_registry[frozen_registry$model_id == registration$model_id, , drop = FALSE]
    if (nrow(frozen) != 1L) stop("Frozen model registration is missing", call. = FALSE)
    if (as.character(registration$registration_sha256) != as.character(frozen$registration_sha256)) {
      stop("registration hash drift", call. = FALSE)
    }
    if (as.character(registration$settings_sha256) != as.character(frozen$settings_sha256)) {
      stop("settings hash drift", call. = FALSE)
    }
  }
  if (is.null(support_max)) support_max <- as.integer(registration$candidate_max)
  fit <- switch(
    as.character(registration$model_id),
    uniform_1x2 = fit_uniform_1x2(history, cutoff, support_max),
    expanding_1x2 = fit_expanding_1x2(history, cutoff, support_max),
    elo_goal_nb = fit_elo_goal_nb(history, cutoff, observation_weights),
    open_nb_incumbent = fit_open_nb_incumbent(history, cutoff, observation_weights),
    production_hybrid_nb = fit_production_hybrid_nb(history, cutoff, observation_weights),
    stop("Unknown registered baseline model_id", call. = FALSE)
  )
  fit$adapter_version <- as.character(registration$adapter_version)
  fit$registration_sha256 <- as.character(registration$registration_sha256)
  fit$settings_sha256 <- as.character(registration$settings_sha256)
  fit$panel_id <- as.character(registration$panel_id)
  fit
}

benchmark_nb_means <- function(fit, fixtures) {
  if (fit$model_id == "elo_goal_nb") {
    if (!all(c("elo_diff", "venue_role") %in% names(fixtures))) stop("Elo prediction fixtures require elo_diff and venue_role", call. = FALSE)
    home <- data.frame(
      elo_difference_for_team = as.numeric(fixtures$elo_diff),
      venue_advantage_for_team = as.integer(fixtures$venue_role == "home")
    )
    away <- data.frame(
      elo_difference_for_team = -as.numeric(fixtures$elo_diff),
      venue_advantage_for_team = as.integer(fixtures$venue_role == "away")
    )
    return(list(
      home = as.numeric(stats::predict(fit$team_model, home, type = "response")),
      away = as.numeric(stats::predict(fit$team_model, away, type = "response")),
      home_theta = fit$team_model$theta, away_theta = fit$team_model$theta
    ))
  }
  missing <- setdiff(fit$active_predictors, names(fixtures))
  if (length(missing)) stop("Prediction fixtures are missing active predictors: ", paste(missing, collapse = ", "), call. = FALSE)
  data <- fixtures[, fit$active_predictors, drop = FALSE]
  list(
    home = as.numeric(stats::predict(fit$home_model, data, type = "response")),
    away = as.numeric(stats::predict(fit$away_model, data, type = "response")),
    home_theta = fit$home_model$theta, away_theta = fit$away_model$theta
  )
}

benchmark_one_distribution <- function(id, home_probability, away_probability, raw_tail, support_max) {
  grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
  raw <- outer(home_probability, away_probability)
  grid$score_distribution_id <- id
  grid$probability <- as.vector(raw / sum(raw))
  grid$support_max_home <- support_max
  grid$support_max_away <- support_max
  grid$raw_tail_mass <- raw_tail
  grid$normalized <- TRUE
  grid[, c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )]
}

#' Predict complete registered score distributions and derived markets
#' @export
predict_registered_baseline <- function(fit, fixtures, support_max = NULL) {
  if (!inherits(fit, "benchmark_baseline_fit")) stop("fit is not a registered benchmark baseline", call. = FALSE)
  if (!is.data.frame(fixtures) || !nrow(fixtures) || !"fixture_id" %in% names(fixtures)) {
    stop("fixtures require fixture_id rows", call. = FALSE)
  }
  if (is.null(support_max)) support_max <- if (!is.null(fit$support_max)) fit$support_max else 40L
  support_max <- as.integer(support_max)
  distributions <- vector("list", nrow(fixtures))
  if (fit$model_family == "empirical_control") {
    source_grid <- fit$score_grid
    if (fit$support_max != support_max) stop("Control support differs from fitted registered support", call. = FALSE)
    for (i in seq_len(nrow(fixtures))) {
      grid <- source_grid
      grid$score_distribution_id <- paste0(fixtures$fixture_id[i], "__score")
      grid$support_max_home <- support_max
      grid$support_max_away <- support_max
      grid$raw_tail_mass <- fit$raw_tail_mass
      grid$normalized <- TRUE
      distributions[[i]] <- grid[, c(
        "score_distribution_id", "home_goals", "away_goals", "probability",
        "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
      )]
    }
  } else {
    means <- benchmark_nb_means(fit, fixtures)
    goals <- 0:support_max
    for (i in seq_len(nrow(fixtures))) {
      home_probability <- stats::dnbinom(goals, size = means$home_theta, mu = means$home[i])
      away_probability <- stats::dnbinom(goals, size = means$away_theta, mu = means$away[i])
      raw_tail <- max(0, 1 - sum(home_probability) * sum(away_probability))
      distributions[[i]] <- benchmark_one_distribution(
        paste0(fixtures$fixture_id[i], "__score"), home_probability, away_probability,
        raw_tail, support_max
      )
    }
  }
  predictions <- do.call(rbind, lapply(seq_len(nrow(fixtures)), function(i) {
    grid <- distributions[[i]]
    id <- as.character(grid$score_distribution_id[1])
    market <- derive_benchmark_markets(grid)
    data.frame(
      fixture_id = fixtures$fixture_id[i], score_distribution_id = id,
      as.data.frame(market, stringsAsFactors = FALSE), stringsAsFactors = FALSE
    )
  }))
  distributions <- do.call(rbind, distributions)
  rownames(distributions) <- NULL
  list(predictions = predictions, distributions = distributions)
}

benchmark_manifest_rows <- function(fit, registration, fixtures, history, run_id) {
  date_col <- benchmark_baseline_date_column(history)
  dates <- as.Date(history[[date_col]])
  boundaries <- unique(fixtures[c("edition_id", "track_id", "boundary_id", "evidence_cutoff_exclusive")])
  do.call(rbind, lapply(seq_len(nrow(boundaries)), function(i) {
    cutoff <- as.Date(boundaries$evidence_cutoff_exclusive[i])
    eligible <- dates[!is.na(dates) & dates < cutoff]
    data.frame(
      model_manifest_id = paste(run_id, registration$model_id, boundaries$boundary_id[i], sep = "__"),
      run_id = run_id, model_id = registration$model_id,
      edition_id = boundaries$edition_id[i], track_id = boundaries$track_id[i],
      boundary_id = boundaries$boundary_id[i], fit_status = "ok",
      fit_row_count = length(eligible), fit_min_date = min(eligible), fit_max_date = max(eligible),
      max_result_date = max(eligible), max_feature_source_date = max(eligible),
      evidence_cutoff_exclusive = cutoff,
      active_predictors = paste(fit$active_predictors, collapse = "|"),
      dropped_predictors_with_reason = paste(fit$dropped_predictors, collapse = "missing_or_zero_variance|"),
      model_family = fit$model_family, convergence_status = fit$convergence_status,
      fallback_status = fit$fallback_status, adapter_version = registration$adapter_version,
      code_version = "phase09-v1", r_version = as.character(getRversion()),
      package_versions = paste0("MASS=", as.character(utils::packageVersion("MASS"))),
      registration_sha256 = registration$registration_sha256,
      settings_sha256 = registration$settings_sha256,
      parent_hashes = benchmark_contract_sha256(c(registration$registration_sha256, registration$settings_sha256, boundaries$boundary_id[i])),
      stringsAsFactors = FALSE
    )
  }))
}

#' Run one registered baseline through the common output contract
#' @export
run_registered_baseline_adapter <- function(
    registration, history, fixtures, seed_registry, support_max,
    run_id = "benchmark_run", frozen_registry = NULL
) {
  validate_seed_registry(seed_registry)
  required_fixture <- c(
    "edition_id", "track_id", "fixture_id", "boundary_id", "forecast_sequence",
    "home_team_id", "away_team_id", "venue_role", "actual_completion_date",
    "evidence_cutoff_exclusive", "result_cutoff_exclusive"
  )
  benchmark_contract_require_columns(fixtures, required_fixture, "Adapter fixtures")
  seed_index <- match(fixtures$fixture_id, seed_registry$fixture_id)
  if (any(is.na(seed_index))) stop("Adapter fixtures are missing model-independent seeds", call. = FALSE)
  pieces <- lapply(split(seq_len(nrow(fixtures)), fixtures$boundary_id), function(index) {
    boundary_fixtures <- fixtures[index, , drop = FALSE]
    cutoff <- unique(as.Date(boundary_fixtures$evidence_cutoff_exclusive))
    if (length(cutoff) != 1L) stop("Boundary fixtures contain inconsistent cutoffs", call. = FALSE)
    fit <- fit_registered_baseline(
      registration, history, cutoff, frozen_registry = frozen_registry,
      support_max = support_max
    )
    prediction <- predict_registered_baseline(fit, boundary_fixtures, support_max)
    list(fit = fit, fixtures = boundary_fixtures, result = prediction)
  })
  distributions <- do.call(rbind, lapply(pieces, function(x) x$result$distributions))
  predictions <- do.call(rbind, lapply(pieces, function(piece) {
    base <- piece$fixtures
    market <- piece$result$predictions[match(base$fixture_id, piece$result$predictions$fixture_id), , drop = FALSE]
    seed <- seed_registry[match(base$fixture_id, seed_registry$fixture_id), , drop = FALSE]
    manifest_id <- paste(run_id, registration$model_id, base$boundary_id, sep = "__")
    data.frame(
      schema_version = "1.0", run_id = run_id, model_id = registration$model_id,
      panel_id = registration$panel_id, edition_id = base$edition_id, track_id = base$track_id,
      fixture_id = base$fixture_id, boundary_id = base$boundary_id,
      forecast_sequence = base$forecast_sequence, home_team_id = base$home_team_id,
      away_team_id = base$away_team_id, venue_role = base$venue_role,
      evidence_cutoff_exclusive = as.Date(base$evidence_cutoff_exclusive),
      result_cutoff_exclusive = as.Date(base$result_cutoff_exclusive),
      model_manifest_id = manifest_id,
      feature_coverage_id = paste(run_id, registration$model_id, base$fixture_id, sep = "__"),
      seed_id = seed$seed_id, score_distribution_id = market$score_distribution_id,
      p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      p_over_2_5 = market$p_over_2_5, p_under_2_5 = market$p_under_2_5,
      p_btts = market$p_btts, modal_home_goals = market$modal_home_goals,
      modal_away_goals = market$modal_away_goals,
      modal_score_probability = market$modal_score_probability,
      prediction_status = "ok", failure_reason = "", stringsAsFactors = FALSE
    )
  }))
  manifests <- do.call(rbind, lapply(pieces, function(piece) {
    benchmark_manifest_rows(piece$fit, registration, piece$fixtures, history, run_id)
  }))
  manifests <- manifests[!duplicated(manifests$model_manifest_id), , drop = FALSE]
  validate_model_manifests(manifests)
  list(predictions = predictions, distributions = distributions, manifests = manifests)
}

#' Build observed post-prediction panel coverage without changing declarations
#' @export
benchmark_output_coverage <- function(predictions, panel_fixtures, model_id, coverage_floor) {
  required <- panel_fixtures[panel_fixtures$eligible & panel_fixtures$output_coverage_required, , drop = FALSE]
  rows <- predictions[predictions$model_id == model_id, , drop = FALSE]
  editions <- unique(required$edition_id)
  result <- do.call(rbind, lapply(editions, function(edition) {
    declared <- required[required$edition_id == edition, , drop = FALSE]
    observed <- rows[rows$fixture_id %in% declared$fixture_id & rows$prediction_status == "ok", , drop = FALSE]
    coverage <- length(unique(observed$fixture_id)) / nrow(declared)
    provenance <- all(declared$point_in_time_provenance_complete)
    data.frame(
      model_id = model_id, panel_id = unique(declared$panel_id), edition_id = edition,
      required_fixture_count = nrow(declared), observed_fixture_count = length(unique(observed$fixture_id)),
      output_coverage = coverage, output_coverage_complete = coverage == 1,
      provenance_complete = provenance,
      promotion_eligible = provenance && coverage >= coverage_floor && coverage == 1,
      stringsAsFactors = FALSE
    )
  }))
  rownames(result) <- NULL
  result
}

#' Construct a canonical complete global score-support audit
#' @export
build_score_support_audit <- function(model_registry, boundary_inventory, tail_evaluator) {
  if (!is.function(tail_evaluator)) stop("tail_evaluator must be a function", call. = FALSE)
  rows <- vector("list", nrow(model_registry) * nrow(boundary_inventory))
  cursor <- 0L
  for (m in seq_len(nrow(model_registry))) {
    for (b in seq_len(nrow(boundary_inventory))) {
      cursor <- cursor + 1L
      candidates <- seq.int(model_registry$candidate_min[m], model_registry$candidate_max[m])
      tails <- vapply(candidates, function(candidate) {
        as.numeric(tail_evaluator(
          model_registry$model_id[m], boundary_inventory$edition_id[b],
          boundary_inventory$track_id[b], boundary_inventory$boundary_id[b], candidate
        ))
      }, numeric(1))
      rows[[cursor]] <- data.frame(
        model_id = model_registry$model_id[m], edition_id = boundary_inventory$edition_id[b],
        track_id = boundary_inventory$track_id[b], boundary_id = boundary_inventory$boundary_id[b],
        candidate_g = candidates, raw_omitted_tail = tails,
        tolerance = model_registry$raw_tail_tolerance[m],
        pass = tails <= model_registry$raw_tail_tolerance[m],
        registration_sha256 = model_registry$registration_sha256[m],
        settings_sha256 = model_registry$settings_sha256[m],
        boundary_sha256 = boundary_inventory$boundary_sha256[b], stringsAsFactors = FALSE
      )
    }
  }
  enriched <- do.call(rbind, rows)
  if (any(!is.finite(enriched$raw_omitted_tail) | enriched$raw_omitted_tail < 0)) {
    stop("Score support evaluator returned invalid tails", call. = FALSE)
  }
  globally_passing <- as.integer(names(Filter(
    isTRUE,
    lapply(split(enriched$pass, enriched$candidate_g), all)
  )))
  if (!length(globally_passing)) stop("No globally valid score support candidate exists", call. = FALSE)
  enriched$selected_g <- min(globally_passing)
  enriched$parent_hashes <- benchmark_support_parent_sha256(enriched)
  audit <- enriched[, c(
    "model_id", "edition_id", "track_id", "boundary_id", "candidate_g",
    "raw_omitted_tail", "tolerance", "pass", "selected_g", "parent_hashes"
  )]
  audit <- audit[order(audit$model_id, audit$edition_id, audit$track_id, audit$boundary_id, audit$candidate_g), , drop = FALSE]
  rownames(audit) <- NULL
  audit$row_hash <- ""
  audit$row_hash <- benchmark_row_sha256(audit, "row_hash")
  validate_score_support_audit(audit, model_registry, boundary_inventory)
  audit
}

#' Build the frozen Phase 09 raw-tail evaluator
#'
#' Empirical controls use their actual expanding history at each exclusive
#' boundary. Registered NB families use a conservative analytic envelope
#' (mu 5, theta 8), which dominates the observed registered-fixture envelope
#' (mu below 3 and theta above 7.9) and resolves within the frozen 8:40 range.
#' @export
registered_score_support_tail_evaluator <- function(
    history, boundaries, nb_mu_bound = 5, nb_theta_bound = 8
) {
  if (!is.data.frame(boundaries) || !all(c("boundary_id", "evidence_cutoff_exclusive") %in% names(boundaries))) {
    stop("boundaries require boundary_id and evidence_cutoff_exclusive", call. = FALSE)
  }
  history <- benchmark_baseline_training_rows(history)
  date_col <- benchmark_baseline_date_column(history)
  response <- benchmark_baseline_response_columns(history)
  history[[date_col]] <- as.Date(history[[date_col]])
  cache <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(boundaries))) {
    boundary_id <- as.character(boundaries$boundary_id[i])
    cutoff <- as.Date(boundaries$evidence_cutoff_exclusive[i])
    rows <- history[history[[date_col]] < cutoff, , drop = FALSE]
    if (!nrow(rows)) stop("Score-support boundary has no eligible history", call. = FALSE)
    uniform_weights <- rep(1, nrow(rows))
    expanding_weights <- benchmark_observation_weights(rows, cutoff)
    home <- as.numeric(rows[[response[["home"]]]])
    away <- as.numeric(rows[[response[["away"]]]])
    for (candidate_g in 8:40) {
      omitted <- home > candidate_g | away > candidate_g
      cache[[paste("uniform_1x2", boundary_id, candidate_g, sep = "|")]] <-
        sum(uniform_weights[omitted]) / sum(uniform_weights)
      cache[[paste("expanding_1x2", boundary_id, candidate_g, sep = "|")]] <-
        sum(expanding_weights[omitted]) / sum(expanding_weights)
    }
  }
  evaluator <- function(model_id, edition_id, track_id, boundary_id, candidate_g) {
    if (model_id %in% c("uniform_1x2", "expanding_1x2")) {
      return(cache[[paste(model_id, boundary_id, candidate_g, sep = "|")]])
    }
    max(0, 1 - stats::pnbinom(candidate_g, size = nb_theta_bound, mu = nb_mu_bound)^2)
  }
  attr(evaluator, "nb_envelope") <- c(mu = nb_mu_bound, theta = nb_theta_bound)
  evaluator
}
