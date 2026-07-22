#' Registered Phase 10 statistical challenger adapters

challenger_zero_coverage_predictors <- function() {
  setdiff(baseline_goal_predictors(), elo_only_goal_predictors())
}

challenger_zero_coverage_evidence <- function(history) {
  features <- challenger_zero_coverage_predictors()
  missing <- setdiff(features, names(history))
  if (length(missing)) {
    stop(
      "Elo-only ablation history is missing compatibility predictors: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  rows <- lapply(features, function(feature_id) {
    values <- suppressWarnings(as.numeric(history[[feature_id]]))
    if (any(!is.finite(values)) || any(values != 0)) {
      stop(
        "Zero-coverage compatibility predictor must remain finite zero: ",
        feature_id,
        call. = FALSE
      )
    }

    companion <- function(suffix, default) {
      column <- paste0(feature_id, suffix)
      if (!column %in% names(history)) return(default)
      history[[column]]
    }
    source_present <- as.logical(companion("__source_present", FALSE))
    value_present <- as.logical(companion("__value_present", FALSE))
    imputed <- as.logical(companion("__imputed", TRUE))
    reason <- as.character(companion(
      "__imputation_reason",
      "point_in_time_source_coverage_zero"
    ))
    if (
      any(is.na(source_present) | source_present) ||
      any(is.na(value_present) | value_present) ||
      any(is.na(imputed) | !imputed) ||
      any(is.na(reason) | reason != "point_in_time_source_coverage_zero")
    ) {
      stop(
        "Zero-coverage compatibility provenance is inconsistent for: ",
        feature_id,
        call. = FALSE
      )
    }

    data.frame(
      feature_id = feature_id,
      value = 0,
      source_present = FALSE,
      value_present = FALSE,
      imputed = TRUE,
      active_in_fit = FALSE,
      coverage_status = "point_in_time_source_coverage_zero",
      stringsAsFactors = FALSE
    )
  })
  evidence <- do.call(rbind, rows)
  rownames(evidence) <- NULL
  evidence
}

challenger_inactive_ablation_nodes <- function() {
  data.frame(
    node_id = c("attack_xg", "defence_xg", "xgd", "form"),
    parent_id = "open_nb_incumbent",
    activated = FALSE,
    fit_invoked = FALSE,
    status = "not_activated_zero_coverage",
    activation_reason = "phase09_open_core_source_and_value_coverage_zero",
    stringsAsFactors = FALSE
  )
}

#' Fit the registered level-one Elo-only incumbent ablation
#'
#' Uses the unchanged Phase 9 two-sided negative-binomial fitter, open-core
#' panel, and observation-weight path while reducing only the active predictor
#' set. Formula-compatible xG/form columns remain explicit zero-coverage
#' evidence and never activate deeper ablation nodes.
#'
#' @param history Checked open-core benchmark history.
#' @param cutoff Exclusive evidence cutoff.
#' @param observation_weights Optional Phase 9 observation weights.
#' @param ... Reserved for adapter compatibility.
#' @return A benchmark baseline fit with ablation provenance.
#' @export
fit_open_nb_elo_only_ablation <- function(
    history, cutoff = NULL, observation_weights = NULL, ...
) {
  if (!exists("benchmark_fit_two_sided_nb", mode = "function")) {
    stop("benchmark_fit_two_sided_nb must be loaded before challenger fitting", call. = FALSE)
  }
  compatibility_evidence <- challenger_zero_coverage_evidence(history)
  fit <- benchmark_fit_two_sided_nb(
    history = history,
    cutoff = cutoff,
    candidates = elo_only_goal_predictors(),
    model_id = "open_nb_elo_only_ablation",
    panel_id = "open_core",
    observation_weights = observation_weights
  )
  fit$compatibility_feature_evidence <- compatibility_evidence
  fit$ablation_nodes <- challenger_inactive_ablation_nodes()
  fit
}

challenger_project_root <- function() {
  normalizePath(
    file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
    mustWork = TRUE
  )
}

challenger_source_if_missing <- function(symbol, path) {
  if (!exists(symbol, mode = "function")) {
    source(file.path(challenger_project_root(), path), local = .GlobalEnv)
  }
  if (!exists(symbol, mode = "function")) {
    stop("Required challenger service is unavailable: ", symbol, call. = FALSE)
  }
  invisible(TRUE)
}

