#' Nested calibration remediation for the retained Phase 12 incumbent.
#'
#' This module is development-only. It consumes the sealed 12-tournament
#' development panel, never resolves WC2026 labels, and owns no release or
#' competition-registry mutation path.

phase14_remediation_project_root <- function() {
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "data/benchmark/phase09/fixtures.csv"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Phase 14 remediation could not locate the project root", call. = FALSE)
}

phase14_remediation_resolve_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 14 remediation path must be one non-empty value", call. = FALSE)
  }
  if (grepl("^/", path)) path else file.path(phase14_remediation_project_root(), path)
}

phase14_remediation_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- phase14_remediation_resolve_path(relative_path)
  if (!file.exists(path)) stop("Phase 14 remediation dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop("Phase 14 remediation dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

phase14_remediation_source_if_missing(
  "R/release/calibration_revision.R",
  c(
    "phase14_build_incumbent_development_panel",
    "phase14_calibration_revision_file_sha256",
    "phase14_calibration_revision_gate_row",
    "phase14_calibration_revision_table_sha256"
  )
)
phase14_remediation_source_if_missing(
  "R/calibration/calibration_selection.R",
  c("phase12_selection_decision", "phase12_selection_protocol")
)

phase14_remediation_scalar <- function(value) {
  if (!length(value) || is.na(value)) "" else formatC(as.numeric(value), digits = 17L, format = "fg")
}

phase14_remediation_join_ids <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(values)]
  paste(values, collapse = "|")
}

phase14_remediation_split_ids <- function(value) {
  value <- as.character(value)
  if (!length(value) || is.na(value) || !nzchar(value)) character() else strsplit(value, "\\|", fixed = FALSE)[[1L]]
}

phase14_remediation_inner_map <- function(validation_editions, all_editions) {
  entries <- vapply(validation_editions, function(validation) {
    index <- match(validation, all_editions)
    training <- if (is.na(index) || index <= 1L) character() else all_editions[seq_len(index - 1L)]
    paste0(validation, "~", paste(training, collapse = "+"))
  }, character(1))
  paste(entries, collapse = ";")
}

phase14_remediation_parse_inner_map <- function(value) {
  value <- as.character(value)
  if (!length(value) || is.na(value) || !nzchar(value)) return(list())
  entries <- strsplit(value, ";", fixed = TRUE)[[1L]]
  result <- lapply(entries, function(entry) {
    parts <- strsplit(entry, "~", fixed = TRUE)[[1L]]
    if (length(parts) != 2L || !nzchar(parts[[1L]])) stop("Phase 14 remediation inner training map is invalid", call. = FALSE)
    if (!nzchar(parts[[2L]])) character() else strsplit(parts[[2L]], "+", fixed = TRUE)[[1L]]
  })
  names(result) <- vapply(entries, function(entry) strsplit(entry, "~", fixed = TRUE)[[1L]][[1L]], character(1))
  result
}

phase14_remediation_candidate_grid <- function() {
  warmup <- c(60L, 128L, 256L, 400L)
  shrinkage <- c(0.25, 0.50, 0.75, 1.00)
  penalties <- c(0.001, 0.01, 0.05, 0.10, 0.50, 1.00, 5.00)
  raw <- data.frame(
    candidate_id = "raw_identity",
    family = "raw_identity",
    warmup_rows = 0L,
    scalar_shrinkage = NA_real_,
    vector_penalty = NA_real_,
    complexity_rank = 1L,
    candidate_order = 1L,
    stringsAsFactors = FALSE
  )
  scalar <- do.call(rbind, lapply(warmup, function(rows) {
    data.frame(
      candidate_id = paste0("scalar_w", rows, "_s", gsub("\\.", "p", format(shrinkage, trim = TRUE))),
      family = "scalar_temperature",
      warmup_rows = rows,
      scalar_shrinkage = shrinkage,
      vector_penalty = NA_real_,
      complexity_rank = 2L,
      candidate_order = seq_along(shrinkage),
      stringsAsFactors = FALSE
    )
  }))
  scalar$candidate_order <- seq_len(nrow(scalar))
  vector <- do.call(rbind, lapply(warmup, function(rows) {
    data.frame(
      candidate_id = paste0("vector_w", rows, "_p", gsub("\\.", "p", format(penalties, trim = TRUE, scientific = FALSE))),
      family = "vector_scaling",
      warmup_rows = rows,
      scalar_shrinkage = NA_real_,
      vector_penalty = penalties,
      complexity_rank = 3L,
      candidate_order = seq_along(penalties),
      stringsAsFactors = FALSE
    )
  }))
  vector$candidate_order <- seq_len(nrow(vector))
  result <- rbind(raw, scalar, vector)
  rownames(result) <- NULL
  result
}

#' Return the predeclared family, grid, transform, ranking, and seed contract.
#' @export
phase14_calibration_remediation_contract <- function() {
  list(
    schema_version = "phase14-calibration-remediation-contract-v2",
    family_order = c("raw_identity", "scalar_temperature", "vector_scaling"),
    warmup_rows = c(60L, 128L, 256L, 400L),
    scalar_shrinkage = c(0.25, 0.50, 0.75, 1.00),
    vector_penalties = c(0.001, 0.01, 0.05, 0.10, 0.50, 1.00, 5.00),
    temperature_bounds = c(0.25, 4),
    vector_slope_bounds = c(0.25, 4),
    vector_offset_bounds = c(-2, 2),
    minimum_class_count = 10L,
    minimum_inner_validation_tournaments = 2L,
    optimizer_method = "stats::optim-L-BFGS-B",
    scalar_transform = "exp(shrinkage*bounded_log_temperature)",
    vector_transform = "softmax(slopes*log(raw_probability)+zero_sum_offsets)",
    vector_penalty_target = "sum((slopes-1)^2)+sum(offsets^2)",
    tie_break_order = c("rps", "calibration_error", "log_loss", "brier", "complexity_rank"),
    seed_base = 142100L,
    seed_algorithm = "seed_base_plus_sha256_first_7_hex_mod_2147483646",
    candidates = phase14_remediation_candidate_grid()
  )
}

phase14_remediation_contract_table <- function(contract = phase14_calibration_remediation_contract()) {
  result <- contract$candidates
  result$schema_version <- contract$schema_version
  result$family_order <- paste(contract$family_order, collapse = "|")
  result$warmup_grid <- paste(contract$warmup_rows, collapse = "|")
  result$scalar_shrinkage_grid <- paste(format(contract$scalar_shrinkage, nsmall = 2L), collapse = "|")
  result$vector_penalty_grid <- paste(format(contract$vector_penalties, scientific = FALSE, trim = TRUE), collapse = "|")
  result$temperature_bounds <- paste(contract$temperature_bounds, collapse = "|")
  result$vector_slope_bounds <- paste(contract$vector_slope_bounds, collapse = "|")
  result$vector_offset_bounds <- paste(contract$vector_offset_bounds, collapse = "|")
  result$minimum_class_count <- contract$minimum_class_count
  result$minimum_inner_validation_tournaments <- contract$minimum_inner_validation_tournaments
  result$optimizer_method <- contract$optimizer_method
  result$scalar_transform <- contract$scalar_transform
  result$vector_transform <- contract$vector_transform
  result$vector_penalty_target <- contract$vector_penalty_target
  result$tie_break_order <- paste(contract$tie_break_order, collapse = "|")
  result$seed_base <- contract$seed_base
  result$seed_algorithm <- contract$seed_algorithm
  result <- result[, c(
    "schema_version", "candidate_id", "family", "warmup_rows", "scalar_shrinkage",
    "vector_penalty", "complexity_rank", "candidate_order", "family_order",
    "warmup_grid", "scalar_shrinkage_grid", "vector_penalty_grid", "temperature_bounds",
    "vector_slope_bounds", "vector_offset_bounds", "minimum_class_count",
    "minimum_inner_validation_tournaments", "optimizer_method", "scalar_transform",
    "vector_transform", "vector_penalty_target", "tie_break_order", "seed_base",
    "seed_algorithm"
  )]
  result$contract_row_sha256 <- vapply(seq_len(nrow(result)), function(i) {
    phase14_calibration_revision_table_sha256(result[i, , drop = FALSE])
  }, character(1))
  result
}

phase14_remediation_seed <- function(
    outer_index, inner_validation_index, family, warmup_rows = NA_integer_,
    scalar_shrinkage = NA_real_, vector_penalty = NA_real_, stage = "inner"
) {
  contract <- phase14_calibration_remediation_contract()
  key <- paste(
    as.integer(outer_index), as.integer(inner_validation_index), as.character(stage),
    as.character(family), ifelse(is.na(warmup_rows), "", as.integer(warmup_rows)),
    phase14_remediation_scalar(scalar_shrinkage),
    phase14_remediation_scalar(vector_penalty),
    sep = "|"
  )
  hash <- digest::digest(key, algo = "sha256", serialize = FALSE)
  offset <- strtoi(substr(hash, 1L, 7L), base = 16L)
  seed <- (as.double(contract$seed_base) + as.double(offset)) %% 2147483646
  as.integer(seed + 1)
}

phase14_remediation_panel_editions <- function(panel) {
  editions <- attr(panel, "edition_order")
  if (!is.null(editions) && length(editions)) return(as.character(editions))
  if (!"edition_open_date" %in% names(panel)) {
    panel$edition_open_date <- as.Date(panel$scheduled_date)
  }
  opens <- tapply(as.Date(panel$edition_open_date), panel$edition_id, min)
  names(sort(as.Date(opens, origin = "1970-01-01"), method = "radix"))
}

phase14_remediation_prepare_panel <- function(panel) {
  required <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_home", "p_draw", "p_away", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status", "scheduled_date",
    "actual_completion_date", "regulation_home_goals", "regulation_away_goals",
    "observed_class"
  )
  phase14_calibration_revision_require_columns(panel, required, "Phase 14 remediation panel")
  if (nrow(panel) != 630L || anyDuplicated(as.character(panel$fixture_id)) ||
      phase14_calibration_revision_has_holdout_identity(panel) ||
      any(as.character(panel$model_id) != "open_nb_incumbent") ||
      any(as.character(panel$track_id) != "updating") ||
      any(as.character(panel$panel_id) != "open_core")) {
    stop("Phase 14 remediation requires the exact sealed 630-row development panel", call. = FALSE)
  }
  probabilities <- as.matrix(panel[, c("p_home", "p_draw", "p_away")])
  storage.mode(probabilities) <- "double"
  if (anyNA(probabilities) || any(!is.finite(probabilities)) || any(probabilities <= 0 | probabilities >= 1) ||
      any(abs(rowSums(probabilities) - 1) > 1e-10)) {
    stop("Phase 14 remediation raw probability simplex is invalid", call. = FALSE)
  }
  observed <- phase14_calibration_revision_observed_class(
    panel$regulation_home_goals, panel$regulation_away_goals
  )
  if (!identical(as.character(panel$observed_class), as.character(observed))) {
    stop("Phase 14 remediation observed classes drifted from registered fixture scores", call. = FALSE)
  }
  panel$scheduled_date <- as.Date(panel$scheduled_date)
  panel$actual_completion_date <- as.Date(panel$actual_completion_date)
  if ("edition_open_date" %in% names(panel)) panel$edition_open_date <- as.Date(panel$edition_open_date)
  editions <- phase14_remediation_panel_editions(panel)
  if (length(editions) != 12L || anyDuplicated(editions)) {
    stop("Phase 14 remediation requires exactly 12 chronological development editions", call. = FALSE)
  }
  for (index in seq_along(editions)) {
    outer <- editions[[index]]
    outer_open <- min(panel$scheduled_date[panel$edition_id == outer])
    prior <- if (index <= 1L) character() else editions[seq_len(index - 1L)]
    if (length(prior) && any(panel$actual_completion_date[panel$edition_id %in% prior] >= outer_open)) {
      stop("Phase 14 remediation tournament chronology is not strictly prior", call. = FALSE)
    }
  }
  attr(panel, "edition_order") <- editions
  panel
}

