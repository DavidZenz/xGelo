# Independent Phase 14 calibration-remediation acceptance authority.
#
# Deliberately limited to frozen inputs and Phase 12 score/decision primitives.
# The Phase 14 remediation implementation is an untrusted opaque artifact here.

if (!exists(".reference_phase14_acceptance_cache", inherits = FALSE)) {
  .reference_phase14_acceptance_cache <- new.env(parent = emptyenv())
}

reference_phase14_repo_root <- function(path = ".") {
  candidate <- normalizePath(path, mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Cannot locate xGelo project root", call. = FALSE)
    candidate <- parent
  }
}

reference_phase14_source_phase12 <- function(project_root = reference_phase14_repo_root()) {
  if (!exists("phase12_inner_oof_prediction_hash", mode = "function", inherits = TRUE)) {
    source(file.path(project_root, "R/calibration/inner_oof.R"), local = .GlobalEnv)
  }
  required <- c("canonical_benchmark_sha256", "fixed_benchmark_calibration",
                "phase12_selection_decision")
  if (!all(vapply(required, exists, logical(1), mode = "function", inherits = TRUE))) {
    source(file.path(project_root, "R/calibration/calibration_selection.R"), local = .GlobalEnv)
  }
  invisible(TRUE)
}

reference_phase14_require <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
  invisible(TRUE)
}

reference_phase14_require_columns <- function(data, columns, name) {
  reference_phase14_require(is.data.frame(data), paste0(name, " must be a data frame"))
  missing <- setdiff(columns, names(data))
  reference_phase14_require(!length(missing), paste0(name, " missing columns: ", paste(missing, collapse = ", ")))
}

reference_phase14_read_csv <- function(path, name = basename(path), character = FALSE) {
  reference_phase14_require(file.exists(path), paste0(name, " is missing"))
  args <- list(file = path, check.names = FALSE, stringsAsFactors = FALSE)
  if (character) {
    args$colClasses <- "character"
    args$na.strings <- NULL
  }
  tryCatch(do.call(utils::read.csv, args), error = function(error) {
    stop(name, " is unreadable: ", conditionMessage(error), call. = FALSE)
  })
}