challenger_load_validated_protocol <- function(
    protocol = NULL, protocol_dir = "data/benchmark/phase10"
) {
  if (!is.null(protocol)) {
    if (!inherits(protocol, "validated_challenger_protocol") ||
        !isTRUE(protocol$valid) || !is.data.frame(protocol$model_registry) ||
        nrow(protocol$model_registry) != 7L) {
      stop("protocol must be the canonical validated challenger object", call. = FALSE)
    }
    return(protocol)
  }
  challenger_source_if_missing("benchmark_row_sha256", "R/benchmark/registry.R")
  challenger_source_if_missing(
    "require_challenger_environment",
    "R/benchmark/challenger_preflight.R"
  )
  challenger_source_if_missing(
    "load_and_validate_challenger_protocol",
    "R/benchmark/challenger_protocol.R"
  )
  validated <- load_and_validate_challenger_protocol(
    file.path(challenger_project_root(), protocol_dir)
  )
  class(validated) <- c("validated_challenger_protocol", class(validated))
  validated
}

challenger_registration <- function(protocol, candidate_id, registration = NULL) {
  candidate_id <- as.character(candidate_id)
  if (length(candidate_id) != 1L || is.na(candidate_id) || !nzchar(candidate_id)) {
    stop("candidate_id must be one registered identifier", call. = FALSE)
  }
  canonical <- protocol$model_registry[
    as.character(protocol$model_registry$candidate_id) == candidate_id,
    , drop = FALSE
  ]
  if (nrow(canonical) != 1L) stop("unknown registered challenger candidate_id", call. = FALSE)
  if (!is.null(registration)) {
    if (!is.data.frame(registration) || nrow(registration) != 1L ||
        !identical(as.character(registration$candidate_id), candidate_id) ||
        !identical(
          as.character(registration$registration_sha256),
          as.character(canonical$registration_sha256)
        ) ||
        !identical(
          as.character(registration$settings_sha256),
          as.character(canonical$settings_sha256)
        )) {
      stop("challenger registration or settings drift", call. = FALSE)
    }
  }
  canonical
}

challenger_settings_scalar <- function(settings, name, default = NULL) {
  value <- settings[[name]]
  if (is.null(value)) value <- default
  value
}

challenger_validate_runtime_settings <- function(settings, registration) {
  if (!is.list(settings)) stop("settings must be a named list", call. = FALSE)
  if (!is.null(settings$registration_sha256) &&
      !identical(
        as.character(settings$registration_sha256),
        as.character(registration$registration_sha256)
      )) {
    stop("challenger registration hash drift", call. = FALSE)
  }
  if (!is.null(settings$registry_settings_sha256) &&
      !identical(
        as.character(settings$registry_settings_sha256),
        as.character(registration$settings_sha256)
      )) {
    stop("challenger settings hash drift", call. = FALSE)
  }
  invisible(TRUE)
}

challenger_training_history <- function(history, cutoff = NULL) {
  challenger_source_if_missing(
    "benchmark_baseline_training_rows",
    "R/benchmark/baselines.R"
  )
  benchmark_baseline_training_rows(history, cutoff)
}

challenger_penalized_fit <- function(history, cutoff, settings, with_elo) {
  challenger_source_if_missing(
    "benchmark_observation_weights",
    "R/benchmark/weights.R"
  )
  challenger_source_if_missing(
    "build_penalized_poisson_design",
    "R/forecast/penalized_poisson.R"
  )
  training <- challenger_training_history(history, cutoff)
  team_ids <- challenger_settings_scalar(
    settings,
    "registered_team_ids",
    sort(unique(c(training$home_team_id, training$away_team_id)), method = "radix")
  )
  design <- build_penalized_poisson_design(training, team_ids)
  weight_cutoff <- if (is.null(cutoff)) {
    max(as.Date(training[[benchmark_baseline_date_column(training)]])) + 1L
  } else {
    as.Date(cutoff)
  }
  weights <- benchmark_observation_weights(training, weight_cutoff)
  fit <- fit_penalized_team_means(
    design,
    lambda = as.numeric(challenger_settings_scalar(settings, "team_ridge_lambda", 1)),
    observation_weights = weights
  )
  if (isTRUE(with_elo)) {
    fit <- fit_penalized_elo_offset(
      fit,
      design,
      lambda = as.numeric(challenger_settings_scalar(settings, "elo_lasso_lambda", 1))
    )
  }
  fit$adapter_active_predictors <- c(
    "attack_prior_match_count", "defence_prior_match_count",
    "team_shrinkage_weight", "team_cold_start", "venue_advantage_for_team",
    if (isTRUE(with_elo)) c("elo_diff", "elo_difference_for_team")
  )
  fit$adapter_dropped_predictors <- challenger_zero_coverage_predictors()
  fit$fit_training_dates <- as.Date(training[[benchmark_baseline_date_column(training)]])
  fit
}