phase14_remediation_support <- function(rows) {
  counts <- table(factor(as.character(rows$observed_class), levels = c("home", "draw", "away")))
  c(
    rows = nrow(rows), home = as.integer(counts[["home"]]),
    draw = as.integer(counts[["draw"]]), away = as.integer(counts[["away"]])
  )
}

phase14_remediation_with_seed <- function(seed, callback) {
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old_seed, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(seed), kind = "L'Ecuyer-CMRG")
  callback()
}

phase14_remediation_fit_candidate <- function(training, candidate, seed, contract) {
  family <- as.character(candidate$family[[1L]])
  identity <- list(
    valid = TRUE, fit_status = if (family == "raw_identity") "raw_fallback" else "fitted",
    fallback_reason = if (family == "raw_identity") "identity_baseline" else "",
    optimizer_method = if (family == "raw_identity") "not_run" else contract$optimizer_method,
    optimizer_seed = as.integer(seed), optimizer_convergence_code = NA_integer_,
    optimizer_convergence_message = if (family == "raw_identity") "not_run" else "",
    optimizer_objective_value = NA_real_, temperature = 1,
    slope_home = 1, slope_draw = 1, slope_away = 1,
    offset_home = 0, offset_draw = 0, offset_away = 0
  )
  if (family == "raw_identity") return(identity)
  probabilities <- as.matrix(training[, c("p_home", "p_draw", "p_away")])
  storage.mode(probabilities) <- "double"
  observed <- match(as.character(training$observed_class), c("home", "draw", "away"))
  observed_matrix <- matrix(0, nrow = nrow(training), ncol = 3L)
  observed_matrix[cbind(seq_len(nrow(training)), observed)] <- 1
  epsilon <- 1e-15
  log_probabilities <- log(pmax(probabilities, epsilon))
  softmax_rows <- function(logits) {
    maxima <- apply(logits, 1L, max)
    values <- exp(logits - maxima)
    values / rowSums(values)
  }
  if (family == "scalar_temperature") {
    objective <- function(log_temperature) {
      calibrated <- softmax_rows(log_probabilities / exp(log_temperature[[1L]]))
      value <- -mean(log(pmax(calibrated[cbind(seq_len(nrow(calibrated)), observed)], epsilon)))
      if (is.finite(value)) value else Inf
    }
    gradient <- function(log_temperature) {
      temperature <- exp(log_temperature[[1L]])
      logits <- log_probabilities / temperature
      calibrated <- softmax_rows(logits)
      as.numeric(mean(rowSums((calibrated - observed_matrix) * (-logits))))
    }
    optimized <- tryCatch(
      phase14_remediation_with_seed(seed, function() stats::optim(
        par = 0, fn = objective, gr = gradient, method = "L-BFGS-B",
        lower = log(contract$temperature_bounds[[1L]]),
        upper = log(contract$temperature_bounds[[2L]])
      )),
      error = function(error) error
    )
    if (inherits(optimized, "error") || length(optimized$par) != 1L ||
        !is.finite(optimized$par[[1L]]) || !identical(as.integer(optimized$convergence), 0L) ||
        !is.finite(optimized$value)) {
      identity$valid <- FALSE
      identity$fit_status <- "raw_fallback"
      identity$fallback_reason <- "optimizer_invalid"
      identity$optimizer_convergence_message <- if (inherits(optimized, "error")) conditionMessage(optimized) else "invalid_optimizer_state"
      return(identity)
    }
    shrinkage <- as.numeric(candidate$scalar_shrinkage[[1L]])
    final_log_temperature <- shrinkage * as.numeric(optimized$par[[1L]])
    identity$temperature <- exp(final_log_temperature)
    identity$optimizer_convergence_code <- as.integer(optimized$convergence)
    identity$optimizer_convergence_message <- if (is.null(optimized$message) || !nzchar(optimized$message)) "converged" else as.character(optimized$message)
    identity$optimizer_objective_value <- as.numeric(objective(final_log_temperature))
    return(identity)
  }
  if (family == "vector_scaling") {
    penalty <- as.numeric(candidate$vector_penalty[[1L]])
    objective <- function(parameters) {
      slopes <- as.numeric(parameters[1:3])
      offsets <- c(as.numeric(parameters[4:5]), -sum(as.numeric(parameters[4:5])))
      calibrated <- softmax_rows(sweep(log_probabilities, 2L, slopes, `*`) +
        matrix(offsets, nrow = nrow(probabilities), ncol = 3L, byrow = TRUE))
      loss <- -mean(log(pmax(calibrated[cbind(seq_len(nrow(calibrated)), observed)], epsilon)))
      regularization <- penalty * (sum((slopes - 1)^2) + sum(offsets^2))
      value <- loss + regularization
      if (is.finite(value)) value else Inf
    }
    gradient <- function(parameters) {
      slopes <- as.numeric(parameters[1:3])
      offsets <- c(as.numeric(parameters[4:5]), -sum(as.numeric(parameters[4:5])))
      calibrated <- softmax_rows(sweep(log_probabilities, 2L, slopes, `*`) +
        matrix(offsets, nrow = nrow(probabilities), ncol = 3L, byrow = TRUE))
      residual <- calibrated - observed_matrix
      slope_gradient <- colMeans(residual * log_probabilities) + 2 * penalty * (slopes - 1)
      offset_gradient <- colMeans(residual) + 2 * penalty * offsets
      c(slope_gradient, offset_gradient[[1L]] - offset_gradient[[3L]],
        offset_gradient[[2L]] - offset_gradient[[3L]])
    }
    optimized <- tryCatch(
      phase14_remediation_with_seed(seed, function() stats::optim(
        par = c(1, 1, 1, 0, 0), fn = objective, gr = gradient, method = "L-BFGS-B",
        lower = c(rep(contract$vector_slope_bounds[[1L]], 3L), rep(contract$vector_offset_bounds[[1L]], 2L)),
        upper = c(rep(contract$vector_slope_bounds[[2L]], 3L), rep(contract$vector_offset_bounds[[2L]], 2L))
      )),
      error = function(error) error
    )
    if (inherits(optimized, "error") || length(optimized$par) != 5L ||
        any(!is.finite(optimized$par)) || !identical(as.integer(optimized$convergence), 0L) ||
        !is.finite(optimized$value)) {
      identity$valid <- FALSE
      identity$fit_status <- "raw_fallback"
      identity$fallback_reason <- "optimizer_invalid"
      identity$optimizer_convergence_message <- if (inherits(optimized, "error")) conditionMessage(optimized) else "invalid_optimizer_state"
      return(identity)
    }
    offsets <- c(as.numeric(optimized$par[4:5]), -sum(as.numeric(optimized$par[4:5])))
    identity$slope_home <- as.numeric(optimized$par[[1L]])
    identity$slope_draw <- as.numeric(optimized$par[[2L]])
    identity$slope_away <- as.numeric(optimized$par[[3L]])
    identity$offset_home <- offsets[[1L]]
    identity$offset_draw <- offsets[[2L]]
    identity$offset_away <- offsets[[3L]]
    identity$optimizer_convergence_code <- as.integer(optimized$convergence)
    identity$optimizer_convergence_message <- if (is.null(optimized$message) || !nzchar(optimized$message)) "converged" else as.character(optimized$message)
    identity$optimizer_objective_value <- as.numeric(optimized$value)
    return(identity)
  }
  stop("Phase 14 remediation candidate family is invalid", call. = FALSE)
}

phase14_remediation_fit_value <- function(fit, field) {
  value <- fit[[field]]
  if (is.data.frame(fit)) value[[1L]] else value
}

phase14_remediation_apply_fit <- function(fit, probabilities) {
  if (is.null(names(probabilities)) || !setequal(names(probabilities), c("home", "draw", "away"))) {
    stop("Phase 14 remediation probabilities must be named home, draw, and away", call. = FALSE)
  }
  probabilities <- validate_probability_vector(probabilities[c("home", "draw", "away")], name = "Phase 14 remediation raw probabilities")
  family <- as.character(phase14_remediation_fit_value(fit, "selected_family"))
  if (family == "raw_identity") return(probabilities)
  if (family == "scalar_temperature") {
    temperature <- as.numeric(phase14_remediation_fit_value(fit, "temperature"))
    contract <- phase14_calibration_remediation_contract()
    if (!is.finite(temperature) || temperature < contract$temperature_bounds[[1L]] || temperature > contract$temperature_bounds[[2L]]) {
      stop("Phase 14 remediation scalar temperature is invalid", call. = FALSE)
    }
    return(phase12_temperature_transform(probabilities, temperature))
  }
  if (family == "vector_scaling") {
    slopes <- as.numeric(c(
      phase14_remediation_fit_value(fit, "slope_home"),
      phase14_remediation_fit_value(fit, "slope_draw"),
      phase14_remediation_fit_value(fit, "slope_away")
    ))
    offsets <- as.numeric(c(
      phase14_remediation_fit_value(fit, "offset_home"),
      phase14_remediation_fit_value(fit, "offset_draw"),
      phase14_remediation_fit_value(fit, "offset_away")
    ))
    contract <- phase14_calibration_remediation_contract()
    if (any(!is.finite(slopes)) || any(slopes < contract$vector_slope_bounds[[1L]] | slopes > contract$vector_slope_bounds[[2L]]) ||
        any(!is.finite(offsets)) || any(offsets[1:2] < contract$vector_offset_bounds[[1L]] | offsets[1:2] > contract$vector_offset_bounds[[2L]]) ||
        abs(sum(offsets)) > 1e-12) {
      stop("Phase 14 remediation vector parameters are not identifiable or in bounds", call. = FALSE)
    }
    logits <- slopes * log(pmax(probabilities, 1e-15)) + offsets
    logits <- logits - max(logits)
    values <- exp(logits)
    values <- values / sum(values)
    names(values) <- c("home", "draw", "away")
    return(validate_probability_vector(values, name = "Phase 14 remediation vector probabilities"))
  }
  stop("Phase 14 remediation selected family is invalid", call. = FALSE)
}

