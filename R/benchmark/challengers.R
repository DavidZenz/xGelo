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