challenger_dynamic_fit <- function(history, cutoff, settings, with_elo) {
  challenger_source_if_missing(
    "initialize_dynamic_goal_state",
    "R/forecast/dynamic_goal_ability.R"
  )
  training <- challenger_training_history(history, cutoff)
  coefficient <- as.numeric(challenger_settings_scalar(settings, "elo_coefficient", 0))
  if (isTRUE(with_elo) && !is.finite(coefficient)) {
    stop("dynamic Elo coefficient must be finite", call. = FALSE)
  }
  result <- list(
    model_id = if (isTRUE(with_elo)) "dynamic_goal_ability_elo" else "dynamic_goal_ability",
    model_family = "dynamic_poisson",
    history = training,
    pseudo_exposure = as.numeric(challenger_settings_scalar(settings, "pseudo_exposure", 8)),
    half_life_days = as.numeric(challenger_settings_scalar(settings, "half_life_days", 730)),
    elo_coefficient = if (isTRUE(with_elo)) coefficient else 0,
    active_predictors = c(
      "dynamic_state_age_days", "dynamic_state_exposure", "team_cold_start",
      "venue_advantage_for_team",
      if (isTRUE(with_elo)) c("elo_diff", "elo_difference_for_team")
    ),
    dropped_predictors = challenger_zero_coverage_predictors(),
    fit_row_count = nrow(training),
    training_dates = as.Date(training[[benchmark_baseline_date_column(training)]]),
    convergence_status = "converged", fallback_status = "none"
  )
  class(result) <- "challenger_dynamic_fit"
  result
}

#' Fit one canonical registered statistical challenger
#'
#' @export
fit_registered_challenger <- function(
    candidate_id, history, settings = list(), cutoff = NULL,
    registration = NULL, protocol = NULL,
    protocol_dir = "data/benchmark/phase10", fit_callback = NULL
) {
  protocol <- challenger_load_validated_protocol(protocol, protocol_dir)
  registration <- challenger_registration(protocol, candidate_id, registration)
  challenger_validate_runtime_settings(settings, registration)
  candidate_id <- as.character(candidate_id)
  if (!is.null(fit_callback)) {
    return(fit_callback(
      candidate_id = candidate_id, history = history, settings = settings,
      cutoff = cutoff, registration = registration, protocol = protocol
    ))
  }
  fit <- switch(
    candidate_id,
    poisson_team_ridge = challenger_penalized_fit(history, cutoff, settings, FALSE),
    poisson_team_ridge_elo = challenger_penalized_fit(history, cutoff, settings, TRUE),
    dynamic_goal_ability = challenger_dynamic_fit(history, cutoff, settings, FALSE),
    dynamic_goal_ability_elo = challenger_dynamic_fit(history, cutoff, settings, TRUE),
    poisson_team_ridge_elo_dc = challenger_penalized_fit(history, cutoff, settings, TRUE),
    poisson_team_ridge_elo_bivpois = challenger_penalized_fit(history, cutoff, settings, TRUE),
    open_nb_elo_only_ablation = fit_open_nb_elo_only_ablation(history, cutoff),
    stop("unknown challenger allowlist candidate_id", call. = FALSE)
  )
  fit$candidate_id <- candidate_id
  fit$registration <- registration
  fit$runtime_settings <- settings
  fit
}