phase14_remediation_apply_rows <- function(fit, rows) {
  probabilities <- as.matrix(rows[, c("p_home", "p_draw", "p_away")])
  storage.mode(probabilities) <- "double"
  if (any(!is.finite(probabilities)) || any(probabilities <= 0 | probabilities >= 1) ||
      any(abs(rowSums(probabilities) - 1) > 1e-10)) {
    stop("Phase 14 remediation row probabilities do not form a finite simplex", call. = FALSE)
  }
  family <- as.character(phase14_remediation_fit_value(fit, "selected_family"))
  if (family == "raw_identity") return(probabilities)
  contract <- phase14_calibration_remediation_contract()
  row_softmax <- function(logits) {
    logits <- logits - apply(logits, 1L, max)
    values <- exp(logits)
    values / rowSums(values)
  }
  if (family == "scalar_temperature") {
    temperature <- as.numeric(phase14_remediation_fit_value(fit, "temperature"))
    if (!is.finite(temperature) || temperature < contract$temperature_bounds[[1L]] ||
        temperature > contract$temperature_bounds[[2L]]) {
      stop("Phase 14 remediation scalar temperature is invalid", call. = FALSE)
    }
    return(row_softmax(log(probabilities) / temperature))
  }
  if (family == "vector_scaling") {
    slopes <- as.numeric(c(
      phase14_remediation_fit_value(fit, "slope_home"),
      phase14_remediation_fit_value(fit, "slope_draw"),
      phase14_remediation_fit_value(fit, "slope_away")
    ))
    offsets <- as.numeric(c(
      phase14_remediation_fit_value(fit, "offset_home"),
      phase14_remediation_fit_value(fit, "offset_draw"),
      phase14_remediation_fit_value(fit, "offset_away")
    ))
    if (any(!is.finite(slopes)) || any(slopes < contract$vector_slope_bounds[[1L]] |
                                        slopes > contract$vector_slope_bounds[[2L]]) ||
        any(!is.finite(offsets)) || any(offsets[1:2] < contract$vector_offset_bounds[[1L]] |
                                          offsets[1:2] > contract$vector_offset_bounds[[2L]]) ||
        abs(sum(offsets)) > 1e-12) {
      stop("Phase 14 remediation vector parameters are not identifiable or in bounds", call. = FALSE)
    }
    logits <- sweep(log(probabilities), 2L, slopes, `*`)
    logits <- sweep(logits, 2L, offsets, `+`)
    return(row_softmax(logits))
  }
  stop("Phase 14 remediation selected family is invalid", call. = FALSE)
}

phase14_remediation_panel_sha256 <- function(panel) {
  columns <- c(
    "edition_id", "fixture_id", "scheduled_date", "actual_completion_date",
    "regulation_home_goals", "regulation_away_goals", "observed_class",
    "p_home", "p_draw", "p_away", "score_distribution_id", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status"
  )
  phase14_calibration_revision_table_sha256(panel[, columns, drop = FALSE], c("edition_id", "fixture_id"))
}

phase14_remediation_comparison <- function(
    rows, calibrated_probabilities, protocol = phase12_selection_protocol()
) {
  if (!is.data.frame(rows) || !nrow(rows) || nrow(calibrated_probabilities) != nrow(rows)) {
    stop("Phase 14 remediation comparison requires complete inner predictions", call. = FALSE)
  }
  identity_columns <- phase12_selection_expected_identity()
  phase14_calibration_revision_require_columns(
    rows,
    c(identity_columns, "p_home", "p_draw", "p_away"),
    "Phase 14 remediation comparison rows"
  )
  raw <- rows[, c(identity_columns, "p_home", "p_draw", "p_away"), drop = FALSE]
  calibrated <- raw
  calibrated[, c("p_home", "p_draw", "p_away")] <- calibrated_probabilities
  identity <- phase12_selection_identity(raw, calibrated, as.character(rows$fixture_id))
  raw_scores <- phase14_calibration_revision_score_view(raw, rows, "raw_1x2")
  calibrated_scores <- phase14_calibration_revision_score_view(calibrated, rows, "calibrated_1x2")
  editions <- unique(as.character(rows$edition_id))
  raw_summaries <- aggregate_benchmark_scores(raw_scores, editions)
  calibrated_summaries <- aggregate_benchmark_scores(calibrated_scores, editions)
  raw_calibration <- fixed_benchmark_calibration(raw, rows, as.character(rows$fixture_id))
  calibrated_calibration <- fixed_benchmark_calibration(calibrated, rows, as.character(rows$fixture_id))
  raw_headline <- stats::setNames(vapply(c("rps", "brier", "log_loss"), function(metric) {
    phase12_selection_metric_headline(raw_summaries, metric)
  }, numeric(1)), c("rps", "brier", "log_loss"))
  calibrated_headline <- stats::setNames(vapply(c("rps", "brier", "log_loss"), function(metric) {
    phase12_selection_metric_headline(calibrated_summaries, metric)
  }, numeric(1)), c("rps", "brier", "log_loss"))
  tournament_metric <- function(summaries, metric) {
    subset <- summaries[
      summaries$target == "regulation_1x2" & summaries$metric == metric &
        summaries$grain == "tournament",
      c("edition_id", "estimate"),
      drop = FALSE
    ]
    subset[match(editions, subset$edition_id), , drop = FALSE]
  }
  raw_fold <- tournament_metric(raw_summaries, "rps")
  calibrated_fold <- tournament_metric(calibrated_summaries, "rps")
  if (anyNA(raw_fold$edition_id) || anyNA(calibrated_fold$edition_id)) {
    stop("Phase 14 remediation comparison fold evidence is incomplete", call. = FALSE)
  }
  fold_delta <- as.numeric(calibrated_fold$estimate) - as.numeric(raw_fold$estimate)
  comparison <- list(
    candidate_id = "open_nb_incumbent",
    track_id = "updating",
    run_id = as.character(raw$run_id[[1L]]),
    panel_id = "open_core",
    raw_predictions = raw,
    calibrated_predictions = calibrated,
    raw_scores = raw_scores,
    calibrated_scores = calibrated_scores,
    raw_summaries = raw_summaries,
    calibrated_summaries = calibrated_summaries,
    raw_calibration = raw_calibration,
    calibrated_calibration = calibrated_calibration,
    raw_headline = raw_headline,
    calibrated_headline = calibrated_headline,
    raw_calibration_values = phase12_selection_calibration_values(raw_calibration),
    calibrated_calibration_values = phase12_selection_calibration_values(calibrated_calibration),
    paired_rps = list(
      breadth = data.frame(maximum_fold_regression = max(fold_delta)),
      bootstrap = data.frame(
        estimate = mean(fold_delta), lower = min(fold_delta), upper = max(fold_delta)
      )
    ),
    expected_fixture_ids = as.character(rows$fixture_id),
    expected_editions = editions,
    coverage_numerator = length(unique(rows$fixture_id)),
    coverage_denominator = nrow(rows),
    coverage_valid = length(unique(rows$fixture_id)) == nrow(rows),
    calibration_support_valid = TRUE,
    distribution_unchanged = TRUE,
    identity = identity
  )
  list(
    comparison = comparison,
    decision = phase12_selection_decision(comparison, protocol = protocol)
  )
}

phase14_remediation_fast_metrics <- function(rows, probabilities) {
  probabilities <- as.matrix(probabilities)
  storage.mode(probabilities) <- "double"
  if (nrow(probabilities) != nrow(rows) || ncol(probabilities) != 3L ||
      any(!is.finite(probabilities)) || any(probabilities <= 0 | probabilities >= 1) ||
      any(abs(rowSums(probabilities) - 1) > 1e-10)) {
    stop("Phase 14 remediation fast metrics require a complete probability simplex", call. = FALSE)
  }
  observed_index <- match(as.character(rows$observed_class), c("home", "draw", "away"))
  if (anyNA(observed_index)) stop("Phase 14 remediation fast metrics require valid classes", call. = FALSE)
  observed <- matrix(0, nrow = nrow(rows), ncol = 3L)
  observed[cbind(seq_len(nrow(rows)), observed_index)] <- 1
  rps <- rowMeans((cbind(probabilities[, 1L], rowSums(probabilities[, 1:2, drop = FALSE])) -
    cbind(observed[, 1L], rowSums(observed[, 1:2, drop = FALSE])))^2)
  brier <- rowSums((probabilities - observed)^2)
  log_loss <- -log(pmax(probabilities[cbind(seq_len(nrow(rows)), observed_index)], 1e-15))
  editions <- unique(as.character(rows$edition_id))
  tournament_mean <- function(values) {
    stats::setNames(vapply(editions, function(edition) {
      mean(values[as.character(rows$edition_id) == edition])
    }, numeric(1)), editions)
  }
  tournament <- list(
    rps = tournament_mean(rps), brier = tournament_mean(brier),
    log_loss = tournament_mean(log_loss)
  )
  edition_sizes <- table(as.character(rows$edition_id))
  weights <- 1 / (3 * as.numeric(edition_sizes[as.character(rows$edition_id)]))
  class_errors <- vapply(seq_len(3L), function(class_index) {
    bins <- pmin(floor(probabilities[, class_index] * 10), 9L) + 1L
    weighted_probability <- tapply(weights * probabilities[, class_index], bins, sum)
    weighted_observed <- tapply(weights * observed[, class_index], bins, sum)
    sum(abs(weighted_probability - weighted_observed)) / sum(weights)
  }, numeric(1))
  names(class_errors) <- c("home", "draw", "away")
  list(
    headline = c(
      rps = mean(tournament$rps), brier = mean(tournament$brier),
      log_loss = mean(tournament$log_loss)
    ),
    tournament = tournament,
    calibration = list(
      calibration_error = mean(class_errors),
      home_calibration_error = class_errors[["home"]],
      draw_calibration_error = class_errors[["draw"]],
      away_calibration_error = class_errors[["away"]],
      n_fixtures = nrow(rows), n_tournaments = length(editions)
    )
  )
}

phase14_remediation_decision_from_validated_protocol <- function(comparison, protocol) {
  if (!is.list(protocol) || is.null(protocol$core_gate$maximum_fold_regression$value) ||
      is.null(protocol$supporting_vetoes$brier_relative_change$value) ||
      is.null(protocol$supporting_vetoes$log_loss_relative_change$value)) {
    stop("Phase 14 remediation requires the validated Phase 12 protocol", call. = FALSE)
  }
  validated_protocol <- protocol
  decision_environment <- new.env(parent = environment(phase12_selection_decision))
  decision_environment$phase12_selection_protocol <- function(protocol = NULL) {
    validated_protocol
  }
  unchanged_decision <- phase12_selection_decision
  environment(unchanged_decision) <- decision_environment
  unchanged_decision(comparison, protocol = validated_protocol)
}