reference_phase14_file_sha256 <- function(path) {
  reference_phase14_require(requireNamespace("digest", quietly = TRUE), "digest is required")
  reference_phase14_require(file.exists(path), paste0("Hash input is missing: ", path))
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

reference_phase14_table_sha256 <- function(data, order_by = character()) {
  reference_phase14_require(requireNamespace("digest", quietly = TRUE), "digest is required")
  reference_phase14_require(is.data.frame(data), "Canonical hash input must be a data frame")
  if (length(order_by)) {
    reference_phase14_require(all(order_by %in% names(data)), "Canonical hash ordering column is missing")
    ordering <- do.call(order, c(lapply(data[order_by], as.character), list(method = "radix")))
    data <- data[ordering, , drop = FALSE]
  }
  values <- lapply(data, function(value) {
    if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
    if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    value <- as.character(value)
    value[is.na(value)] <- "<NA>"
    value
  })
  rows <- if (nrow(data)) vapply(seq_len(nrow(data)), function(i) {
    paste(vapply(values, `[[`, character(1), i), collapse = "\u001f")
  }, character(1)) else character()
  digest::digest(paste(c(names(data), rows), collapse = "\u001e"),
                 algo = "sha256", serialize = FALSE)
}

reference_phase14_row_sha256 <- function(data, hash_column) {
  vapply(seq_len(nrow(data)), function(i) {
    reference_phase14_table_sha256(data[i, setdiff(names(data), hash_column), drop = FALSE])
  }, character(1))
}

reference_phase14_split <- function(value, separator = "\\|") {
  value <- as.character(value %||% "")
  if (!length(value) || is.na(value[[1L]]) || !nzchar(value[[1L]])) return(character())
  strsplit(value[[1L]], separator, perl = TRUE)[[1L]]
}

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

reference_phase14_numeric_equal <- function(actual, expected, tolerance, label) {
  actual <- as.numeric(actual)
  expected <- as.numeric(expected)
  same_na <- is.na(actual) & is.na(expected)
  ok <- same_na | (!is.na(actual) & !is.na(expected) & is.finite(actual) & is.finite(expected) &
                    abs(actual - expected) <= tolerance)
  reference_phase14_require(length(actual) == length(expected) && all(ok),
                            paste0(label, " differs from independent reconstruction"))
}

reference_phase14_character_equal <- function(actual, expected, label) {
  actual <- as.character(actual)
  expected <- as.character(expected)
  actual[is.na(actual)] <- ""
  expected[is.na(expected)] <- ""
  reference_phase14_require(identical(actual, expected),
                            paste0(label, " differs from independent reconstruction"))
}

reference_phase14_bool <- function(value) {
  if (is.logical(value)) return(value)
  tolower(as.character(value)) == "true"
}

reference_phase14_candidate_id_scalar <- function(warmup, shrinkage) {
  paste0("scalar_w", warmup, "_s", gsub("\\.", "p", sprintf("%.2f", shrinkage)))
}

reference_phase14_candidate_id_vector <- function(warmup, penalty) {
  paste0("vector_w", warmup, "_p", gsub("\\.", "p", sprintf("%.3f", penalty)))
}

reference_phase14_contract <- function() {
  warmups <- c(60L, 128L, 256L, 400L)
  shrinkages <- c(0.25, 0.50, 0.75, 1.00)
  penalties <- c(0.001, 0.010, 0.050, 0.100, 0.500, 1.000, 5.000)
  candidates <- list(data.frame(
    candidate_id = "raw_identity", family = "raw_identity", warmup_rows = 0L,
    scalar_shrinkage = NA_real_, vector_penalty = NA_real_, complexity_rank = 1L,
    candidate_order = 1L, stringsAsFactors = FALSE
  ))
  candidates <- c(candidates, lapply(seq_along(warmups), function(wi) {
    do.call(rbind, lapply(seq_along(shrinkages), function(si) data.frame(
      candidate_id = reference_phase14_candidate_id_scalar(warmups[[wi]], shrinkages[[si]]),
      family = "scalar_temperature", warmup_rows = warmups[[wi]],
      scalar_shrinkage = shrinkages[[si]], vector_penalty = NA_real_,
      complexity_rank = 2L, candidate_order = (wi - 1L) * length(shrinkages) + si,
      stringsAsFactors = FALSE
    )))
  }))
  candidates <- c(candidates, lapply(seq_along(warmups), function(wi) {
    do.call(rbind, lapply(seq_along(penalties), function(pi) data.frame(
      candidate_id = reference_phase14_candidate_id_vector(warmups[[wi]], penalties[[pi]]),
      family = "vector_scaling", warmup_rows = warmups[[wi]],
      scalar_shrinkage = NA_real_, vector_penalty = penalties[[pi]],
      complexity_rank = 3L, candidate_order = (wi - 1L) * length(penalties) + pi,
      stringsAsFactors = FALSE
    )))
  }))
  candidates <- do.call(rbind, candidates)
  rownames(candidates) <- NULL
  constants <- data.frame(
    schema_version = "phase14-calibration-remediation-contract-v2",
    family_order = "raw_identity|scalar_temperature|vector_scaling",
    warmup_grid = "60|128|256|400", scalar_shrinkage_grid = "0.25|0.50|0.75|1.00",
    vector_penalty_grid = "0.001|0.010|0.050|0.100|0.500|1.000|5.000",
    temperature_bounds = "0.25|4", vector_slope_bounds = "0.25|4",
    vector_offset_bounds = "-2|2", minimum_class_count = 10L,
    minimum_inner_validation_tournaments = 2L, optimizer_method = "stats::optim-L-BFGS-B",
    scalar_transform = "exp(shrinkage*bounded_log_temperature)",
    vector_transform = "softmax(slopes*log(raw_probability)+zero_sum_offsets)",
    vector_penalty_target = "sum((slopes-1)^2)+sum(offsets^2)",
    tie_break_order = "rps|calibration_error|log_loss|brier|complexity_rank",
    seed_base = 142100L, seed_algorithm = "seed_base_plus_sha256_first_7_hex_mod_2147483646",
    stringsAsFactors = FALSE
  )
  expected <- cbind(constants[rep(1L, nrow(candidates)), , drop = FALSE], candidates)
  expected <- expected[, c(
    "schema_version", "candidate_id", "family", "warmup_rows", "scalar_shrinkage",
    "vector_penalty", "complexity_rank", "candidate_order", "family_order", "warmup_grid",
    "scalar_shrinkage_grid", "vector_penalty_grid", "temperature_bounds", "vector_slope_bounds",
    "vector_offset_bounds", "minimum_class_count", "minimum_inner_validation_tournaments",
    "optimizer_method", "scalar_transform", "vector_transform", "vector_penalty_target",
    "tie_break_order", "seed_base", "seed_algorithm"
  )]
  expected$contract_row_sha256 <- reference_phase14_row_sha256(
    transform(expected, contract_row_sha256 = ""), "contract_row_sha256"
  )
  list(candidates = candidates, persisted = expected, seed_base = 142100L,
       minimum_class_count = 10L, minimum_inner = 2L)
}

reference_phase14_compare_contract <- function(actual, expected) {
  reference_phase14_require(identical(names(actual), names(expected)), "Remediation contract schema differs")
  reference_phase14_character_equal(actual$candidate_id, expected$candidate_id, "Candidate order")
  numeric_columns <- c("warmup_rows", "scalar_shrinkage", "vector_penalty", "complexity_rank",
                       "candidate_order", "minimum_class_count", "minimum_inner_validation_tournaments",
                       "seed_base")
  for (column in numeric_columns) {
    reference_phase14_numeric_equal(actual[[column]], expected[[column]], 0, paste("Contract", column))
  }
  for (column in setdiff(names(expected), c(numeric_columns, "contract_row_sha256"))) {
    reference_phase14_character_equal(actual[[column]], expected[[column]], paste("Contract", column))
  }
  reference_phase14_character_equal(
    actual$contract_row_sha256,
    reference_phase14_row_sha256(actual, "contract_row_sha256"),
    "Contract row hash"
  )
  invisible(TRUE)
}

reference_phase14_observed_class <- function(home, away) {
  ifelse(home > away, "home", ifelse(home < away, "away", "draw"))
}

reference_phase14_panel <- function(project_root = reference_phase14_repo_root()) {
  reference_phase14_source_phase12(project_root)
  predictions_path <- file.path(project_root,
    "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv")
  fixtures_path <- file.path(project_root, "data/benchmark/phase09/fixtures.csv")
  predictions <- reference_phase14_read_csv(predictions_path, "Frozen Phase 09 predictions")
  fixtures <- reference_phase14_read_csv(fixtures_path, "Frozen Phase 09 fixtures")
  selected <- predictions[
    predictions$model_id == "open_nb_incumbent" & predictions$track_id == "updating" &
      predictions$panel_id == "open_core", , drop = FALSE
  ]
  reference_phase14_require(nrow(predictions[predictions$model_id == "open_nb_incumbent", ]) == 1260L,
                            "Incumbent source row count changed")
  reference_phase14_require(nrow(selected) == 630L && !anyDuplicated(selected$fixture_id),
                            "Raw development panel must contain 630 unique fixtures")
  reference_phase14_require(all(selected$prediction_status == "ok"), "Raw development panel is incomplete")
  reference_phase14_require(!any(grepl("wc2026", tolower(paste(selected$edition_id, selected$fixture_id)))),
                            "WC2026 holdout identity entered raw development panel")
  index <- match(selected$fixture_id, fixtures$fixture_id)
  reference_phase14_require(!anyNA(index) && nrow(fixtures) == 630L && !anyDuplicated(fixtures$fixture_id),
                            "Fixture registry does not exactly cover raw panel")
  matched <- fixtures[index, , drop = FALSE]
  reference_phase14_require(all(selected$edition_id == matched$edition_id) && all(matched$score_eligible),
                            "Fixture identities or score eligibility differ")
  probabilities <- as.matrix(selected[c("p_home", "p_draw", "p_away")])
  storage.mode(probabilities) <- "double"
  reference_phase14_require(all(is.finite(probabilities)) && all(probabilities >= 0) &&
                              all(probabilities <= 1) && max(abs(rowSums(probabilities) - 1)) <= 1e-10,
                            "Raw development probabilities are invalid")
  panel <- selected
  panel$scheduled_date <- as.Date(matched$scheduled_date)
  panel$actual_completion_date <- as.Date(matched$actual_completion_date)
  panel$regulation_home_goals <- as.integer(matched$regulation_home_goals)
  panel$regulation_away_goals <- as.integer(matched$regulation_away_goals)
  panel$score_eligible <- as.logical(matched$score_eligible)
  panel$observed_class <- reference_phase14_observed_class(
    panel$regulation_home_goals, panel$regulation_away_goals
  )
  panel$fixture_row_sha256 <- as.character(matched$row_sha256)
  source_columns <- names(selected)
  panel$source_prediction_row_sha256 <- vapply(seq_len(nrow(selected)), function(i) {
    phase12_inner_oof_prediction_hash(selected[i, source_columns, drop = FALSE], source_columns)
  }, character(1))
  edition_open <- tapply(panel$scheduled_date, panel$edition_id, min)
  editions <- names(sort(as.Date(edition_open, origin = "1970-01-01"), method = "radix"))
  expected_editions <- c("wc2002", "euro2004", "wc2006", "euro2008", "wc2010", "euro2012",
                         "wc2014", "euro2016", "wc2018", "euro2020", "wc2022", "euro2024")
  reference_phase14_require(identical(editions, expected_editions), "Development tournament chronology changed")
  panel$edition_open_date <- as.Date(edition_open[panel$edition_id], origin = "1970-01-01")
  panel$edition_sequence <- match(panel$edition_id, editions)
  panel <- panel[order(panel$edition_sequence, panel$scheduled_date, panel$fixture_id, method = "radix"), ]
  rownames(panel) <- NULL
  list(panel = panel, fixtures = fixtures, editions = editions,
       predictions_path = predictions_path, fixtures_path = fixtures_path)
}

reference_phase14_inner_map <- function(editions) {
  if (!length(editions)) return("")
  paste(vapply(seq_along(editions), function(i) {
    paste0(editions[[i]], "~", paste(editions[seq_len(i - 1L)], collapse = "+"))
  }, character(1)), collapse = ";")
}

reference_phase14_support <- function(panel) {
  counts <- table(factor(panel$observed_class, levels = c("home", "draw", "away")))
  c(rows = nrow(panel), home = unname(counts[["home"]]), draw = unname(counts[["draw"]]),
    away = unname(counts[["away"]]))
}

reference_phase14_softmax <- function(eta) {
  shifted <- eta - apply(eta, 1L, max)
  output <- exp(shifted)
  output / rowSums(output)
}

reference_phase14_apply_fit <- function(probabilities, fit) {
  probabilities <- pmax(as.matrix(probabilities), 1e-15)
  if (fit$family == "raw_identity") return(probabilities)
  if (fit$family == "scalar_temperature") {
    return(reference_phase14_softmax(log(probabilities) / fit$temperature))
  }
  eta <- sweep(log(probabilities), 2L, fit$slopes, `*`)
  eta <- sweep(eta, 2L, fit$offsets, `+`)
  reference_phase14_softmax(eta)
}

reference_phase14_seed <- function(seed_base, outer_index, inner_index, candidate) {
  # Frozen canonical schedule: all key components are explicit, ordered, and locale independent.
  scalar <- if (is.na(candidate$scalar_shrinkage[[1L]])) "NA" else sprintf("%.2f", candidate$scalar_shrinkage[[1L]])
  vector <- if (is.na(candidate$vector_penalty[[1L]])) "NA" else sprintf("%.3f", candidate$vector_penalty[[1L]])
  key <- paste(outer_index, inner_index, candidate$family[[1L]], candidate$warmup_rows[[1L]],
               scalar, vector, sep = "|")
  hash <- digest::digest(key, algo = "sha256", serialize = FALSE)
  as.integer(seed_base + (strtoi(substr(hash, 1L, 7L), base = 16L) %% 2147483646L))
}

reference_phase14_outer_seed_schedule <- function(index) {
  # Published canonical SHA-256 schedule for outer indices 1:12 and the final
  # all-development fit at index 13. These values are part of the frozen test
  # contract, not read from candidate selections or fit artifacts.
  schedule <- c(171275948L, 104347410L, 25013354L, 84027872L, 49874161L,
                249299676L, 148759012L, 264690252L, 196301648L, 110527505L,
                234015799L, 48436887L, 116450559L)
  reference_phase14_require(length(index) == 1L && index >= 1L && index <= length(schedule),
                            "Outer seed index is outside the frozen schedule")
  schedule[[as.integer(index)]]
}

reference_phase14_fit <- function(training, candidate, seed) {
  family <- candidate$family[[1L]]
  identity <- list(family = family, seed = as.integer(seed), method = "not_run",
                   convergence = NA_integer_, message = "not_run", objective = NA_real_,
                   temperature = 1, slopes = c(1, 1, 1), offsets = c(0, 0, 0), status = "raw_fallback")
  if (family == "raw_identity") return(identity)
  probabilities <- pmax(as.matrix(training[c("p_home", "p_draw", "p_away")]), 1e-15)
  log_probabilities <- log(probabilities)
  class_index <- match(training$observed_class, c("home", "draw", "away"))
  observed <- diag(3L)[class_index, , drop = FALSE]
  set.seed(as.integer(seed))
  if (family == "scalar_temperature") {
    transform <- function(theta) reference_phase14_softmax(log_probabilities / exp(theta[[1L]]))
    objective <- function(theta) {
      fitted <- transform(theta)
      -mean(log(fitted[cbind(seq_len(nrow(fitted)), class_index)]))
    }
    gradient <- function(theta) {
      fitted <- transform(theta)
      eta <- log_probabilities / exp(theta[[1L]])
      mean(rowSums((fitted - observed) * (-eta)))
    }
    result <- stats::optim(0, objective, gradient, method = "L-BFGS-B",
                           lower = log(0.25), upper = log(4))
    bounded_temperature <- exp(result$par[[1L]])
    temperature <- exp(candidate$scalar_shrinkage[[1L]] * log(bounded_temperature))
    return(list(family = family, seed = as.integer(seed), method = "stats::optim-L-BFGS-B",
                convergence = as.integer(result$convergence), message = as.character(result$message),
                objective = as.numeric(result$value), temperature = temperature,
                slopes = c(1, 1, 1), offsets = c(0, 0, 0), status = "fitted"))
  }
  penalty <- candidate$vector_penalty[[1L]]
  transform <- function(parameters) {
    eta <- sweep(log_probabilities, 2L, parameters[1:3], `*`)
    eta <- sweep(eta, 2L, c(parameters[4:5], -sum(parameters[4:5])), `+`)
    reference_phase14_softmax(eta)
  }
  objective <- function(parameters) {
    fitted <- transform(parameters)
    offsets <- c(parameters[4:5], -sum(parameters[4:5]))
    -mean(log(fitted[cbind(seq_len(nrow(fitted)), class_index)])) +
      penalty * (sum((parameters[1:3] - 1)^2) + sum(offsets^2))
  }
  gradient <- function(parameters) {
    fitted <- transform(parameters)
    error <- fitted - observed
    c(colMeans(error * log_probabilities) + 2 * penalty * (parameters[1:3] - 1),
      mean(error[, 1L] - error[, 3L]) + 2 * penalty * (2 * parameters[[4L]] + parameters[[5L]]),
      mean(error[, 2L] - error[, 3L]) + 2 * penalty * (parameters[[4L]] + 2 * parameters[[5L]]))
  }
  result <- stats::optim(c(1, 1, 1, 0, 0), objective, gradient, method = "L-BFGS-B",
                         lower = c(0.25, 0.25, 0.25, -2, -2),
                         upper = c(4, 4, 4, 2, 2))
  list(family = family, seed = as.integer(seed), method = "stats::optim-L-BFGS-B",
       convergence = as.integer(result$convergence), message = as.character(result$message),
       objective = as.numeric(result$value), temperature = 1,
       slopes = as.numeric(result$par[1:3]),
       offsets = c(as.numeric(result$par[4:5]), -sum(result$par[4:5])), status = "fitted")
}

reference_phase14_metric_values <- function(rows, probabilities) {
  class_index <- match(rows$observed_class, c("home", "draw", "away"))
  observed <- diag(3L)[class_index, , drop = FALSE]
  cumulative_probability <- cbind(probabilities[, 1L], probabilities[, 1L] + probabilities[, 2L])
  cumulative_observed <- cbind(observed[, 1L], observed[, 1L] + observed[, 2L])
  data.frame(
    edition_id = rows$edition_id,
    rps = rowMeans((cumulative_probability - cumulative_observed)^2),
    brier = rowSums((probabilities - observed)^2),
    log_loss = -log(probabilities[cbind(seq_len(nrow(probabilities)), class_index)]),
    stringsAsFactors = FALSE
  )
}

reference_phase14_candidate_evidence <- function(panel, candidate, validation_indices, cache, protocol) {
  valid <- validation_indices[vapply(validation_indices, function(index) {
    !is.null(cache[[candidate$candidate_id]][[as.character(index)]])
  }, logical(1))]
  if (length(valid) < 2L) return(NULL)
  candidate_parts <- lapply(valid, function(index) cache[[candidate$candidate_id]][[as.character(index)]]$predictions)
  candidate_rows <- do.call(rbind, candidate_parts)
  raw_rows <- panel[panel$edition_sequence %in% valid, , drop = FALSE]
  raw_rows <- raw_rows[match(candidate_rows$fixture_id, raw_rows$fixture_id), , drop = FALSE]
  candidate_probabilities <- as.matrix(candidate_rows[c("p_home", "p_draw", "p_away")])
  raw_probabilities <- as.matrix(raw_rows[c("p_home", "p_draw", "p_away")])
  candidate_metrics <- reference_phase14_metric_values(raw_rows, candidate_probabilities)
  raw_metrics <- reference_phase14_metric_values(raw_rows, raw_probabilities)
  editions <- unique(raw_rows$edition_id[order(raw_rows$edition_sequence)])
  headline <- function(metrics, column) mean(vapply(editions, function(edition) {
    mean(metrics[[column]][metrics$edition_id == edition])
  }, numeric(1)))
  candidate_headline <- vapply(c("rps", "brier", "log_loss"), function(metric) headline(candidate_metrics, metric), numeric(1))
  raw_headline <- vapply(c("rps", "brier", "log_loss"), function(metric) headline(raw_metrics, metric), numeric(1))
  candidate_view <- raw_rows
  candidate_view$p_home <- candidate_probabilities[, 1L]
  candidate_view$p_draw <- candidate_probabilities[, 2L]
  candidate_view$p_away <- candidate_probabilities[, 3L]
  raw_calibration <- fixed_benchmark_calibration(raw_rows, raw_rows, raw_rows$fixture_id)$summary$calibration_error[[1L]]
  candidate_calibration <- fixed_benchmark_calibration(candidate_view, raw_rows, raw_rows$fixture_id)$summary$calibration_error[[1L]]
  fold_regression <- max(vapply(editions, function(edition) {
    mean(candidate_metrics$rps[candidate_metrics$edition_id == edition]) -
      mean(raw_metrics$rps[raw_metrics$edition_id == edition])
  }, numeric(1)))
  brier_limit <- as.numeric(protocol$supporting_vetoes$brier_relative_change$value)
  log_limit <- as.numeric(protocol$supporting_vetoes$log_loss_relative_change$value)
  fold_limit <- as.numeric(protocol$core_gate$maximum_fold_regression$value)
  relative <- function(raw, candidate) (candidate - raw) / abs(raw)
  eligible <- candidate_headline[["rps"]] <= raw_headline[["rps"]] &&
    relative(raw_headline[["brier"]], candidate_headline[["brier"]]) <= brier_limit &&
    relative(raw_headline[["log_loss"]], candidate_headline[["log_loss"]]) <= log_limit &&
    fold_regression <= fold_limit && candidate_calibration < raw_calibration
  data.frame(candidate_id = candidate$candidate_id, family = candidate$family,
             warmup_rows = candidate$warmup_rows, scalar_shrinkage = candidate$scalar_shrinkage,
             vector_penalty = candidate$vector_penalty, complexity_rank = candidate$complexity_rank,
             candidate_order = candidate$candidate_order, ranking_rps = candidate_headline[["rps"]],
             ranking_calibration_error = candidate_calibration,
             ranking_log_loss = candidate_headline[["log_loss"]],
             ranking_brier = candidate_headline[["brier"]],
             fold_stability_max_regression = fold_regression, eligible = eligible,
             valid_inner_validation_count = length(valid),
             valid_inner_validation_editions = paste(panel$edition_id[match(valid, panel$edition_sequence)], collapse = "|"),
             stringsAsFactors = FALSE)
}

reference_phase14_fit_cache <- function(panel, contract) {
  cache <- setNames(vector("list", nrow(contract$candidates)), contract$candidates$candidate_id)
  for (candidate_index in seq_len(nrow(contract$candidates))) {
    candidate <- contract$candidates[candidate_index, , drop = FALSE]
    cache[[candidate$candidate_id]] <- list()
    if (candidate$family == "raw_identity") next
    for (validation_index in 2:12) {
      training <- panel[panel$edition_sequence < validation_index, , drop = FALSE]
      support <- reference_phase14_support(training)
      if (support[["rows"]] < candidate$warmup_rows || min(support[c("home", "draw", "away")]) < 10L) next
      seed <- reference_phase14_seed(contract$seed_base, 13L, validation_index, candidate)
      fit <- reference_phase14_fit(training, candidate, seed)
      if (fit$convergence != 0L || !is.finite(fit$objective)) next
      validation <- panel[panel$edition_sequence == validation_index, , drop = FALSE]
      probabilities <- reference_phase14_apply_fit(validation[c("p_home", "p_draw", "p_away")], fit)
      cache[[candidate$candidate_id]][[as.character(validation_index)]] <- list(
        fit = fit,
        predictions = data.frame(fixture_id = validation$fixture_id, edition_id = validation$edition_id,
                                 p_home = probabilities[, 1L], p_draw = probabilities[, 2L],
                                 p_away = probabilities[, 3L], stringsAsFactors = FALSE)
      )
    }
  }
  cache
}

reference_phase14_select <- function(panel, outer_index, contract, cache, protocol) {
  validation_indices <- seq_len(outer_index - 1L)
  evidence <- lapply(seq_len(nrow(contract$candidates)), function(index) {
    candidate <- contract$candidates[index, , drop = FALSE]
    if (candidate$family == "raw_identity") return(NULL)
    reference_phase14_candidate_evidence(panel, candidate, validation_indices, cache, protocol)
  })
  evidence <- do.call(rbind, Filter(Negate(is.null), evidence))
  eligible <- if (is.null(evidence)) evidence else evidence[evidence$eligible, , drop = FALSE]
  if (is.null(eligible) || !nrow(eligible)) return(list(candidate = contract$candidates[1L, , drop = FALSE], evidence = NULL))
  ordering <- order(eligible$ranking_rps, eligible$ranking_calibration_error,
                    eligible$ranking_log_loss, eligible$ranking_brier,
                    eligible$complexity_rank, eligible$candidate_order, method = "radix")
  winner <- eligible[ordering[1L], , drop = FALSE]
  list(candidate = contract$candidates[match(winner$candidate_id, contract$candidates$candidate_id), , drop = FALSE],
       evidence = winner)
}

reference_phase14_outer_graph <- function(panel, contract, protocol) {
  cache <- reference_phase14_fit_cache(panel, contract)
  selections <- vector("list", 12L)
  fits <- vector("list", 12L)
  predictions <- vector("list", 12L)
  for (outer_index in 1:12) {
    outer <- panel$edition_id[match(outer_index, panel$edition_sequence)]
    prior_editions <- unique(panel$edition_id[panel$edition_sequence < outer_index])
    training <- panel[panel$edition_sequence < outer_index, , drop = FALSE]
    support <- reference_phase14_support(training)
    selection <- if (outer_index <= 3L) {
      list(candidate = contract$candidates[1L, , drop = FALSE], evidence = NULL)
    } else reference_phase14_select(panel, outer_index, contract, cache, protocol)
    candidate <- selection$candidate
    fallback <- candidate$family == "raw_identity"
    fallback_reason <- if (!fallback) "" else if (outer_index <= 3L) {
      "insufficient_nested_support"
    } else "no_eligible_improvement"
    seed <- reference_phase14_outer_seed_schedule(outer_index)
    fit <- if (fallback) reference_phase14_fit(training, candidate, seed) else reference_phase14_fit(training, candidate, seed)
    valid_editions <- if (is.null(selection$evidence)) "" else selection$evidence$valid_inner_validation_editions[[1L]]
    rank_value <- function(column) if (is.null(selection$evidence)) NA_real_ else selection$evidence[[column]][[1L]]
    fit_status <- if (fallback) "raw_fallback" else "fitted"
    outer_open <- unique(panel$edition_open_date[panel$edition_sequence == outer_index])
    max_completion <- if (nrow(training)) max(training$actual_completion_date) else as.Date(NA)
    common <- data.frame(
      outer_edition_id = outer, outer_index = outer_index,
      outer_training_editions = paste(prior_editions, collapse = "|"),
      inner_validation_editions = paste(prior_editions, collapse = "|"),
      inner_training_map = reference_phase14_inner_map(prior_editions),
      outer_training_row_count = support[["rows"]],
      outer_training_class_count_home = support[["home"]],
      outer_training_class_count_draw = support[["draw"]],
      outer_training_class_count_away = support[["away"]],
      selected_candidate_id = candidate$candidate_id, selected_family = candidate$family,
      warmup_rows = candidate$warmup_rows, scalar_shrinkage = candidate$scalar_shrinkage,
      vector_penalty = candidate$vector_penalty,
      ranking_rps = rank_value("ranking_rps"),
      ranking_calibration_error = rank_value("ranking_calibration_error"),
      ranking_log_loss = rank_value("ranking_log_loss"), ranking_brier = rank_value("ranking_brier"),
      fold_stability_max_regression = rank_value("fold_stability_max_regression"),
      fit_status = fit_status, fallback_reason = fallback_reason,
      optimizer_method = fit$method, optimizer_seed = fit$seed,
      optimizer_convergence_code = fit$convergence,
      optimizer_convergence_message = fit$message, optimizer_objective_value = fit$objective,
      valid_inner_validation_count = if (is.null(selection$evidence)) 0L else selection$evidence$valid_inner_validation_count[[1L]],
      valid_inner_validation_editions = valid_editions,
      eligibility_reason = if (fallback) fallback_reason else "eligible",
      outer_open_date = outer_open, outer_training_max_completion_date = max_completion,
      stringsAsFactors = FALSE, check.names = FALSE
    )
    selections[[outer_index]] <- common
    fits[[outer_index]] <- cbind(
      schema_version = "phase14-outer-fold-fit-v2",
      common[, c("outer_edition_id", "outer_index", "outer_training_editions", "inner_validation_editions",
                 "inner_training_map", "outer_training_row_count", "outer_training_class_count_home",
                 "outer_training_class_count_draw", "outer_training_class_count_away", "selected_candidate_id",
                 "selected_family", "warmup_rows", "scalar_shrinkage", "vector_penalty", "ranking_rps",
                 "ranking_calibration_error", "ranking_log_loss", "ranking_brier", "fold_stability_max_regression",
                 "fit_status", "fallback_reason", "optimizer_method", "optimizer_seed",
                 "optimizer_convergence_code", "optimizer_convergence_message", "optimizer_objective_value")],
      temperature = fit$temperature, slope_home = fit$slopes[[1L]], slope_draw = fit$slopes[[2L]],
      slope_away = fit$slopes[[3L]], offset_home = fit$offsets[[1L]], offset_draw = fit$offsets[[2L]],
      offset_away = fit$offsets[[3L]], stringsAsFactors = FALSE
    )
    validation <- panel[panel$edition_sequence == outer_index, , drop = FALSE]
    probability <- reference_phase14_apply_fit(validation[c("p_home", "p_draw", "p_away")], fit)
    predictions[[outer_index]] <- data.frame(
      fixture_id = validation$fixture_id, p_home_calibrated = probability[, 1L],
      p_draw_calibrated = probability[, 2L], p_away_calibrated = probability[, 3L],
      selected_family = candidate$family, selected_candidate_id = candidate$candidate_id,
      outer_training_editions = common$outer_training_editions,
      inner_validation_editions = common$inner_validation_editions,
      inner_training_map = common$inner_training_map, stringsAsFactors = FALSE
    )
  }
  list(selections = do.call(rbind, selections), fits = do.call(rbind, fits),
       predictions = do.call(rbind, predictions), cache = cache)
}

reference_phase14_compare_outer <- function(expected, selection, fits, calibrated) {
  lineage_columns <- c("outer_edition_id", "outer_index", "outer_training_editions",
    "inner_validation_editions", "inner_training_map", "outer_training_row_count",
    "outer_training_class_count_home", "outer_training_class_count_draw",
    "outer_training_class_count_away", "selected_candidate_id", "selected_family", "warmup_rows",
    "scalar_shrinkage", "vector_penalty", "fit_status", "fallback_reason", "optimizer_method",
    "optimizer_convergence_code", "optimizer_convergence_message",
    "valid_inner_validation_count", "valid_inner_validation_editions", "eligibility_reason")
  for (column in lineage_columns) {
    reference_phase14_character_equal(selection[[column]], expected$selections[[column]], paste("Selection", column))
  }
  expected_seeds <- vapply(seq_len(nrow(expected$selections)), reference_phase14_outer_seed_schedule,
                           integer(1))
  reference_phase14_numeric_equal(selection$optimizer_seed, expected_seeds, 0,
                                  "Selection optimizer seed")
  reference_phase14_numeric_equal(fits$optimizer_seed, expected_seeds, 0, "Fit optimizer seed")
  numeric_selection <- c("ranking_rps", "ranking_calibration_error", "ranking_log_loss",
                         "ranking_brier", "fold_stability_max_regression", "optimizer_objective_value")
  for (column in numeric_selection) {
    reference_phase14_numeric_equal(selection[[column]], expected$selections[[column]], 1e-12,
                                    paste("Selection", column))
  }
  reference_phase14_require(all(as.Date(selection$outer_open_date) == as.Date(expected$selections$outer_open_date)),
                            "Outer open dates differ from reconstructed chronology")
  expected_max <- as.character(expected$selections$outer_training_max_completion_date)
  actual_max <- as.character(selection$outer_training_max_completion_date)
  actual_max[is.na(actual_max)] <- ""; expected_max[is.na(expected_max)] <- ""
  reference_phase14_require(identical(actual_max, expected_max), "Outer training completion cutoffs differ")
  fit_lineage <- intersect(c(lineage_columns, numeric_selection), names(fits))
  for (column in fit_lineage) {
    if (column %in% numeric_selection) {
      reference_phase14_numeric_equal(fits[[column]], expected$fits[[column]], 1e-12, paste("Fit", column))
    } else {
      reference_phase14_character_equal(fits[[column]], expected$fits[[column]], paste("Fit", column))
    }
  }
  parameter_columns <- c("temperature", "slope_home", "slope_draw", "slope_away",
                         "offset_home", "offset_draw", "offset_away")
  for (column in parameter_columns) {
    reference_phase14_numeric_equal(fits[[column]], expected$fits[[column]], 1e-10, paste("Fit", column))
  }
  actual_predictions <- calibrated[match(expected$predictions$fixture_id, calibrated$fixture_id), ]
  reference_phase14_require(!anyNA(actual_predictions$fixture_id), "Calibrated predictions omit reconstructed fixtures")
  for (column in c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated")) {
    reference_phase14_numeric_equal(actual_predictions[[column]], expected$predictions[[column]], 1e-12,
                                    paste("Calibrated", column))
  }
  for (column in c("selected_family", "selected_candidate_id", "outer_training_editions",
                   "inner_validation_editions", "inner_training_map")) {
    reference_phase14_character_equal(actual_predictions[[column]], expected$predictions[[column]],
                                      paste("Calibrated lineage", column))
  }
  invisible(TRUE)
}

reference_phase14_score_decision <- function(panel, expected_predictions, project_root, protocol) {
  calibrated <- panel
  index <- match(calibrated$fixture_id, expected_predictions$fixture_id)
  calibrated$p_home <- expected_predictions$p_home_calibrated[index]
  calibrated$p_draw <- expected_predictions$p_draw_calibrated[index]
  calibrated$p_away <- expected_predictions$p_away_calibrated[index]
  raw_probabilities <- as.matrix(panel[c("p_home", "p_draw", "p_away")])
  calibrated_probabilities <- as.matrix(calibrated[c("p_home", "p_draw", "p_away")])
  raw_metrics <- reference_phase14_metric_values(panel, raw_probabilities)
  calibrated_metrics <- reference_phase14_metric_values(panel, calibrated_probabilities)
  editions <- unique(panel$edition_id[order(panel$edition_sequence)])
  headline <- function(metrics, column) mean(vapply(editions, function(edition) {
    mean(metrics[[column]][metrics$edition_id == edition])
  }, numeric(1)))
  raw_headline <- vapply(c("rps", "brier", "log_loss"), function(metric) headline(raw_metrics, metric), numeric(1))
  calibrated_headline <- vapply(c("rps", "brier", "log_loss"), function(metric) headline(calibrated_metrics, metric), numeric(1))
  raw_calibration <- fixed_benchmark_calibration(panel, panel, panel$fixture_id)$summary
  calibrated_calibration <- fixed_benchmark_calibration(calibrated, panel, panel$fixture_id)$summary
  fold_deltas <- vapply(editions, function(edition) {
    mean(calibrated_metrics$rps[calibrated_metrics$edition_id == edition]) -
      mean(raw_metrics$rps[raw_metrics$edition_id == edition])
  }, numeric(1))
  comparison <- list(
    candidate_id = "open_nb_incumbent", track_id = "updating",
    raw_headline = raw_headline, calibrated_headline = calibrated_headline,
    raw_calibration_values = as.list(raw_calibration[1L, ]),
    calibrated_calibration_values = as.list(calibrated_calibration[1L, ]),
    paired_rps = list(breadth = data.frame(maximum_fold_regression = max(fold_deltas))),
    calibration_support_valid = TRUE, coverage_valid = TRUE, coverage_numerator = 630L,
    coverage_denominator = 630L, distribution_unchanged = TRUE,
    identity = list(score_distribution_identity_match = TRUE)
  )
  decision <- phase12_selection_decision(comparison, protocol = protocol, calibration_support_valid = TRUE)
  decision$raw_calibration_values <- comparison$raw_calibration_values
  decision$calibrated_calibration_values <- comparison$calibrated_calibration_values
  decision
}

reference_phase14_compare_gate <- function(gate, decision) {
  expected_reason <- paste(decision$reason_codes, collapse = "|")
  reference_phase14_character_equal(gate$disposition,
    if (!length(decision$reason_codes)) "CALIBRATION_RELEASE_APPROVED" else "CALIBRATION_RELEASE_BLOCKED",
    "Gate disposition")
  reference_phase14_character_equal(gate$reason_codes, expected_reason, "Gate ordered reasons")
  reference_phase14_numeric_equal(gate$reason_count, length(decision$reason_codes), 0, "Gate reason count")
  mapping <- list(
    raw_headline_rps = decision$raw_headline[["rps"]],
    calibrated_headline_rps = decision$calibrated_headline[["rps"]], rps_delta = decision$rps_delta,
    raw_headline_brier = decision$raw_headline[["brier"]],
    calibrated_headline_brier = decision$calibrated_headline[["brier"]],
    brier_relative_change = decision$brier_relative_change,
    raw_headline_log_loss = decision$raw_headline[["log_loss"]],
    calibrated_headline_log_loss = decision$calibrated_headline[["log_loss"]],
    log_loss_relative_change = decision$log_loss_relative_change,
    fold_stability_max_regression = decision$max_fold_regression,
    raw_calibration_error = as.numeric(decision$raw_calibration_values$calibration_error),
    calibrated_calibration_error = as.numeric(decision$calibrated_calibration_values$calibration_error),
    calibration_error_delta = decision$calibration_delta
  )
  for (column in names(mapping)) {
    reference_phase14_numeric_equal(gate[[column]], mapping[[column]], 1e-12, paste("Gate", column))
  }
  boolean_mapping <- list(
    calibration_support_valid = decision$calibration_support_valid,
    coverage_valid = decision$coverage_valid,
    score_identity_valid = decision$distribution_unchanged,
    rps_valid = !"rps_veto" %in% decision$reason_codes,
    brier_valid = !"brier_veto" %in% decision$reason_codes,
    log_loss_valid = !"log_loss_veto" %in% decision$reason_codes,
    fold_stability_valid = !"fold_stability_veto" %in% decision$reason_codes,
    calibration_improvement_valid = !"calibration_not_improved" %in% decision$reason_codes,
    calibration_promoted = decision$calibration_promoted
  )
  for (column in names(boolean_mapping)) {
    reference_phase14_require(identical(reference_phase14_bool(gate[[column]]), boolean_mapping[[column]]),
                              paste0("Gate ", column, " differs from Phase 12 decision"))
  }
  reference_phase14_character_equal(gate$primary_probability_view, decision$primary_probability_view,
                                    "Gate primary probability view")
  invisible(TRUE)
}

reference_phase14_manifest_paths <- function(project_root, root) {
  c(
    source_predictions_file_sha256 = file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv"),
    fixtures_file_sha256 = file.path(project_root, "data/benchmark/phase09/fixtures.csv"),
    freeze_manifest_sha256 = file.path(project_root, "data/benchmark/phase12/freeze_manifest.csv"),
    calibration_recipe_sha256 = file.path(project_root, "data/benchmark/phase12/calibration_recipe.json"),
    protocol_sha256 = file.path(project_root, "data/benchmark/phase09/promotion_protocol.json"),
    model_registry_sha256 = file.path(project_root, "data/benchmark/phase09/model_registry.csv"),
    seed_registry_sha256 = file.path(project_root, "data/benchmark/phase09/seed_registry.csv"),
    phase12_selector_sha256 = file.path(project_root, "R/calibration/calibration_selection.R"),
    original_revision_code_sha256 = file.path(project_root, "R/release/calibration_revision.R"),
    original_gate_sha256 = file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_gate.csv"),
    original_manifest_sha256 = file.path(project_root, "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision/calibration_revision_manifest.csv"),
    remediation_code_sha256 = file.path(project_root, "R/release/calibration_remediation.R"),
    remediation_contract_sha256 = file.path(root, "remediation_contract.csv"),
    outer_fold_selection_sha256 = file.path(root, "outer_fold_selection.csv"),
    outer_fold_fits_sha256 = file.path(root, "outer_fold_fits.csv"),
    calibrator_sha256 = file.path(root, "calibrator.rds"),
    calibrated_predictions_sha256 = file.path(root, "calibrated_predictions.csv"),
    calibration_gate_sha256 = file.path(root, "calibration_gate.csv")
  )
}

reference_phase14_frozen_authority_pins <- function() {
  c(
    source_predictions_file_sha256 = "a9a6d04f8357478109ff4852ec5ce650cf1c55dc3fcfa4d3ce10b802191ece3f",
    source_predictions_slice_sha256 = "269a46a70fc6326c1bcf336eddc113237a63d004362e89ff6b56674e084088c8",
    fixtures_file_sha256 = "69dac1891ffa948d3b6ecd29949063c9dffb47bb50ced5dbf6c87bc80286c8dc",
    freeze_manifest_sha256 = "71b6f74a7a32199b41505de5955818475ae3e9138269f0a01b71d9371a4a2caa",
    calibration_recipe_sha256 = "7b9cecc347e49965a317af22b6febcf31feb9becbfebe65582d51a36b1e8ff21",
    protocol_sha256 = "984b73132baa78b064ea11d20ee108f672bfbc5bffb0ed93ecc226e81d950efd",
    model_registry_sha256 = "7c3aeac0f319892849169ce37c4d24777a05fc37699ddd520beac7c588bd4ada",
    seed_registry_sha256 = "b1c74b16dabd2707dc32390c42ccbe2a42a29818c4ebe6733699ac94aa64bd99",
    phase12_selector_sha256 = "81932c8decf9a2b4f6a8684ae24c089cd5637bedd7def4c3ed4781b76b05a00c",
    original_revision_code_sha256 = "76424aeab02aac1a6fad464a4f57fa12e72972b61aabf9180ec251d86d50cb65",
    original_gate_sha256 = "7d5de6a007f1ce0bbf242eb9c5f63abc8252d734364bc758e0d3840f850b9d84",
    original_manifest_sha256 = "a1cb95545607f4630a5a9f48f9efd0a38385050c376c940664933b4fd9e4bec0",
    remediation_code_sha256 = "08f9d3a547923b24f9d2a28eda036239735e78ced0c012fdd185f23c455aa30b"
  )
}

reference_phase14_validate_hash_graph <- function(root, project_root, manifest, contract, selection, fits, gate) {
  paths <- reference_phase14_manifest_paths(project_root, root)
  for (field in names(paths)) {
    reference_phase14_character_equal(manifest[[field]], reference_phase14_file_sha256(paths[[field]]),
                                      paste("Manifest", field))
  }
  pins <- reference_phase14_frozen_authority_pins()
  for (field in names(pins)) {
    reference_phase14_character_equal(manifest[[field]], pins[[field]],
                                      paste("Frozen authority pin", field))
  }
  reference_phase14_character_equal(manifest$code_commit,
                                    "5f55988dd30f9cf37948017c61dfd78c4ccd4295",
                                    "Producer code commit pin")
  reference_phase14_character_equal(contract$contract_row_sha256,
                                    reference_phase14_row_sha256(contract, "contract_row_sha256"),
                                    "Contract hashes")
  reference_phase14_character_equal(selection$selection_row_sha256,
                                    reference_phase14_row_sha256(selection, "selection_row_sha256"),
                                    "Selection hashes")
  reference_phase14_character_equal(fits$fit_record_sha256,
                                    reference_phase14_row_sha256(fits, "fit_record_sha256"), "Fit hashes")
  reference_phase14_character_equal(selection$fit_record_sha256, fits$fit_record_sha256,
                                    "Selection-to-fit hash graph")
  manifest_character <- reference_phase14_read_csv(file.path(root, "calibration_revision_manifest.csv"),
                                                   "Manifest", character = TRUE)
  expected_self <- reference_phase14_table_sha256(
    manifest_character[, setdiff(names(manifest_character), "manifest_self_sha256"), drop = FALSE]
  )
  reference_phase14_character_equal(manifest_character$manifest_self_sha256, expected_self,
                                    "Manifest self hash")
  gate_character <- reference_phase14_read_csv(file.path(root, "calibration_gate.csv"), "Gate", character = TRUE)
  expected_gate_hash <- reference_phase14_table_sha256(
    gate_character[, setdiff(names(gate_character), "row_sha256"), drop = FALSE]
  )
  reference_phase14_character_equal(gate_character$row_sha256, expected_gate_hash, "Gate row hash")
  invisible(TRUE)
}

#' Independently validate a Phase 14 remediation candidate graph.
#'
#' @param root Candidate artifact root. May be an isolated adversarial copy.
#' @param require_promoted Require the independently reconstructed gate to pass.
#' @return TRUE invisibly on acceptance; otherwise raises a fail-closed error.
reference_validate_phase14_calibration_candidate <- function(root, require_promoted = TRUE) {
  project_root <- reference_phase14_repo_root()
  reference_phase14_source_phase12(project_root)
  root <- normalizePath(root, mustWork = FALSE)
  files <- c("remediation_contract.csv", "outer_fold_selection.csv", "outer_fold_fits.csv",
             "calibrator.rds", "calibrated_predictions.csv", "calibration_gate.csv",
             "calibration_revision_manifest.csv")
  reference_phase14_require(all(file.exists(file.path(root, files))), "Candidate graph is incomplete")
  contract <- reference_phase14_read_csv(file.path(root, files[[1L]]), "Remediation contract")
  selection <- reference_phase14_read_csv(file.path(root, files[[2L]]), "Outer selection")
  fits <- reference_phase14_read_csv(file.path(root, files[[3L]]), "Outer fits")
  calibrated <- reference_phase14_read_csv(file.path(root, files[[5L]]), "Calibrated predictions")
  gate <- reference_phase14_read_csv(file.path(root, files[[6L]]), "Calibration gate")
  manifest <- reference_phase14_read_csv(file.path(root, files[[7L]]), "Calibration manifest")
  calibrator <- readRDS(file.path(root, files[[4L]]))
  expected_contract <- reference_phase14_contract()
  reference_phase14_compare_contract(contract, expected_contract$persisted)
  if (is.null(.reference_phase14_acceptance_cache$base)) {
    source <- reference_phase14_panel(project_root)
    protocol <- jsonlite::fromJSON(file.path(project_root, "data/benchmark/phase09/promotion_protocol.json"),
                                   simplifyVector = FALSE)
    expected <- reference_phase14_outer_graph(source$panel, expected_contract, protocol)
    .reference_phase14_acceptance_cache$base <- list(
      source = source, protocol = protocol, expected = expected
    )
  }
  base <- .reference_phase14_acceptance_cache$base
  source <- base$source
  panel <- source$panel
  reference_phase14_require(nrow(calibrated) == 630L && !anyDuplicated(calibrated$fixture_id),
                            "Candidate predictions do not contain exactly 630 unique fixtures")
  reference_phase14_require(setequal(calibrated$fixture_id, panel$fixture_id), "Candidate fixture identities differ")
  reference_phase14_require(!any(grepl("wc2026", tolower(paste(calibrated$edition_id, calibrated$fixture_id)))),
                            "Candidate graph contains WC2026 holdout identity")
  raw_columns <- names(panel)
  persisted_raw <- calibrated[match(panel$fixture_id, calibrated$fixture_id), raw_columns, drop = FALSE]
  for (column in raw_columns) {
    if (column %in% c("p_home", "p_draw", "p_away", "expected_home_goals", "expected_away_goals",
                      "p_over_2_5", "p_under_2_5", "p_btts", "modal_score_probability")) {
      reference_phase14_numeric_equal(persisted_raw[[column]], panel[[column]], 1e-15,
                                      paste("Frozen raw panel", column))
    } else {
      reference_phase14_character_equal(persisted_raw[[column]], panel[[column]],
                                        paste("Frozen raw panel", column))
    }
  }
  protocol <- base$protocol
  expected <- base$expected
  reference_phase14_compare_outer(expected, selection, fits, calibrated)
  source_panel_hashes <- c(
    as.character(selection$selection_source_panel_sha256),
    as.character(fits$source_panel_sha256),
    as.character(calibrator$source_panel_sha256),
    as.character(manifest$source_predictions_slice_sha256)
  )
  reference_phase14_require(length(unique(source_panel_hashes)) == 1L &&
                              grepl("^[0-9a-f]{64}$", source_panel_hashes[[1L]]),
                            "Source-panel hash graph is inconsistent")
  final_selection <- reference_phase14_select(panel, 13L, expected_contract, expected$cache, protocol)
  reference_phase14_character_equal(final_selection$candidate$candidate_id, calibrator$selected_candidate_id,
                                    "Final selected candidate")
  final_seed <- reference_phase14_outer_seed_schedule(13L)
  final_fit <- reference_phase14_fit(panel, final_selection$candidate, final_seed)
  reference_phase14_numeric_equal(calibrator$optimizer_seed, final_seed, 0, "Final optimizer seed")
  reference_phase14_numeric_equal(calibrator$optimizer_convergence_code, final_fit$convergence, 0,
                                  "Final optimizer convergence")
  reference_phase14_character_equal(calibrator$optimizer_convergence_message, final_fit$message,
                                    "Final optimizer message")
  reference_phase14_numeric_equal(calibrator$optimizer_objective_value, final_fit$objective, 1e-10,
                                  "Final optimizer objective")
  reference_phase14_numeric_equal(
    unlist(calibrator[c("temperature", "slope_home", "slope_draw", "slope_away",
                        "offset_home", "offset_draw", "offset_away")]),
    c(final_fit$temperature, final_fit$slopes, final_fit$offsets), 1e-10, "Final fitted parameters"
  )
  decision <- reference_phase14_score_decision(panel, expected$predictions, project_root, protocol)
  reference_phase14_compare_gate(gate, decision)
  reference_phase14_require(identical(as.integer(gate$expected_row_count), 630L) &&
                              identical(as.integer(gate$observed_row_count), 630L) &&
                              identical(as.integer(gate$unique_fixture_count), 630L) &&
                              reference_phase14_bool(gate$chronology_valid) &&
                              reference_phase14_bool(gate$outer_gate_passed) &&
                              reference_phase14_bool(gate$final_fit_performed),
                            "Gate counts, chronology, or final-fit status are invalid")
  reference_phase14_validate_hash_graph(root, project_root, manifest, contract, selection, fits, gate)
  immutable <- c("holdout_labels_used", "authority_mutated", "candidate_authority")
  for (column in immutable) {
    reference_phase14_require(!reference_phase14_bool(gate[[column]]) &&
                              !reference_phase14_bool(manifest[[column]]) &&
                              !isTRUE(calibrator[[column]]), paste0(column, " must remain false"))
  }
  reference_phase14_require(identical(as.integer(manifest$development_row_count), 630L) &&
                              identical(as.integer(manifest$unique_fixture_count), 630L) &&
                              identical(as.integer(manifest$outer_fold_count), 12L) &&
                              identical(as.integer(manifest$fit_record_count), 12L),
                            "Manifest counts differ from reconstructed graph")
  if (isTRUE(require_promoted)) {
    reference_phase14_require(!length(decision$reason_codes),
                              paste0("Independent gate is blocked: ", paste(decision$reason_codes, collapse = "|")))
    reference_phase14_require(identical(as.character(gate$fit_status), "fitted") &&
                              identical(as.character(gate$primary_probability_view), "calibrated_1x2") &&
                              reference_phase14_bool(gate$calibration_promoted) &&
                              identical(as.character(manifest$fit_status), "fitted") &&
                              reference_phase14_bool(manifest$calibration_promoted) &&
                              isTRUE(calibrator$final_fit_performed) && isTRUE(calibrator$calibration_promoted),
                            "Candidate did not earn fitted calibrated promotion")
  }
  invisible(TRUE)
}