challenger_dynamic_means <- function(fit, fixtures) {
  history <- dynamic_goal_as_results(fit$history)
  fixture_frame <- fixtures
  fixture_frame$match_date <- as.Date(fixtures$actual_completion_date)
  team_ids <- sort(unique(c(
    history$home_team_id, history$away_team_id,
    fixture_frame$home_team_id, fixture_frame$away_team_id
  )), method = "radix")
  global_rate <- mean(c(history$home_goals, history$away_goals))
  if (!is.finite(global_rate) || global_rate <= 0) global_rate <- 1.25
  initial <- initialize_dynamic_goal_state(
    team_ids, global_rate, fit$pseudo_exposure, min(history$match_date)
  )
  replay <- replay_dynamic_goal_states(
    history, fixture_frame, initial, half_life_days = fit$half_life_days
  )
  means <- replay$predictions[match(fixtures$fixture_id, replay$predictions$fixture_id), , drop = FALSE]
  if (any(is.na(means$fixture_id))) stop("dynamic predictions dropped fixtures", call. = FALSE)
  elo <- if (fit$elo_coefficient == 0) rep.int(0, nrow(fixtures)) else as.numeric(fixtures$elo_diff)
  means$mu_home <- exp(means$dynamic_log_mu_home + fit$elo_coefficient * elo)
  means$mu_away <- exp(means$dynamic_log_mu_away - fit$elo_coefficient * elo)
  means
}

challenger_distribution_grid <- function(
    candidate_id, mu_home, mu_away, support_max, distribution_id, settings,
    nb_fit = NULL, row_index = NULL
) {
  challenger_source_if_missing(
    "independent_poisson_grid",
    "R/forecast/score_dependence.R"
  )
  if (identical(candidate_id, "open_nb_elo_only_ablation")) {
    goals <- 0:as.integer(support_max)
    home <- stats::dnbinom(goals, size = nb_fit$home_model$theta, mu = mu_home)
    away <- stats::dnbinom(goals, size = nb_fit$away_model$theta, mu = mu_away)
    return(benchmark_one_distribution(
      distribution_id, home, away,
      max(0, 1 - sum(home) * sum(away)), support_max
    ))
  }
  switch(
    candidate_id,
    poisson_team_ridge = independent_poisson_grid(mu_home, mu_away, support_max, distribution_id),
    poisson_team_ridge_elo = independent_poisson_grid(mu_home, mu_away, support_max, distribution_id),
    dynamic_goal_ability = independent_poisson_grid(mu_home, mu_away, support_max, distribution_id),
    dynamic_goal_ability_elo = independent_poisson_grid(mu_home, mu_away, support_max, distribution_id),
    poisson_team_ridge_elo_dc = dixon_coles_grid(
      mu_home, mu_away,
      as.numeric(challenger_settings_scalar(settings, "rho", 0)),
      support_max, distribution_id
    ),
    poisson_team_ridge_elo_bivpois = bivariate_poisson_grid(
      mu_home, mu_away,
      as.numeric(challenger_settings_scalar(settings, "q", 0)),
      support_max, distribution_id
    ),
    stop("unknown challenger allowlist candidate_id", call. = FALSE)
  )
}