phase14_remediation_fast_decision <- function(
    rows, calibrated_probabilities, protocol = phase12_selection_protocol()
) {
  raw_probabilities <- as.matrix(rows[, c("p_home", "p_draw", "p_away")])
  raw <- phase14_remediation_fast_metrics(rows, raw_probabilities)
  calibrated <- phase14_remediation_fast_metrics(rows, calibrated_probabilities)
  editions <- unique(as.character(rows$edition_id))
  fold_delta <- calibrated$tournament$rps[editions] - raw$tournament$rps[editions]
  comparison <- list(
    candidate_id = "open_nb_incumbent", track_id = "updating",
    raw_headline = raw$headline, calibrated_headline = calibrated$headline,
    raw_calibration_values = raw$calibration,
    calibrated_calibration_values = calibrated$calibration,
    paired_rps = list(
      breadth = data.frame(maximum_fold_regression = max(fold_delta)),
      bootstrap = data.frame(
        estimate = mean(fold_delta), lower = min(fold_delta), upper = max(fold_delta)
      )
    ),
    coverage_numerator = length(unique(as.character(rows$fixture_id))),
    coverage_denominator = nrow(rows),
    coverage_valid = length(unique(as.character(rows$fixture_id))) == nrow(rows),
    calibration_support_valid = TRUE, distribution_unchanged = TRUE,
    identity = list(score_distribution_identity_match = TRUE)
  )
  list(
    comparison = comparison,
    decision = phase14_remediation_decision_from_validated_protocol(comparison, protocol)
  )
}