#' Predict one or more registered statistical challengers
#'
#' @export
predict_registered_challenger <- function(
    candidate_id, fit = NULL, fixtures = NULL, support_max = 40L,
    mean_predictions = NULL, settings = list(), validate_only = FALSE
) {
  allowed <- c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "dynamic_goal_ability", "dynamic_goal_ability_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
    "open_nb_elo_only_ablation"
  )
  candidate_id <- as.character(candidate_id)
  if (any(!candidate_id %in% allowed)) stop("unknown challenger allowlist candidate_id", call. = FALSE)
  if (isTRUE(validate_only)) {
    required <- c("candidate_id", "mean_parent_id", "mean_prediction_hash")
    if (!is.data.frame(mean_predictions) || !all(required %in% names(mean_predictions))) {
      stop("shared mean validation requires candidate, parent, and hash columns", call. = FALSE)
    }
    expected <- c(
      "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
      "poisson_team_ridge_elo_bivpois"
    )
    if (!identical(as.character(mean_predictions$candidate_id), expected) ||
        any(as.character(mean_predictions$mean_parent_id) != "poisson_team_ridge_elo") ||
        length(unique(tolower(as.character(mean_predictions$mean_prediction_hash)))) != 1L ||
        any(!grepl("^[0-9a-f]{64}$", tolower(as.character(mean_predictions$mean_prediction_hash))))) {
      stop("dependence siblings do not attest one augmented penalized mean", call. = FALSE)
    }
    return(mean_predictions)
  }
  if (length(candidate_id) != 1L || is.null(fit) || !is.data.frame(fixtures) || !nrow(fixtures)) {
    stop("one fitted candidate and non-empty fixtures are required", call. = FALSE)
  }
  challenger_source_if_missing(
    "derive_benchmark_markets",
    "R/benchmark/contracts.R"
  )
  challenger_source_if_missing(
    "statistical_mean_prediction_hash",
    "R/forecast/score_dependence.R"
  )
  if (candidate_id %in% c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois"
  )) {
    means <- predict_penalized_poisson_means(fit, fixtures)
  } else if (candidate_id %in% c("dynamic_goal_ability", "dynamic_goal_ability_elo")) {
    means <- challenger_dynamic_means(fit, fixtures)
  } else {
    nb <- benchmark_nb_means(fit, fixtures)
    means <- data.frame(
      fixture_id = as.character(fixtures$fixture_id),
      mu_home = nb$home, mu_away = nb$away,
      stringsAsFactors = FALSE
    )
  }
  identity <- data.frame(
    outer_edition_id = as.character(fixtures$edition_id),
    track_id = as.character(fixtures$track_id),
    boundary_id = as.character(fixtures$boundary_id),
    fixture_id = as.character(fixtures$fixture_id),
    mu_home = as.numeric(means$mu_home), mu_away = as.numeric(means$mu_away),
    stringsAsFactors = FALSE
  )
  mean_hash <- statistical_mean_prediction_hash(identity)
  distributions <- lapply(seq_len(nrow(fixtures)), function(i) {
    distribution_id <- paste(
      candidate_id, fixtures$track_id[i], fixtures$fixture_id[i], "score", sep = "__"
    )
    challenger_distribution_grid(
      candidate_id, identity$mu_home[i], identity$mu_away[i], support_max,
      distribution_id, settings, nb_fit = fit, row_index = i
    )
  })
  distributions <- do.call(rbind, distributions)
  markets <- do.call(rbind, lapply(seq_len(nrow(fixtures)), function(i) {
    id <- unique(distributions$score_distribution_id)[i]
    grid <- distributions[distributions$score_distribution_id == id, , drop = FALSE]
    data.frame(
      fixture_id = as.character(fixtures$fixture_id[i]),
      score_distribution_id = id,
      as.data.frame(derive_benchmark_markets(grid), stringsAsFactors = FALSE),
      stringsAsFactors = FALSE
    )
  }))
  list(
    means = cbind(
      identity,
      mean_parent_id = if (candidate_id %in% c(
        "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
        "poisson_team_ridge_elo_bivpois"
      )) "poisson_team_ridge_elo" else candidate_id,
      mean_prediction_hash = mean_hash
    ),
    predictions = markets,
    distributions = distributions,
    model_evidence = means
  )
}

challenger_baseline_registration <- function(registration) {
  data.frame(
    model_id = as.character(registration$candidate_id),
    panel_id = as.character(registration$native_panel_id),
    adapter_version = as.character(registration$adapter_version),
    registration_sha256 = as.character(registration$registration_sha256),
    settings_sha256 = as.character(registration$settings_sha256),
    stringsAsFactors = FALSE
  )
}

challenger_manifest_fit <- function(fit, candidate_id) {
  if (inherits(fit, "benchmark_baseline_fit")) return(fit)
  training_dates <- if (!is.null(fit$fit_training_dates)) fit$fit_training_dates else fit$training_dates
  structure(list(
    model_id = candidate_id,
    model_family = if (!is.null(fit$model_family)) fit$model_family else "statistical_challenger",
    active_predictors = if (!is.null(fit$adapter_active_predictors)) {
      fit$adapter_active_predictors
    } else {
      fit$active_predictors
    },
    dropped_predictors = if (!is.null(fit$adapter_dropped_predictors)) {
      fit$adapter_dropped_predictors
    } else {
      fit$dropped_predictors
    },
    training_dates = training_dates,
    fit_row_count = length(training_dates),
    convergence_status = fit$convergence_status,
    fallback_status = fit$fallback_status
  ), class = "benchmark_baseline_fit")
}