phase14_remediation_inner_folds <- function(panel, outer_index, editions) {
  validation_editions <- if (outer_index <= 1L) character() else editions[seq_len(outer_index - 1L)]
  if (!length(validation_editions)) {
    return(data.frame(
      inner_validation_edition_id = character(), inner_validation_index = integer(),
      inner_training_editions = character(), inner_training_map_entry = character(),
      training_row_count = integer(), training_class_count_home = integer(),
      training_class_count_draw = integer(), training_class_count_away = integer(),
      training_max_sequence = integer(), stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(validation_editions, function(validation) {
    validation_index <- match(validation, editions)
    training_editions <- if (validation_index <= 1L) character() else editions[seq_len(validation_index - 1L)]
    training <- panel[panel$edition_id %in% training_editions, , drop = FALSE]
    support <- phase14_remediation_support(training)
    data.frame(
      inner_validation_edition_id = validation,
      inner_validation_index = validation_index,
      inner_training_editions = phase14_remediation_join_ids(training_editions),
      inner_training_map_entry = phase14_remediation_inner_map(validation, editions),
      training_row_count = support[["rows"]],
      training_class_count_home = support[["home"]],
      training_class_count_draw = support[["draw"]],
      training_class_count_away = support[["away"]],
      training_max_sequence = if (length(training_editions)) validation_index - 1L else 0L,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

phase14_remediation_candidate_score <- function(
    candidate, inner_folds, panel, editions, outer_index, contract,
    fit_cache = new.env(parent = emptyenv()),
    protocol = phase12_selection_protocol()
) {
  family <- as.character(candidate$family[[1L]])
  empty <- data.frame(
    candidate_id = as.character(candidate$candidate_id[[1L]]),
    family = family,
    warmup_rows = as.integer(candidate$warmup_rows[[1L]]),
    scalar_shrinkage = as.numeric(candidate$scalar_shrinkage[[1L]]),
    vector_penalty = as.numeric(candidate$vector_penalty[[1L]]),
    complexity_rank = as.integer(candidate$complexity_rank[[1L]]),
    candidate_order = as.integer(candidate$candidate_order[[1L]]),
    valid_inner_validation_count = 0L,
    valid_inner_validation_editions = "",
    inner_optimizer_seeds = "",
    inner_convergence_codes = "",
    eligible = FALSE,
    eligibility_reason = if (family == "raw_identity") "identity_baseline" else "insufficient_nested_support",
    reason_codes = "",
    ranking_rps = NA_real_,
    ranking_calibration_error = NA_real_,
    ranking_log_loss = NA_real_,
    ranking_brier = NA_real_,
    fold_stability_max_regression = NA_real_,
    stringsAsFactors = FALSE
  )
  if (family == "raw_identity") return(empty)
  validation_rows <- list()
  probabilities <- list()
  valid_editions <- character()
  seeds <- integer()
  convergence <- integer()
  optimizer_invalid <- FALSE
  for (fold_index in seq_len(nrow(inner_folds))) {
    fold <- inner_folds[fold_index, , drop = FALSE]
    support <- c(
      rows = as.integer(fold$training_row_count[[1L]]),
      home = as.integer(fold$training_class_count_home[[1L]]),
      draw = as.integer(fold$training_class_count_draw[[1L]]),
      away = as.integer(fold$training_class_count_away[[1L]])
    )
    if (support[["rows"]] < as.integer(candidate$warmup_rows[[1L]]) ||
        any(support[c("home", "draw", "away")] < contract$minimum_class_count)) next
    training_editions <- phase14_remediation_split_ids(fold$inner_training_editions[[1L]])
    training <- panel[panel$edition_id %in% training_editions, , drop = FALSE]
    validation <- panel[
      panel$edition_id == as.character(fold$inner_validation_edition_id[[1L]]),
      ,
      drop = FALSE
    ]
    if (nrow(training) && any(training$actual_completion_date >= min(validation$scheduled_date))) {
      stop("Phase 14 remediation inner fit is not strictly prior to validation", call. = FALSE)
    }
    seed <- phase14_remediation_seed(
      outer_index = outer_index,
      inner_validation_index = as.integer(fold$inner_validation_index[[1L]]),
      family = family,
      warmup_rows = candidate$warmup_rows[[1L]],
      scalar_shrinkage = candidate$scalar_shrinkage[[1L]],
      vector_penalty = candidate$vector_penalty[[1L]],
      stage = "inner"
    )
    cache_key <- paste(
      phase14_remediation_join_ids(training_editions), family,
      phase14_remediation_scalar(candidate$scalar_shrinkage[[1L]]),
      phase14_remediation_scalar(candidate$vector_penalty[[1L]]),
      sep = "|"
    )
    if (exists(cache_key, envir = fit_cache, inherits = FALSE)) {
      fit <- get(cache_key, envir = fit_cache, inherits = FALSE)
      fit$optimizer_seed <- as.integer(seed)
    } else {
      fit <- phase14_remediation_fit_candidate(training, candidate, seed, contract)
      assign(cache_key, fit, envir = fit_cache)
    }
    if (!isTRUE(fit$valid)) {
      optimizer_invalid <- TRUE
      next
    }
    validation_rows[[length(validation_rows) + 1L]] <- validation
    probabilities[[length(probabilities) + 1L]] <- phase14_remediation_apply_rows(
      c(list(selected_family = family), fit), validation
    )
    valid_editions <- c(valid_editions, as.character(fold$inner_validation_edition_id[[1L]]))
    seeds <- c(seeds, seed)
    convergence <- c(convergence, as.integer(fit$optimizer_convergence_code))
  }
  empty$valid_inner_validation_count <- length(valid_editions)
  empty$valid_inner_validation_editions <- phase14_remediation_join_ids(valid_editions)
  empty$inner_optimizer_seeds <- phase14_remediation_join_ids(seeds)
  empty$inner_convergence_codes <- phase14_remediation_join_ids(convergence)
  if (length(valid_editions) < contract$minimum_inner_validation_tournaments) {
    empty$eligibility_reason <- if (optimizer_invalid) "optimizer_invalid" else "insufficient_nested_support"
    return(empty)
  }
  evidence <- do.call(rbind, validation_rows)
  calibrated <- do.call(rbind, probabilities)
  scored <- phase14_remediation_fast_decision(evidence, calibrated, protocol = protocol)
  decision <- scored$decision
  empty$reason_codes <- phase14_remediation_join_ids(decision$reason_codes)
  empty$eligible <- !length(decision$reason_codes)
  empty$eligibility_reason <- if (empty$eligible) "eligible" else "unchanged_phase12_veto"
  empty$ranking_rps <- as.numeric(scored$comparison$calibrated_headline[["rps"]])
  empty$ranking_calibration_error <- as.numeric(scored$comparison$calibrated_calibration_values$calibration_error)
  empty$ranking_log_loss <- as.numeric(scored$comparison$calibrated_headline[["log_loss"]])
  empty$ranking_brier <- as.numeric(scored$comparison$calibrated_headline[["brier"]])
  empty$fold_stability_max_regression <- as.numeric(decision$max_fold_regression)
  empty
}

phase14_remediation_fit_record_sha256 <- function(fit_record) {
  if (!is.data.frame(fit_record) || nrow(fit_record) != 1L) {
    stop("Phase 14 remediation fit hash requires one row", call. = FALSE)
  }
  phase14_calibration_revision_table_sha256(
    fit_record[, setdiff(names(fit_record), "fit_record_sha256"), drop = FALSE]
  )
}

phase14_remediation_selection_sha256 <- function(selection) {
  phase14_calibration_revision_table_sha256(
    selection[, setdiff(names(selection), "selection_row_sha256"), drop = FALSE]
  )
}

#' Validate one replay-sufficient outer-fold fit record.
#' @export
phase14_remediation_validate_fit_record <- function(
    fit_record, panel = phase14_build_incumbent_development_panel(),
    contract = phase14_calibration_remediation_contract()
) {
  required <- c(
    "schema_version", "outer_edition_id", "outer_index",
    "outer_training_editions", "inner_validation_editions", "inner_training_map",
    "outer_training_row_count", "outer_training_class_count_home",
    "outer_training_class_count_draw", "outer_training_class_count_away",
    "selected_candidate_id", "selected_family", "warmup_rows",
    "scalar_shrinkage", "vector_penalty", "fit_status", "fallback_reason",
    "optimizer_method", "optimizer_seed", "optimizer_convergence_code",
    "optimizer_objective_value", "temperature", "slope_home", "slope_draw",
    "slope_away", "offset_home", "offset_draw", "offset_away",
    "source_panel_sha256", "fit_record_sha256"
  )
  phase14_calibration_revision_require_columns(
    fit_record, required, "Phase 14 remediation fit record"
  )
  if (!is.data.frame(fit_record) || nrow(fit_record) != 1L ||
      !identical(as.character(fit_record$schema_version[[1L]]), "phase14-outer-fold-fit-v2")) {
    stop("Phase 14 remediation fit record must be one versioned row", call. = FALSE)
  }
  panel <- phase14_remediation_prepare_panel(panel)
  editions <- phase14_remediation_panel_editions(panel)
  outer <- as.character(fit_record$outer_edition_id[[1L]])
  outer_index <- match(outer, editions)
  if (is.na(outer_index) || !identical(as.integer(fit_record$outer_index[[1L]]), as.integer(outer_index))) {
    stop("Phase 14 remediation fit outer tournament is not registered", call. = FALSE)
  }
  expected_prior <- if (outer_index <= 1L) character() else editions[seq_len(outer_index - 1L)]
  if (!identical(phase14_remediation_split_ids(fit_record$outer_training_editions[[1L]]), expected_prior) ||
      !identical(phase14_remediation_split_ids(fit_record$inner_validation_editions[[1L]]), expected_prior) ||
      !identical(as.character(fit_record$inner_training_map[[1L]]),
                 phase14_remediation_inner_map(expected_prior, editions))) {
    stop("Phase 14 remediation fit training and inner folds must be strictly prior to the outer tournament", call. = FALSE)
  }
  training <- panel[panel$edition_id %in% expected_prior, , drop = FALSE]
  if (nrow(training) && any(training$actual_completion_date >= min(panel$scheduled_date[panel$edition_id == outer]))) {
    stop("Phase 14 remediation fit training is not strictly prior to the outer tournament", call. = FALSE)
  }
  support <- phase14_remediation_support(training)
  recorded_support <- as.integer(c(
    fit_record$outer_training_row_count[[1L]],
    fit_record$outer_training_class_count_home[[1L]],
    fit_record$outer_training_class_count_draw[[1L]],
    fit_record$outer_training_class_count_away[[1L]]
  ))
  if (!identical(recorded_support, as.integer(support[c("rows", "home", "draw", "away")]))) {
    stop("Phase 14 remediation fit training support does not replay", call. = FALSE)
  }
  if (!identical(as.character(fit_record$source_panel_sha256[[1L]]),
                 phase14_remediation_panel_sha256(panel))) {
    stop("Phase 14 remediation fit source panel hash does not replay", call. = FALSE)
  }
  candidate_index <- match(
    as.character(fit_record$selected_candidate_id[[1L]]),
    as.character(contract$candidates$candidate_id)
  )
  if (is.na(candidate_index)) {
    stop("Phase 14 remediation fit selected candidate is outside the frozen grid", call. = FALSE)
  }
  candidate <- contract$candidates[candidate_index, , drop = FALSE]
  same_numeric <- function(recorded, expected) {
    if (is.na(expected)) is.na(recorded) else isTRUE(all.equal(as.numeric(recorded), as.numeric(expected), tolerance = 0))
  }
  if (!identical(as.character(fit_record$selected_family[[1L]]), as.character(candidate$family[[1L]])) ||
      !same_numeric(fit_record$warmup_rows[[1L]], candidate$warmup_rows[[1L]]) ||
      !same_numeric(fit_record$scalar_shrinkage[[1L]], candidate$scalar_shrinkage[[1L]]) ||
      !same_numeric(fit_record$vector_penalty[[1L]], candidate$vector_penalty[[1L]])) {
    stop("Phase 14 remediation fit family or hyperparameters drifted from the frozen grid", call. = FALSE)
  }
  expected_seed <- phase14_remediation_seed(
    outer_index = outer_index, inner_validation_index = 0L,
    family = candidate$family[[1L]], warmup_rows = candidate$warmup_rows[[1L]],
    scalar_shrinkage = candidate$scalar_shrinkage[[1L]],
    vector_penalty = candidate$vector_penalty[[1L]], stage = "outer_fit"
  )
  if (!identical(as.integer(fit_record$optimizer_seed[[1L]]), expected_seed)) {
    stop("Phase 14 remediation optimizer seed does not replay", call. = FALSE)
  }
  family <- as.character(candidate$family[[1L]])
  slopes <- as.numeric(fit_record[1L, c("slope_home", "slope_draw", "slope_away")])
  offsets <- as.numeric(fit_record[1L, c("offset_home", "offset_draw", "offset_away")])
  if (family == "raw_identity") {
    if (!identical(as.character(fit_record$fit_status[[1L]]), "raw_fallback") ||
        !identical(as.character(fit_record$optimizer_method[[1L]]), "not_run") ||
        !is.na(fit_record$optimizer_convergence_code[[1L]]) ||
        !isTRUE(all.equal(c(as.numeric(fit_record$temperature[[1L]]), slopes, offsets),
                          c(1, 1, 1, 1, 0, 0, 0), tolerance = 0))) {
      stop("Phase 14 remediation raw fallback fit is not an immutable identity", call. = FALSE)
    }
  } else {
    if (!identical(as.character(fit_record$fit_status[[1L]]), "fitted") ||
        !identical(as.character(fit_record$optimizer_method[[1L]]), contract$optimizer_method) ||
        !identical(as.integer(fit_record$optimizer_convergence_code[[1L]]), 0L) ||
        !is.finite(as.numeric(fit_record$optimizer_objective_value[[1L]]))) {
      stop("Phase 14 remediation optimizer convergence evidence is invalid", call. = FALSE)
    }
    if (family == "scalar_temperature" &&
        (!is.finite(fit_record$temperature[[1L]]) ||
         fit_record$temperature[[1L]] < contract$temperature_bounds[[1L]] ||
         fit_record$temperature[[1L]] > contract$temperature_bounds[[2L]])) {
      stop("Phase 14 remediation scalar fit is outside the frozen parameter bounds", call. = FALSE)
    }
    if (family == "vector_scaling" &&
        (any(!is.finite(slopes)) || any(slopes < contract$vector_slope_bounds[[1L]] |
                                         slopes > contract$vector_slope_bounds[[2L]]) ||
         any(!is.finite(offsets)) || any(offsets[1:2] < contract$vector_offset_bounds[[1L]] |
                                           offsets[1:2] > contract$vector_offset_bounds[[2L]]) ||
         abs(sum(offsets)) > 1e-12)) {
      stop("Phase 14 remediation vector fit is not identifiable or in bounds", call. = FALSE)
    }
  }
  if (!identical(as.character(fit_record$fit_record_sha256[[1L]]),
                 phase14_remediation_fit_record_sha256(fit_record))) {
    stop("Phase 14 remediation fit record hash does not replay", call. = FALSE)
  }
  invisible(TRUE)
}

#' Select and fit one outer tournament using nested strictly-prior folds only.
#' @export
phase14_select_nested_calibrator <- function(
    panel = phase14_build_incumbent_development_panel(), outer_edition_id,
    contract = phase14_calibration_remediation_contract(),
    fit_cache = new.env(parent = emptyenv()),
    protocol = phase12_selection_protocol()
) {
  panel <- phase14_remediation_prepare_panel(panel)
  editions <- phase14_remediation_panel_editions(panel)
  outer_edition_id <- as.character(outer_edition_id)
  outer_index <- match(outer_edition_id, editions)
  if (is.na(outer_index)) stop("Phase 14 remediation outer edition is not registered", call. = FALSE)
  outer_open <- min(panel$scheduled_date[panel$edition_id == outer_edition_id])
  prior <- if (outer_index <= 1L) character() else editions[seq_len(outer_index - 1L)]
  training <- panel[panel$edition_id %in% prior, , drop = FALSE]
  assessment <- panel[panel$edition_id == outer_edition_id, , drop = FALSE]
  if (nrow(training) && any(training$actual_completion_date >= outer_open)) {
    stop("Phase 14 remediation outer training evidence must be strictly prior", call. = FALSE)
  }
  inner_folds <- phase14_remediation_inner_folds(panel, outer_index, editions)
  candidate_scores <- do.call(rbind, lapply(seq_len(nrow(contract$candidates)), function(i) {
    phase14_remediation_candidate_score(
      contract$candidates[i, , drop = FALSE], inner_folds, panel, editions,
      outer_index, contract, fit_cache = fit_cache, protocol = protocol
    )
  }))
  eligible <- candidate_scores[candidate_scores$eligible, , drop = FALSE]
  fallback_reason <- ""
  if (nrow(eligible)) {
    eligible <- eligible[order(
      eligible$ranking_rps,
      eligible$ranking_calibration_error,
      eligible$ranking_log_loss,
      eligible$ranking_brier,
      eligible$complexity_rank,
      eligible$candidate_order,
      method = "radix"
    ), , drop = FALSE]
    chosen <- eligible[1L, , drop = FALSE]
  } else {
    chosen <- candidate_scores[candidate_scores$family == "raw_identity", , drop = FALSE]
    fallback_reason <- if (all(candidate_scores$valid_inner_validation_count < contract$minimum_inner_validation_tournaments)) {
      "insufficient_nested_support"
    } else if (any(candidate_scores$eligibility_reason == "optimizer_invalid")) {
      "optimizer_invalid"
    } else "no_eligible_improvement"
  }
  candidate <- contract$candidates[match(chosen$candidate_id, contract$candidates$candidate_id), , drop = FALSE]
  support <- phase14_remediation_support(training)
  seed <- phase14_remediation_seed(
    outer_index = outer_index,
    inner_validation_index = 0L,
    family = as.character(candidate$family[[1L]]),
    warmup_rows = candidate$warmup_rows[[1L]],
    scalar_shrinkage = candidate$scalar_shrinkage[[1L]],
    vector_penalty = candidate$vector_penalty[[1L]],
    stage = "outer_fit"
  )
  fit <- phase14_remediation_fit_candidate(training, candidate, seed, contract)
  if (!isTRUE(fit$valid) || as.character(candidate$family[[1L]]) == "raw_identity") {
    if (!isTRUE(fit$valid)) fallback_reason <- "optimizer_invalid"
    candidate <- contract$candidates[contract$candidates$family == "raw_identity", , drop = FALSE]
    seed <- phase14_remediation_seed(
      outer_index = outer_index, inner_validation_index = 0L,
      family = candidate$family[[1L]], warmup_rows = candidate$warmup_rows[[1L]],
      scalar_shrinkage = candidate$scalar_shrinkage[[1L]],
      vector_penalty = candidate$vector_penalty[[1L]], stage = "outer_fit"
    )
    fit <- phase14_remediation_fit_candidate(training, candidate, seed, contract)
    fit$fallback_reason <- if (nzchar(fallback_reason)) fallback_reason else "no_eligible_improvement"
    fit$fit_status <- "raw_fallback"
  }
  selected_family <- as.character(candidate$family[[1L]])
  fit_record <- data.frame(
    schema_version = "phase14-outer-fold-fit-v2",
    outer_edition_id = outer_edition_id,
    outer_index = as.integer(outer_index),
    outer_training_editions = phase14_remediation_join_ids(prior),
    inner_validation_editions = phase14_remediation_join_ids(prior),
    inner_training_map = phase14_remediation_inner_map(prior, editions),
    outer_training_row_count = as.integer(support[["rows"]]),
    outer_training_class_count_home = as.integer(support[["home"]]),
    outer_training_class_count_draw = as.integer(support[["draw"]]),
    outer_training_class_count_away = as.integer(support[["away"]]),
    selected_candidate_id = as.character(candidate$candidate_id[[1L]]),
    selected_family = selected_family,
    warmup_rows = as.integer(candidate$warmup_rows[[1L]]),
    scalar_shrinkage = as.numeric(candidate$scalar_shrinkage[[1L]]),
    vector_penalty = as.numeric(candidate$vector_penalty[[1L]]),
    ranking_rps = as.numeric(chosen$ranking_rps[[1L]]),
    ranking_calibration_error = as.numeric(chosen$ranking_calibration_error[[1L]]),
    ranking_log_loss = as.numeric(chosen$ranking_log_loss[[1L]]),
    ranking_brier = as.numeric(chosen$ranking_brier[[1L]]),
    fold_stability_max_regression = as.numeric(chosen$fold_stability_max_regression[[1L]]),
    fit_status = as.character(fit$fit_status),
    fallback_reason = as.character(fit$fallback_reason),
    optimizer_method = as.character(fit$optimizer_method),
    optimizer_seed = as.integer(fit$optimizer_seed),
    optimizer_convergence_code = as.integer(fit$optimizer_convergence_code),
    optimizer_convergence_message = as.character(fit$optimizer_convergence_message),
    optimizer_objective_value = as.numeric(fit$optimizer_objective_value),
    temperature = as.numeric(fit$temperature),
    slope_home = as.numeric(fit$slope_home),
    slope_draw = as.numeric(fit$slope_draw),
    slope_away = as.numeric(fit$slope_away),
    offset_home = as.numeric(fit$offset_home),
    offset_draw = as.numeric(fit$offset_draw),
    offset_away = as.numeric(fit$offset_away),
    source_panel_sha256 = phase14_remediation_panel_sha256(panel),
    fit_record_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  fit_record$fit_record_sha256 <- phase14_remediation_fit_record_sha256(fit_record)
  calibrated <- phase14_remediation_apply_rows(fit_record, assessment)
  predictions <- assessment
  predictions$p_home_calibrated <- calibrated[, 1L]
  predictions$p_draw_calibrated <- calibrated[, 2L]
  predictions$p_away_calibrated <- calibrated[, 3L]
  predictions$selected_family <- selected_family
  predictions$selected_candidate_id <- as.character(candidate$candidate_id[[1L]])
  predictions$fit_record_sha256 <- fit_record$fit_record_sha256[[1L]]
  predictions$outer_training_editions <- fit_record$outer_training_editions[[1L]]
  predictions$inner_validation_editions <- fit_record$inner_validation_editions[[1L]]
  predictions$inner_training_map <- fit_record$inner_training_map[[1L]]
  selection <- fit_record[, setdiff(names(fit_record), c(
    "schema_version", "fit_record_sha256", "temperature", "slope_home", "slope_draw",
    "slope_away", "offset_home", "offset_draw", "offset_away"
  )), drop = FALSE]
  names(selection)[names(selection) == "source_panel_sha256"] <- "selection_source_panel_sha256"
  selection$schema_version <- "phase14-outer-fold-selection-v2"
  selection$valid_inner_validation_count <- as.integer(chosen$valid_inner_validation_count[[1L]])
  selection$valid_inner_validation_editions <- as.character(chosen$valid_inner_validation_editions[[1L]])
  selection$eligibility_reason <- if (selected_family == "raw_identity") as.character(fit$fallback_reason) else "eligible"
  selection$selection_row_sha256 <- ""
  selection$selection_row_sha256 <- phase14_remediation_selection_sha256(selection)
  phase14_remediation_validate_fit_record(fit_record, panel)
  list(
    selection = selection,
    fit = fit_record,
    predictions = predictions,
    candidate_scores = candidate_scores,
    inner_folds = inner_folds
  )
}

phase14_remediation_output_paths <- function(
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"
) {
  root <- phase14_remediation_resolve_path(output_root)
  c(
    remediation_contract = file.path(root, "remediation_contract.csv"),
    outer_fold_selection = file.path(root, "outer_fold_selection.csv"),
    outer_fold_fits = file.path(root, "outer_fold_fits.csv"),
    calibrator = file.path(root, "calibrator.rds"),
    calibrated_predictions = file.path(root, "calibrated_predictions.csv"),
    calibration_gate = file.path(root, "calibration_gate.csv"),
    revision_manifest = file.path(root, "calibration_revision_manifest.csv")
  )
}

phase14_remediation_rank_eligible <- function(candidate_scores) {
  eligible <- candidate_scores[candidate_scores$eligible, , drop = FALSE]
  if (!nrow(eligible)) return(eligible)
  eligible[order(
    eligible$ranking_rps,
    eligible$ranking_calibration_error,
    eligible$ranking_log_loss,
    eligible$ranking_brier,
    eligible$complexity_rank,
    eligible$candidate_order,
    method = "radix"
  ), , drop = FALSE]
}

phase14_remediation_final_fit <- function(
    panel, contract, protocol, fit_cache = new.env(parent = emptyenv())
) {
  editions <- phase14_remediation_panel_editions(panel)
  outer_index <- length(editions) + 1L
  inner_folds <- phase14_remediation_inner_folds(panel, outer_index, editions)
  candidate_scores <- do.call(rbind, lapply(seq_len(nrow(contract$candidates)), function(i) {
    phase14_remediation_candidate_score(
      contract$candidates[i, , drop = FALSE], inner_folds, panel, editions,
      outer_index, contract, fit_cache = fit_cache, protocol = protocol
    )
  }))
  eligible <- phase14_remediation_rank_eligible(candidate_scores)
  if (!nrow(eligible)) {
    stop("Phase 14 remediation outer pass has no eligible final fitted recipe", call. = FALSE)
  }
  chosen <- eligible[1L, , drop = FALSE]
  candidate <- contract$candidates[
    match(chosen$candidate_id, contract$candidates$candidate_id), , drop = FALSE
  ]
  if (identical(as.character(candidate$family[[1L]]), "raw_identity")) {
    stop("Phase 14 remediation outer pass cannot authorize an unfitted final identity", call. = FALSE)
  }
  seed <- phase14_remediation_seed(
    outer_index = outer_index, inner_validation_index = 0L,
    family = candidate$family[[1L]], warmup_rows = candidate$warmup_rows[[1L]],
    scalar_shrinkage = candidate$scalar_shrinkage[[1L]],
    vector_penalty = candidate$vector_penalty[[1L]], stage = "final_fit"
  )
  fit <- phase14_remediation_fit_candidate(panel, candidate, seed, contract)
  if (!isTRUE(fit$valid) || !identical(as.integer(fit$optimizer_convergence_code), 0L)) {
    stop("Phase 14 remediation final optimizer did not converge after the outer pass", call. = FALSE)
  }
  list(candidate = candidate, chosen = chosen, fit = fit, candidate_scores = candidate_scores)
}

phase14_remediation_calibrator <- function(
    panel, decision, contract, protocol, fit_cache = new.env(parent = emptyenv())
) {
  common <- list(
    schema_version = "phase14-calibration-remediation-calibrator-v2",
    model_id = "open_nb_incumbent", track_id = "updating", panel_id = "open_core",
    development_row_count = 630L, development_fixture_count = 630L,
    score_support = 40L, distribution_unchanged = TRUE,
    probability_view = "derived_1x2", outer_gate_passed = isTRUE(decision$calibration_promoted),
    calibration_promoted = isTRUE(decision$calibration_promoted),
    primary_probability_view = as.character(decision$primary_probability_view),
    final_fit_performed = FALSE, candidate_authority = FALSE,
    failed_result_immutable = !isTRUE(decision$calibration_promoted),
    holdout_labels_used = FALSE, authority_mutated = FALSE,
    source_panel_sha256 = phase14_remediation_panel_sha256(panel),
    protocol_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/promotion_protocol.json"
    ),
    calibration_evidence_cutoff = as.character(max(panel$actual_completion_date)),
    model_data_cutoff = "2026-06-10"
  )
  if (!isTRUE(decision$calibration_promoted)) {
    return(c(common, list(
      fit_status = "raw_fallback", fallback_reason = phase14_remediation_join_ids(decision$reason_codes),
      selected_candidate_id = "raw_identity", selected_family = "raw_identity",
      warmup_rows = 0L, scalar_shrinkage = NA_real_, vector_penalty = NA_real_,
      optimizer_method = "not_run", optimizer_seed = NA_integer_,
      optimizer_convergence_code = NA_integer_, optimizer_convergence_message = "not_run",
      optimizer_objective_value = NA_real_, temperature = 1,
      slope_home = 1, slope_draw = 1, slope_away = 1,
      offset_home = 0, offset_draw = 0, offset_away = 0
    )))
  }
  final <- phase14_remediation_final_fit(panel, contract, protocol, fit_cache)
  candidate <- final$candidate
  fit <- final$fit
  common$final_fit_performed <- TRUE
  common$failed_result_immutable <- FALSE
  c(common, list(
    fit_status = "fitted", fallback_reason = "",
    selected_candidate_id = as.character(candidate$candidate_id[[1L]]),
    selected_family = as.character(candidate$family[[1L]]),
    warmup_rows = as.integer(candidate$warmup_rows[[1L]]),
    scalar_shrinkage = as.numeric(candidate$scalar_shrinkage[[1L]]),
    vector_penalty = as.numeric(candidate$vector_penalty[[1L]]),
    optimizer_method = as.character(fit$optimizer_method),
    optimizer_seed = as.integer(fit$optimizer_seed),
    optimizer_convergence_code = as.integer(fit$optimizer_convergence_code),
    optimizer_convergence_message = as.character(fit$optimizer_convergence_message),
    optimizer_objective_value = as.numeric(fit$optimizer_objective_value),
    temperature = as.numeric(fit$temperature),
    slope_home = as.numeric(fit$slope_home), slope_draw = as.numeric(fit$slope_draw),
    slope_away = as.numeric(fit$slope_away), offset_home = as.numeric(fit$offset_home),
    offset_draw = as.numeric(fit$offset_draw), offset_away = as.numeric(fit$offset_away),
    final_nested_candidate_scores_sha256 = phase14_calibration_revision_table_sha256(
      final$candidate_scores, c("candidate_id")
    )
  ))
}

phase14_remediation_gate_row <- function(comparison, calibrator, protocol) {
  gate <- phase14_calibration_revision_gate_row(
    comparison, calibrator = calibrator, chronology_valid = TRUE, protocol = protocol
  )
  gate$schema_version <- "phase14-calibration-remediation-gate-v2"
  gate$outer_gate_passed <- isTRUE(gate$calibration_promoted[[1L]])
  gate$final_fit_performed <- isTRUE(calibrator$final_fit_performed)
  gate$failed_result_immutable <- isTRUE(calibrator$failed_result_immutable)
  gate$candidate_authority <- FALSE
  gate$row_sha256 <- NULL
  gate$row_sha256 <- phase14_calibration_revision_table_sha256(gate)
  gate
}

phase14_remediation_manifest <- function(output_root, gate, calibrator) {
  paths <- phase14_remediation_output_paths(output_root)
  required <- paths[setdiff(names(paths), "revision_manifest")]
  if (any(!file.exists(required))) {
    stop("Phase 14 remediation manifest requires every candidate artifact", call. = FALSE)
  }
  panel <- phase14_remediation_prepare_panel(phase14_build_incumbent_development_panel())
  manifest <- data.frame(
    schema_version = "phase14-calibration-remediation-manifest-v2",
    model_id = "open_nb_incumbent", track_id = "updating", panel_id = "open_core",
    disposition = as.character(gate$disposition[[1L]]),
    reason_codes = as.character(gate$reason_codes[[1L]]),
    reason_count = as.integer(gate$reason_count[[1L]]),
    development_row_count = 630L, unique_fixture_count = 630L,
    outer_fold_count = 12L, fit_record_count = 12L,
    outer_gate_passed = isTRUE(gate$outer_gate_passed[[1L]]),
    final_fit_performed = isTRUE(calibrator$final_fit_performed),
    calibration_promoted = isTRUE(gate$calibration_promoted[[1L]]),
    primary_probability_view = as.character(gate$primary_probability_view[[1L]]),
    fit_status = as.character(calibrator$fit_status),
    holdout_labels_used = FALSE, authority_mutated = FALSE, candidate_authority = FALSE,
    source_predictions_file_sha256 = phase14_calibration_revision_file_sha256(
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv"
    ),
    source_predictions_slice_sha256 = phase14_remediation_panel_sha256(panel),
    fixtures_file_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/fixtures.csv"
    ),
    freeze_manifest_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase12/freeze_manifest.csv"
    ),
    calibration_recipe_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase12/calibration_recipe.json"
    ),
    protocol_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/promotion_protocol.json"
    ),
    model_registry_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/model_registry.csv"
    ),
    seed_registry_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/seed_registry.csv"
    ),
    phase12_selector_sha256 = phase14_calibration_revision_file_sha256(
      "R/calibration/calibration_selection.R"
    ),
    original_revision_code_sha256 = phase14_calibration_revision_file_sha256(
      "R/release/calibration_revision.R"
    ),
    original_gate_sha256 = phase14_calibration_revision_file_sha256(
      "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv"
    ),
    original_manifest_sha256 = phase14_calibration_revision_file_sha256(
      "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv"
    ),
    remediation_code_sha256 = phase14_calibration_revision_file_sha256(
      "R/release/calibration_remediation.R"
    ),
    remediation_contract_sha256 = phase14_calibration_revision_file_sha256(
      paths[["remediation_contract"]]
    ),
    outer_fold_selection_sha256 = phase14_calibration_revision_file_sha256(
      paths[["outer_fold_selection"]]
    ),
    outer_fold_fits_sha256 = phase14_calibration_revision_file_sha256(
      paths[["outer_fold_fits"]]
    ),
    calibrator_sha256 = phase14_calibration_revision_file_sha256(paths[["calibrator"]]),
    calibrated_predictions_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibrated_predictions"]]
    ),
    calibration_gate_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibration_gate"]]
    ),
    code_commit = phase14_calibration_revision_git_commit(),
    manifest_self_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest$manifest_self_sha256 <- phase14_calibration_revision_manifest_self_hash(manifest)
  manifest
}

phase14_remediation_read_csv <- function(path, name) {
  if (!file.exists(path)) stop(name, " is missing", call. = FALSE)
  utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = c("NA")
  )
}

phase14_remediation_compare_gate <- function(actual, expected) {
  fields <- setdiff(names(expected), c("code_commit", "row_sha256"))
  phase14_calibration_revision_require_columns(actual, fields, "Phase 14 remediation gate")
  numeric_fields <- c(
    "expected_row_count", "observed_row_count", "unique_fixture_count",
    "raw_headline_rps", "calibrated_headline_rps", "rps_delta",
    "raw_headline_brier", "calibrated_headline_brier", "brier_relative_change",
    "raw_headline_log_loss", "calibrated_headline_log_loss", "log_loss_relative_change",
    "fold_stability_max_regression", "raw_calibration_error",
    "calibrated_calibration_error", "calibration_error_delta", "reason_count",
    "score_support_g"
  )
  for (field in fields) {
    matches <- if (field %in% numeric_fields) {
      isTRUE(all.equal(as.numeric(actual[[field]]), as.numeric(expected[[field]]), tolerance = 1e-12))
    } else {
      identical(as.character(actual[[field]]), as.character(expected[[field]]))
    }
    if (!matches) stop("Phase 14 remediation gate decision drifted: ", field, call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate the complete immutable calibration-remediation candidate graph.
#' @export
phase14_validate_calibration_remediation <- function(
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2",
    require_promoted = FALSE
) {
  paths <- phase14_remediation_output_paths(output_root)
  if (any(!file.exists(paths))) {
    stop("Phase 14 remediation artifact graph is incomplete", call. = FALSE)
  }
  panel <- phase14_remediation_prepare_panel(phase14_build_incumbent_development_panel())
  editions <- phase14_remediation_panel_editions(panel)
  contract <- phase14_remediation_read_csv(paths[["remediation_contract"]], "Phase 14 remediation contract")
  selection <- phase14_remediation_read_csv(paths[["outer_fold_selection"]], "Phase 14 outer selection")
  fits <- phase14_remediation_read_csv(paths[["outer_fold_fits"]], "Phase 14 outer fits")
  predictions <- phase14_remediation_read_csv(
    paths[["calibrated_predictions"]], "Phase 14 remediation predictions"
  )
  gate <- phase14_remediation_read_csv(paths[["calibration_gate"]], "Phase 14 remediation gate")
  manifest <- phase14_remediation_read_csv(paths[["revision_manifest"]], "Phase 14 remediation manifest")
  calibrator <- readRDS(paths[["calibrator"]])
  if ("reason_codes" %in% names(gate)) gate$reason_codes[is.na(gate$reason_codes)] <- ""
  if ("reason_codes" %in% names(manifest)) manifest$reason_codes[is.na(manifest$reason_codes)] <- ""

  expected_contract <- phase14_remediation_contract_table()
  if (nrow(contract) != 45L || anyDuplicated(contract$candidate_id) ||
      !identical(as.character(contract$candidate_id), as.character(expected_contract$candidate_id))) {
    stop("Phase 14 remediation frozen contract identity drifted", call. = FALSE)
  }
  for (i in seq_len(nrow(contract))) {
    expected_hash <- phase14_calibration_revision_table_sha256(
      contract[i, setdiff(names(contract), "contract_row_sha256"), drop = FALSE]
    )
    if (!identical(tolower(as.character(contract$contract_row_sha256[[i]])), tolower(expected_hash))) {
      stop("Phase 14 remediation contract row hash mismatch", call. = FALSE)
    }
  }
  if (nrow(selection) != 12L || nrow(fits) != 12L ||
      !identical(as.character(selection$outer_edition_id), editions) ||
      !identical(as.character(fits$outer_edition_id), editions)) {
    stop("Phase 14 remediation requires one canonical selection and fit per outer tournament", call. = FALSE)
  }
  fit_link_fields <- c(
    "outer_training_editions", "inner_validation_editions", "inner_training_map",
    "selected_candidate_id", "selected_family", "warmup_rows", "scalar_shrinkage",
    "vector_penalty", "fit_status", "fallback_reason", "optimizer_seed"
  )
  for (i in seq_len(12L)) {
    fit <- fits[i, , drop = FALSE]
    phase14_remediation_validate_fit_record(fit, panel)
    selection_hash <- phase14_remediation_selection_sha256(selection[i, , drop = FALSE])
    if (!identical(
      tolower(as.character(selection$selection_row_sha256[[i]])), tolower(selection_hash)
    )) {
      stop("Phase 14 remediation selection row hash mismatch", call. = FALSE)
    }
    for (field in fit_link_fields) {
      if (!identical(as.character(selection[[field]][[i]]), as.character(fit[[field]][[1L]]))) {
        stop("Phase 14 remediation selection-to-fit lineage drifted: ", field, call. = FALSE)
      }
    }
    if (!identical(
      tolower(as.character(selection$fit_record_sha256[[i]])),
      tolower(as.character(fit$fit_record_sha256[[1L]]))
    )) {
      stop("Phase 14 remediation selection-to-fit hash link drifted", call. = FALSE)
    }
    outer_open <- min(panel$scheduled_date[panel$edition_id == editions[[i]]])
    expected_max <- if (i == 1L) "" else as.character(max(
      panel$actual_completion_date[panel$edition_id %in% editions[seq_len(i - 1L)]]
    ))
    if (!identical(as.character(selection$outer_open_date[[i]]), as.character(outer_open)) ||
        !identical(as.character(selection$outer_training_max_completion_date[[i]]), expected_max)) {
      stop("Phase 14 remediation selection date cutoff drifted", call. = FALSE)
    }
  }
  if (nrow(predictions) != 630L || anyDuplicated(as.character(predictions$fixture_id)) ||
      !identical(as.character(predictions$fixture_id), as.character(panel$fixture_id)) ||
      phase14_calibration_revision_has_holdout_identity(predictions)) {
    stop("Phase 14 remediation prediction identity is invalid", call. = FALSE)
  }
  identity_columns <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_over_2_5", "p_under_2_5", "p_btts", "prediction_status"
  )
  for (field in identity_columns) {
    if (!identical(as.character(predictions[[field]]), as.character(panel[[field]]))) {
      stop("Phase 14 remediation raw/distribution identity drifted: ", field, call. = FALSE)
    }
  }
  for (field in c("p_home", "p_draw", "p_away")) {
    if (!isTRUE(all.equal(as.numeric(predictions[[field]]), as.numeric(panel[[field]]), tolerance = 0))) {
      stop("Phase 14 remediation raw probability identity drifted: ", field, call. = FALSE)
    }
  }
  calibrated_columns <- c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated")
  calibrated <- as.matrix(predictions[, calibrated_columns, drop = FALSE])
  storage.mode(calibrated) <- "double"
  if (any(!is.finite(calibrated)) || any(calibrated <= 0 | calibrated >= 1) ||
      any(abs(rowSums(calibrated) - 1) > 1e-12)) {
    stop("Phase 14 remediation calibrated probability simplex is invalid", call. = FALSE)
  }
  for (i in seq_len(12L)) {
    rows <- panel[panel$edition_id == editions[[i]], , drop = FALSE]
    replay <- phase14_remediation_apply_rows(fits[i, , drop = FALSE], rows)
    persisted <- calibrated[match(rows$fixture_id, predictions$fixture_id), , drop = FALSE]
    if (!isTRUE(all.equal(unname(replay), unname(persisted), tolerance = 1e-12))) {
      stop("Phase 14 remediation outer fit replay mismatch", call. = FALSE)
    }
  }
  if (!is.list(calibrator) || !identical(as.character(calibrator$model_id), "open_nb_incumbent") ||
      !identical(as.character(calibrator$track_id), "updating") ||
      !identical(as.character(calibrator$panel_id), "open_core") ||
      !identical(as.integer(calibrator$development_row_count), 630L) ||
      !identical(as.integer(calibrator$development_fixture_count), 630L) ||
      !identical(as.integer(calibrator$score_support), 40L) ||
      isTRUE(calibrator$holdout_labels_used) || isTRUE(calibrator$authority_mutated) ||
      !identical(as.character(calibrator$source_panel_sha256), phase14_remediation_panel_sha256(panel))) {
    stop("Phase 14 remediation calibrator identity is invalid", call. = FALSE)
  }
  protocol <- phase12_selection_protocol()
  comparison <- phase14_remediation_comparison(panel, calibrated, protocol = protocol)
  expected_gate <- phase14_remediation_gate_row(comparison$comparison, calibrator, protocol)
  if (nrow(gate) != 1L) stop("Phase 14 remediation requires one gate row", call. = FALSE)
  gate_hash <- phase14_calibration_revision_table_sha256(
    gate[, setdiff(names(gate), "row_sha256"), drop = FALSE]
  )
  if (!identical(tolower(as.character(gate$row_sha256[[1L]])), tolower(gate_hash))) {
    stop("Phase 14 remediation gate row hash mismatch", call. = FALSE)
  }
  phase14_remediation_compare_gate(gate, expected_gate)
  promoted <- phase14_calibration_revision_as_logical(gate$calibration_promoted[[1L]])
  if (promoted) {
    if (!identical(as.character(calibrator$fit_status), "fitted") ||
        !isTRUE(calibrator$final_fit_performed) || !isTRUE(calibrator$outer_gate_passed) ||
        !identical(as.character(gate$primary_probability_view[[1L]]), "calibrated_1x2")) {
      stop("Phase 14 remediation promoted final fit is invalid", call. = FALSE)
    }
  } else if (!identical(as.character(calibrator$fit_status), "raw_fallback") ||
      isTRUE(calibrator$final_fit_performed) || isTRUE(calibrator$outer_gate_passed) ||
      !isTRUE(calibrator$failed_result_immutable) ||
      !identical(as.character(gate$primary_probability_view[[1L]]), "raw_1x2")) {
    stop("Phase 14 remediation blocked result is not immutable raw fallback", call. = FALSE)
  }
  if (isTRUE(require_promoted) && !promoted) {
    stop("Phase 14 remediation release is blocked and not promoted", call. = FALSE)
  }

  if (nrow(manifest) != 1L) stop("Phase 14 remediation requires one manifest row", call. = FALSE)
  manifest_hash <- phase14_calibration_revision_manifest_self_hash(manifest)
  if (!identical(
    tolower(as.character(manifest$manifest_self_sha256[[1L]])), tolower(manifest_hash)
  )) {
    stop("Phase 14 remediation manifest self-hash mismatch", call. = FALSE)
  }
  expected_hashes <- c(
    remediation_contract_sha256 = phase14_calibration_revision_file_sha256(paths[["remediation_contract"]]),
    outer_fold_selection_sha256 = phase14_calibration_revision_file_sha256(paths[["outer_fold_selection"]]),
    outer_fold_fits_sha256 = phase14_calibration_revision_file_sha256(paths[["outer_fold_fits"]]),
    calibrator_sha256 = phase14_calibration_revision_file_sha256(paths[["calibrator"]]),
    calibrated_predictions_sha256 = phase14_calibration_revision_file_sha256(paths[["calibrated_predictions"]]),
    calibration_gate_sha256 = phase14_calibration_revision_file_sha256(paths[["calibration_gate"]]),
    source_predictions_file_sha256 = phase14_calibration_revision_file_sha256("outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv"),
    source_predictions_slice_sha256 = phase14_remediation_panel_sha256(panel),
    fixtures_file_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase09/fixtures.csv"),
    freeze_manifest_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase12/freeze_manifest.csv"),
    calibration_recipe_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase12/calibration_recipe.json"),
    protocol_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase09/promotion_protocol.json"),
    model_registry_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase09/model_registry.csv"),
    seed_registry_sha256 = phase14_calibration_revision_file_sha256("data/benchmark/phase09/seed_registry.csv"),
    phase12_selector_sha256 = phase14_calibration_revision_file_sha256("R/calibration/calibration_selection.R"),
    original_revision_code_sha256 = phase14_calibration_revision_file_sha256("R/release/calibration_revision.R"),
    original_gate_sha256 = phase14_calibration_revision_file_sha256("outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv"),
    original_manifest_sha256 = phase14_calibration_revision_file_sha256("outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv"),
    remediation_code_sha256 = phase14_calibration_revision_file_sha256("R/release/calibration_remediation.R")
  )
  phase14_calibration_revision_require_columns(
    manifest, c(names(expected_hashes), "holdout_labels_used", "authority_mutated",
                "candidate_authority", "outer_fold_count", "fit_record_count"),
    "Phase 14 remediation manifest"
  )
  for (field in names(expected_hashes)) {
    if (!identical(tolower(as.character(manifest[[field]][[1L]])),
                   tolower(as.character(expected_hashes[[field]])))) {
      stop("Phase 14 remediation artifact or authority hash mismatch: ", field, call. = FALSE)
    }
  }
  if (phase14_calibration_revision_as_logical(manifest$holdout_labels_used[[1L]]) ||
      phase14_calibration_revision_as_logical(manifest$authority_mutated[[1L]]) ||
      phase14_calibration_revision_as_logical(manifest$candidate_authority[[1L]]) ||
      as.integer(manifest$outer_fold_count[[1L]]) != 12L ||
      as.integer(manifest$fit_record_count[[1L]]) != 12L) {
    stop("Phase 14 remediation manifest claims forbidden authority or incomplete folds", call. = FALSE)
  }
  invisible(TRUE)
}

#' Build the all-fold immutable calibration-remediation candidate graph once.
#' @export
phase14_build_calibration_remediation <- function(
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-remediation-v2"
) {
  final_root <- phase14_remediation_resolve_path(output_root)
  if (file.exists(final_root) || dir.exists(final_root)) {
    stop("Phase 14 remediation output root already exists and is immutable", call. = FALSE)
  }
  parent <- dirname(final_root)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  staging_root <- file.path(parent, paste0(".", basename(final_root), "-staging-", Sys.getpid()))
  if (file.exists(staging_root) || dir.exists(staging_root)) {
    stop("Phase 14 remediation staging root already exists", call. = FALSE)
  }
  dir.create(staging_root, recursive = TRUE, showWarnings = FALSE)
  keep_staging <- FALSE
  on.exit({
    if (!keep_staging && dir.exists(staging_root)) unlink(staging_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  panel <- phase14_remediation_prepare_panel(phase14_build_incumbent_development_panel())
  editions <- phase14_remediation_panel_editions(panel)
  contract <- phase14_calibration_remediation_contract()
  protocol <- phase12_selection_protocol()
  fit_cache <- new.env(parent = emptyenv())
  selections <- vector("list", length(editions))
  fits <- vector("list", length(editions))
  predictions <- vector("list", length(editions))
  for (i in seq_along(editions)) {
    result <- phase14_select_nested_calibrator(
      panel, editions[[i]], contract = contract, fit_cache = fit_cache, protocol = protocol
    )
    selection <- result$selection
    outer_rows <- panel[panel$edition_id == editions[[i]], , drop = FALSE]
    prior <- if (i == 1L) character() else editions[seq_len(i - 1L)]
    training <- panel[panel$edition_id %in% prior, , drop = FALSE]
    selection$outer_open_date <- as.character(min(outer_rows$scheduled_date))
    selection$outer_training_max_completion_date <- if (nrow(training)) {
      as.character(max(training$actual_completion_date))
    } else ""
    selection$fit_record_sha256 <- result$fit$fit_record_sha256[[1L]]
    selection$selection_row_sha256 <- ""
    selection$selection_row_sha256 <- phase14_remediation_selection_sha256(selection)
    selections[[i]] <- selection
    fits[[i]] <- result$fit
    predictions[[i]] <- result$predictions
  }
  selection_table <- do.call(rbind, selections)
  fit_table <- do.call(rbind, fits)
  prediction_table <- do.call(rbind, predictions)
  prediction_table <- prediction_table[
    match(as.character(panel$fixture_id), as.character(prediction_table$fixture_id)), , drop = FALSE
  ]
  rownames(selection_table) <- NULL
  rownames(fit_table) <- NULL
  rownames(prediction_table) <- NULL
  calibrated <- as.matrix(prediction_table[, c(
    "p_home_calibrated", "p_draw_calibrated", "p_away_calibrated"
  )])
  storage.mode(calibrated) <- "double"
  comparison <- phase14_remediation_comparison(panel, calibrated, protocol = protocol)
  decision <- comparison$decision
  calibrator <- phase14_remediation_calibrator(
    panel, decision, contract, protocol, fit_cache = fit_cache
  )
  gate <- phase14_remediation_gate_row(comparison$comparison, calibrator, protocol)

  staging_paths <- phase14_remediation_output_paths(staging_root)
  phase14_calibration_revision_write_csv(
    phase14_remediation_contract_table(contract), staging_paths[["remediation_contract"]]
  )
  phase14_calibration_revision_write_csv(selection_table, staging_paths[["outer_fold_selection"]])
  phase14_calibration_revision_write_csv(fit_table, staging_paths[["outer_fold_fits"]])
  saveRDS(calibrator, staging_paths[["calibrator"]], version = 2)
  phase14_calibration_revision_write_csv(
    prediction_table, staging_paths[["calibrated_predictions"]]
  )
  phase14_calibration_revision_write_csv(gate, staging_paths[["calibration_gate"]])
  manifest <- phase14_remediation_manifest(staging_root, gate, calibrator)
  phase14_calibration_revision_write_csv(manifest, staging_paths[["revision_manifest"]])
  phase14_validate_calibration_remediation(staging_root, require_promoted = FALSE)
  if (!file.rename(staging_root, final_root)) {
    stop("Phase 14 remediation atomic publish failed", call. = FALSE)
  }
  keep_staging <- TRUE
  list(
    output_root = final_root,
    paths = phase14_remediation_output_paths(final_root),
    decision = decision, gate = gate, calibrator = calibrator,
    selected_families = stats::setNames(as.character(fit_table$selected_family), editions)
  )
}