challenger_zero_coverage_fixtures <- function(fixtures) {
  fixtures <- fixtures
  for (feature_id in challenger_zero_coverage_predictors()) {
    fixtures[[feature_id]] <- 0
    fixtures[[paste0(feature_id, "__value_present")]] <- FALSE
    fixtures[[paste0(feature_id, "__source_present")]] <- FALSE
    fixtures[[paste0(feature_id, "__source_date")]] <- as.Date(NA)
    fixtures[[paste0(feature_id, "__imputed")]] <- TRUE
    fixtures[[paste0(feature_id, "__imputation_reason")]] <-
      "point_in_time_source_coverage_zero"
  }
  fixtures
}

#' Run one registered statistical candidate through the common adapter contract
#'
#' @export
run_registered_challenger_adapter <- function(
    candidate_id, history, fixtures, seed_registry, support_max = 40L,
    settings = list(), run_id = "phase10_challenger_run",
    registration = NULL, protocol = NULL,
    protocol_dir = "data/benchmark/phase10"
) {
  challenger_source_if_missing(
    "validate_benchmark_predictions",
    "R/benchmark/contracts.R"
  )
  challenger_source_if_missing(
    "run_registered_baseline_adapter",
    "R/benchmark/baselines.R"
  )
  challenger_source_if_missing(
    "benchmark_observation_weights",
    "R/benchmark/weights.R"
  )
  protocol <- challenger_load_validated_protocol(protocol, protocol_dir)
  registration <- challenger_registration(protocol, candidate_id, registration)
  candidate_id <- as.character(candidate_id)
  switch(
    candidate_id,
    poisson_team_ridge = NULL,
    poisson_team_ridge_elo = NULL,
    dynamic_goal_ability = NULL,
    dynamic_goal_ability_elo = NULL,
    poisson_team_ridge_elo_dc = NULL,
    poisson_team_ridge_elo_bivpois = NULL,
    open_nb_elo_only_ablation = NULL,
    stop("unknown challenger allowlist candidate_id", call. = FALSE)
  )
  validate_seed_registry(seed_registry)
  required_fixture <- c(
    "edition_id", "track_id", "fixture_id", "boundary_id", "forecast_sequence",
    "home_team_id", "away_team_id", "venue_role", "actual_completion_date",
    "evidence_cutoff_exclusive", "result_cutoff_exclusive"
  )
  benchmark_contract_require_columns(fixtures, required_fixture, "Challenger adapter fixtures")
  if (support_max != 40L || support_max != as.integer(support_max)) {
    stop("challenger adapter requires sealed G=40 support", call. = FALSE)
  }
  fixtures <- challenger_zero_coverage_fixtures(fixtures)
  pieces <- lapply(split(seq_len(nrow(fixtures)), fixtures$boundary_id), function(index) {
    boundary <- fixtures[index, , drop = FALSE]
    cutoff <- unique(as.Date(boundary$evidence_cutoff_exclusive))
    if (length(cutoff) != 1L || is.na(cutoff)) {
      stop("boundary fixtures require one exclusive cutoff", call. = FALSE)
    }
    fit <- fit_registered_challenger(
      candidate_id, history, settings, cutoff, registration,
      protocol = protocol, protocol_dir = protocol_dir
    )
    predicted <- predict_registered_challenger(
      candidate_id, fit, boundary, support_max, settings = settings
    )
    list(fit = fit, fixtures = boundary, result = predicted)
  })
  distributions <- do.call(rbind, lapply(pieces, function(piece) piece$result$distributions))
  predictions <- do.call(rbind, lapply(pieces, function(piece) {
    base <- piece$fixtures
    markets <- piece$result$predictions[
      match(base$fixture_id, piece$result$predictions$fixture_id), , drop = FALSE
    ]
    seed <- seed_registry[match(base$fixture_id, seed_registry$fixture_id), , drop = FALSE]
    if (any(is.na(seed$seed_id))) stop("challenger fixtures are missing shared seeds", call. = FALSE)
    manifest_id <- paste(run_id, candidate_id, base$boundary_id, sep = "__")
    data.frame(
      schema_version = "1.0", run_id = run_id, model_id = candidate_id,
      panel_id = as.character(registration$native_panel_id), edition_id = base$edition_id,
      track_id = base$track_id, fixture_id = base$fixture_id,
      boundary_id = base$boundary_id, forecast_sequence = base$forecast_sequence,
      home_team_id = base$home_team_id, away_team_id = base$away_team_id,
      venue_role = base$venue_role,
      evidence_cutoff_exclusive = as.Date(base$evidence_cutoff_exclusive),
      result_cutoff_exclusive = as.Date(base$result_cutoff_exclusive),
      model_manifest_id = manifest_id,
      feature_coverage_id = vapply(seq_len(nrow(base)), function(i) {
        benchmark_feature_coverage_id(
          run_id, candidate_id, base$track_id[i], base$boundary_id[i], base$fixture_id[i]
        )
      }, character(1)),
      seed_id = seed$seed_id, score_distribution_id = markets$score_distribution_id,
      p_home = markets$p_home, p_draw = markets$p_draw, p_away = markets$p_away,
      expected_home_goals = markets$expected_home_goals,
      expected_away_goals = markets$expected_away_goals,
      p_over_2_5 = markets$p_over_2_5, p_under_2_5 = markets$p_under_2_5,
      p_btts = markets$p_btts, modal_home_goals = markets$modal_home_goals,
      modal_away_goals = markets$modal_away_goals,
      modal_score_probability = markets$modal_score_probability,
      prediction_status = "ok", failure_reason = "", stringsAsFactors = FALSE
    )
  }))
  baseline_registration <- challenger_baseline_registration(registration)
  manifests <- do.call(rbind, lapply(pieces, function(piece) {
    benchmark_manifest_rows(
      challenger_manifest_fit(piece$fit, candidate_id), baseline_registration,
      piece$fixtures, history, run_id
    )
  }))
  manifests <- manifests[!duplicated(manifests$model_manifest_id), , drop = FALSE]
  mean_evidence <- do.call(rbind, lapply(pieces, function(piece) {
    data.frame(
      boundary_id = unique(as.character(piece$fixtures$boundary_id)),
      mean_parent_candidate_id = unique(as.character(piece$result$means$mean_parent_id)),
      mean_prediction_hash = unique(as.character(piece$result$means$mean_prediction_hash)),
      stringsAsFactors = FALSE
    )
  }))
  if (anyDuplicated(mean_evidence$boundary_id)) {
    stop("challenger mean evidence must be unique by boundary", call. = FALSE)
  }
  mean_index <- match(manifests$boundary_id, mean_evidence$boundary_id)
  if (any(is.na(mean_index))) stop("challenger manifests are missing mean evidence", call. = FALSE)
  manifests$mean_parent_candidate_id <- mean_evidence$mean_parent_candidate_id[mean_index]
  manifests$mean_prediction_hash <- mean_evidence$mean_prediction_hash[mean_index]
  feature_coverage <- build_registered_feature_coverage(
    baseline_registration, predictions, fixtures, protocol$feature_contract, manifests
  )
  model_registry <- data.frame(
    model_id = as.character(protocol$model_registry$candidate_id),
    panel_id = as.character(protocol$model_registry$native_panel_id),
    stringsAsFactors = FALSE
  )
  invisible(lapply(unique(distributions$score_distribution_id), function(id) {
    derive_benchmark_markets(
      distributions[distributions$score_distribution_id == id, , drop = FALSE]
    )
  }))
  validate_model_manifests(manifests)
  validate_benchmark_predictions(
    predictions, fixtures, distributions, seed_registry, support_max
  )
  validate_benchmark_feature_evidence(
    predictions, feature_coverage, model_registry, protocol$feature_contract
  )
  list(
    predictions = predictions,
    distributions = distributions,
    manifests = manifests,
    feature_coverage = feature_coverage
  )
}

#' Build registered full-versus-Elo-only practical non-inferiority evidence
#'
#' @param comparison Named comparison inputs produced from the shared benchmark
#'   score path.
#' @param protocol Optional canonical validated challenger protocol.
#' @param protocol_dir Canonical Phase 10 protocol directory.
#' @return Auditable decision inputs, gates, feature sets, and decision.
#' @export
challenger_ablation_evidence <- function(
    comparison, protocol = NULL,
    protocol_dir = "data/benchmark/phase10"
) {
  if (!is.list(comparison)) {
    stop("ablation comparison must be a named list", call. = FALSE)
  }
  required <- c(
    "candidate_id", "parent_id", "updating_equal_tournament_rps_delta",
    "brier_relative_change", "log_loss_relative_change", "calibration_change",
    "maximum_fold_regression", "fold_wins", "world_cup_wins", "euro_wins",
    "active_features", "inactive_features"
  )
  missing <- setdiff(required, names(comparison))
  if (length(missing)) {
    stop("ablation comparison is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  protocol <- challenger_load_validated_protocol(protocol, protocol_dir)
  registry <- protocol$ablation_registry
  scored <- registry[
    as.character(registry$ablation_id) == "open_nb_elo_only_ablation",
    , drop = FALSE
  ]
  if (nrow(scored) != 1L ||
      !identical(as.character(comparison$candidate_id), as.character(scored$ablation_id)) ||
      !identical(as.character(comparison$parent_id), as.character(scored$parent_candidate_id))) {
    stop("ablation comparison does not match the registered scored sibling", call. = FALSE)
  }
  registered_active <- strsplit(
    as.character(scored$retained_features), "|", fixed = TRUE
  )[[1L]]
  registered_inactive <- strsplit(
    as.character(scored$removed_features), "|", fixed = TRUE
  )[[1L]]
  active_features <- as.character(comparison$active_features)
  inactive_features <- as.character(comparison$inactive_features)
  if (!identical(active_features, registered_active) ||
      !setequal(inactive_features, registered_inactive)) {
    stop("ablation active or inactive feature evidence drift", call. = FALSE)
  }

  metric_names <- c(
    "updating_equal_tournament_rps_delta", "brier_relative_change",
    "log_loss_relative_change", "calibration_change", "maximum_fold_regression",
    "fold_wins", "world_cup_wins", "euro_wins"
  )
  metrics <- vapply(metric_names, function(name) as.numeric(comparison[[name]]), numeric(1))
  if (any(!is.finite(metrics))) {
    stop("ablation decision inputs must be finite", call. = FALSE)
  }
  thresholds <- protocol$thresholds
  needed_thresholds <- c(
    "simpler_noninferiority", "brier_relative", "log_relative", "calibration",
    "maximum_fold_regression", "fold_wins", "world_cup_wins", "euro_wins"
  )
  if (!all(needed_thresholds %in% names(thresholds))) {
    stop("validated selection protocol is missing ablation thresholds", call. = FALSE)
  }
  gates <- c(
    rps = metrics[["updating_equal_tournament_rps_delta"]] <=
      thresholds[["simpler_noninferiority"]],
    brier = metrics[["brier_relative_change"]] <= thresholds[["brier_relative"]],
    log_loss = metrics[["log_loss_relative_change"]] <= thresholds[["log_relative"]],
    calibration = metrics[["calibration_change"]] <= thresholds[["calibration"]],
    worst_fold = metrics[["maximum_fold_regression"]] <=
      thresholds[["maximum_fold_regression"]],
    fold_breadth = metrics[["fold_wins"]] >= thresholds[["fold_wins"]],
    world_cup_breadth = metrics[["world_cup_wins"]] >= thresholds[["world_cup_wins"]],
    euro_breadth = metrics[["euro_wins"]] >= thresholds[["euro_wins"]]
  )
  failed <- names(gates)[!gates]
  list(
    candidate_id = as.character(comparison$candidate_id),
    parent_id = as.character(comparison$parent_id),
    practically_non_inferior = all(gates),
    reason_codes = if (length(failed)) paste(failed, collapse = "|") else "all_gates_pass",
    updating_equal_tournament_rps_delta = unname(metrics[["updating_equal_tournament_rps_delta"]]),
    brier_relative_change = unname(metrics[["brier_relative_change"]]),
    log_loss_relative_change = unname(metrics[["log_loss_relative_change"]]),
    calibration_change = unname(metrics[["calibration_change"]]),
    maximum_fold_regression = unname(metrics[["maximum_fold_regression"]]),
    fold_wins = as.integer(metrics[["fold_wins"]]),
    world_cup_wins = as.integer(metrics[["world_cup_wins"]]),
    euro_wins = as.integer(metrics[["euro_wins"]]),
    active_features = active_features,
    inactive_features = inactive_features,
    gates = gates,
    thresholds = thresholds[needed_thresholds]
  )
}
