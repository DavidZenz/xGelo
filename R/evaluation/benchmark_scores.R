#' Shared scoring and paired diagnostics for rolling tournament benchmarks

benchmark_score_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

benchmark_score_binary_log <- function(probability, observed, epsilon = 1e-15) {
  binary_brier(probability, observed)
  -log(max(if (as.logical(observed)) probability else 1 - probability, epsilon))
}

#' Create one long benchmark metric row
#' @export
benchmark_metric_row <- function(prediction, fixture, metric, value, target = "regulation_1x2") {
  keys <- c("run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id")
  data.frame(
    as.list(prediction[1, keys, drop = FALSE]),
    target = target,
    metric = metric,
    value = as.numeric(value),
    covered = isTRUE(fixture$score_eligible[1]) && is.finite(value),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

benchmark_score_observed_class <- function(home_goals, away_goals) {
  if (home_goals > away_goals) "home" else if (home_goals < away_goals) "away" else "draw"
}

#' Score every registered fixture once through the shared proper-score formulas
#' @export
score_benchmark_fixtures <- function(predictions, fixtures, distributions) {
  prediction_columns <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_home", "p_draw", "p_away", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status"
  )
  fixture_columns <- c(
    "edition_id", "fixture_id", "regulation_home_goals", "regulation_away_goals", "score_eligible"
  )
  distribution_columns <- c("score_distribution_id", "home_goals", "away_goals", "probability")
  benchmark_score_require_columns(predictions, prediction_columns, "Benchmark predictions")
  benchmark_score_require_columns(fixtures, fixture_columns, "Benchmark fixtures")
  benchmark_score_require_columns(distributions, distribution_columns, "Benchmark score distributions")

  fixtures <- fixtures[fixtures$score_eligible, , drop = FALSE]
  if (!nrow(fixtures) || anyDuplicated(fixtures$fixture_id)) {
    stop("Benchmark fixtures require unique score-eligible fixture IDs", call. = FALSE)
  }
  model_groups <- split(predictions, predictions$model_id)
  expected_ids <- as.character(fixtures$fixture_id)
  for (model_id in names(model_groups)) {
    rows <- model_groups[[model_id]]
    if (anyDuplicated(rows$fixture_id) || !setequal(as.character(rows$fixture_id), expected_ids)) {
      stop("Benchmark predictions must contain exactly the registered fixture IDs for every model", call. = FALSE)
    }
    if (any(is.na(rows$prediction_status) | rows$prediction_status != "ok")) {
      stop("Benchmark predictions contain incomplete required outputs", call. = FALSE)
    }
  }
  if (any(!predictions$fixture_id %in% expected_ids)) {
    stop("Benchmark predictions must contain exactly the registered fixture IDs for every model", call. = FALSE)
  }

  output <- vector("list", nrow(predictions))
  for (i in seq_len(nrow(predictions))) {
    prediction <- predictions[i, , drop = FALSE]
    fixture <- fixtures[match(prediction$fixture_id, fixtures$fixture_id), , drop = FALSE]
    if (as.character(prediction$edition_id) != as.character(fixture$edition_id)) {
      stop("Prediction edition identity does not match the fixture registry", call. = FALSE)
    }
    distribution <- distributions[
      distributions$score_distribution_id == prediction$score_distribution_id,
      c("home_goals", "away_goals", "probability"), drop = FALSE
    ]
    distribution <- validate_scoreline_distribution(distribution)
    probabilities <- c(
      home = prediction$p_home, draw = prediction$p_draw, away = prediction$p_away
    )
    actual_home <- as.integer(fixture$regulation_home_goals)
    actual_away <- as.integer(fixture$regulation_away_goals)
    observed <- benchmark_score_observed_class(actual_home, actual_away)
    scoreline <- score_scoreline_distribution(distribution, actual_home, actual_away)
    actual_over <- as.integer(actual_home + actual_away > 2L)
    actual_btts <- as.integer(actual_home > 0L && actual_away > 0L)
    predicted_class <- names(probabilities)[which.max(probabilities)]

    values <- list(
      rps = c(ranked_probability_score(probabilities, observed), "regulation_1x2"),
      brier = c(multiclass_brier(probabilities, observed), "regulation_1x2"),
      log_loss = c(log_score(probabilities, observed), "regulation_1x2"),
      winner_pick_accuracy = c(as.numeric(predicted_class == observed), "regulation_1x2"),
      joint_scoreline_log_loss = c(scoreline$joint_log_score, "regulation_scoreline"),
      home_goal_rps = c(scoreline$home_goal_rps, "home_goals"),
      away_goal_rps = c(scoreline$away_goal_rps, "away_goals"),
      over_2_5_brier = c(binary_brier(prediction$p_over_2_5, actual_over), "over_2_5"),
      over_2_5_log_loss = c(benchmark_score_binary_log(prediction$p_over_2_5, actual_over), "over_2_5"),
      under_2_5_brier = c(binary_brier(prediction$p_under_2_5, 1L - actual_over), "under_2_5"),
      under_2_5_log_loss = c(benchmark_score_binary_log(prediction$p_under_2_5, 1L - actual_over), "under_2_5"),
      btts_brier = c(binary_brier(prediction$p_btts, actual_btts), "btts"),
      btts_log_loss = c(benchmark_score_binary_log(prediction$p_btts, actual_btts), "btts"),
      exact_score_hit = c(scoreline$exact_score_hit, "regulation_scoreline")
    )
    output[[i]] <- do.call(rbind, lapply(names(values), function(metric) {
      benchmark_metric_row(prediction, fixture, metric, as.numeric(values[[metric]][1]), values[[metric]][2])
    }))
  }
  result <- do.call(rbind, output)
  rownames(result) <- NULL
  result
}

benchmark_score_group_key <- function(data, columns) {
  do.call(paste, c(lapply(data[columns], as.character), sep = "\r"))
}

#' Aggregate fixture scores within tournaments before the equal-tournament headline
#' @export
aggregate_benchmark_scores <- function(scores, expected_editions) {
  required <- c(
    "run_id", "model_id", "panel_id", "track_id", "edition_id", "fixture_id",
    "target", "metric", "value", "covered"
  )
  benchmark_score_require_columns(scores, required, "Benchmark fixture scores")
  expected_editions <- as.character(expected_editions)
  if (anyDuplicated(expected_editions) || !length(expected_editions)) {
    stop("expected_editions must contain unique registered edition IDs", call. = FALSE)
  }
  group_columns <- c("run_id", "model_id", "panel_id", "track_id", "target", "metric")
  groups <- split(scores, benchmark_score_group_key(scores, group_columns))
  result <- lapply(groups, function(rows) {
    rows <- rows[rows$covered & is.finite(rows$value), , drop = FALSE]
    if (!setequal(unique(as.character(rows$edition_id)), expected_editions)) {
      stop("Headline aggregation requires every registered tournament", call. = FALSE)
    }
    tournaments <- do.call(rbind, lapply(expected_editions, function(edition) {
      edition_rows <- rows[rows$edition_id == edition, , drop = FALSE]
      data.frame(
        as.list(edition_rows[1, group_columns, drop = FALSE]),
        grain = "tournament", aggregation = "within_tournament", edition_id = edition,
        estimate = mean(edition_rows$value), n_tournaments = 1L,
        n_fixtures = length(unique(edition_rows$fixture_id)),
        coverage_numerator = nrow(edition_rows), coverage_denominator = nrow(edition_rows),
        coverage = 1, stringsAsFactors = FALSE, check.names = FALSE
      )
    }))
    headline_base <- as.list(rows[1, group_columns, drop = FALSE])
    headlines <- rbind(
      data.frame(
        headline_base, grain = "headline", aggregation = "equal_tournament", edition_id = "headline",
        estimate = mean(tournaments$estimate), n_tournaments = nrow(tournaments),
        n_fixtures = length(unique(rows$fixture_id)), coverage_numerator = nrow(rows),
        coverage_denominator = nrow(rows), coverage = 1, stringsAsFactors = FALSE, check.names = FALSE
      ),
      data.frame(
        headline_base, grain = "headline", aggregation = "fixture_weighted", edition_id = "headline",
        estimate = mean(rows$value), n_tournaments = nrow(tournaments),
        n_fixtures = length(unique(rows$fixture_id)), coverage_numerator = nrow(rows),
        coverage_denominator = nrow(rows), coverage = 1, stringsAsFactors = FALSE, check.names = FALSE
      )
    )
    rbind(tournaments, headlines)
  })
  result <- do.call(rbind, result)
  rownames(result) <- NULL
  result
}

#' Fixed one-vs-rest calibration bins shared across benchmark models
#' @export
fixed_benchmark_calibration <- function(predictions, fixtures, min_bin_count = 10L) {
  prediction_columns <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "p_home", "p_draw", "p_away"
  )
  fixture_columns <- c("edition_id", "fixture_id", "regulation_home_goals", "regulation_away_goals")
  benchmark_score_require_columns(predictions, prediction_columns, "Benchmark predictions")
  benchmark_score_require_columns(fixtures, fixture_columns, "Benchmark fixtures")
  if (anyDuplicated(fixtures$fixture_id)) stop("Benchmark fixtures contain duplicate IDs", call. = FALSE)
  group_columns <- c("run_id", "model_id", "panel_id", "track_id")
  groups <- split(predictions, benchmark_score_group_key(predictions, group_columns))
  all_bins <- list()
  all_summaries <- list()
  cursor <- 0L
  for (rows in groups) {
    if (anyDuplicated(rows$fixture_id) || !setequal(rows$fixture_id, fixtures$fixture_id)) {
      stop("Calibration requires exactly the registered fixture IDs", call. = FALSE)
    }
    fixture_rows <- fixtures[match(rows$fixture_id, fixtures$fixture_id), , drop = FALSE]
    if (any(as.character(rows$edition_id) != as.character(fixture_rows$edition_id))) {
      stop("Calibration edition identity does not match fixtures", call. = FALSE)
    }
    edition_sizes <- table(rows$edition_id)
    observations <- do.call(rbind, lapply(seq_len(nrow(rows)), function(i) {
      observed <- benchmark_score_observed_class(
        fixture_rows$regulation_home_goals[i], fixture_rows$regulation_away_goals[i]
      )
      probabilities <- c(home = rows$p_home[i], draw = rows$p_draw[i], away = rows$p_away[i])
      data.frame(
        class = names(probabilities), probability = as.numeric(probabilities),
        observed = as.numeric(names(probabilities) == observed),
        weight = 1 / (3 * as.numeric(edition_sizes[as.character(rows$edition_id[i])])),
        stringsAsFactors = FALSE
      )
    }))
    observations$bin_id <- pmin(floor(observations$probability * 10), 9L) + 1L
    bin_groups <- split(observations, paste(observations$class, observations$bin_id, sep = "\r"))
    bins <- do.call(rbind, lapply(bin_groups, function(bin) {
      total_weight <- sum(bin$weight)
      data.frame(
        as.list(rows[1, group_columns, drop = FALSE]), class = bin$class[1], bin_id = bin$bin_id[1],
        bin_lower = (bin$bin_id[1] - 1) / 10, bin_upper = bin$bin_id[1] / 10,
        n = nrow(bin), weight = total_weight,
        mean_probability = stats::weighted.mean(bin$probability, bin$weight),
        observed_frequency = stats::weighted.mean(bin$observed, bin$weight),
        sparse = nrow(bin) < as.integer(min_bin_count),
        stringsAsFactors = FALSE, check.names = FALSE
      )
    }))
    bins$absolute_gap <- abs(bins$mean_probability - bins$observed_frequency)
    class_errors <- vapply(c("home", "draw", "away"), function(class) {
      class_bins <- bins[bins$class == class, , drop = FALSE]
      sum(class_bins$weight * class_bins$absolute_gap) / sum(class_bins$weight)
    }, numeric(1))
    cursor <- cursor + 1L
    all_bins[[cursor]] <- bins
    all_summaries[[cursor]] <- data.frame(
      as.list(rows[1, group_columns, drop = FALSE]), calibration_error = mean(class_errors),
      home_calibration_error = class_errors["home"], draw_calibration_error = class_errors["draw"],
      away_calibration_error = class_errors["away"], n_fixtures = nrow(rows),
      n_tournaments = length(unique(rows$edition_id)), stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  bins <- do.call(rbind, all_bins)
  summary <- do.call(rbind, all_summaries)
  rownames(bins) <- NULL
  rownames(summary) <- NULL
  list(bins = bins, summary = summary)
}

#' Leave-one-tournament-out diagnostics for fold deltas
#' @export
leave_one_tournament_out_deltas <- function(fold_deltas) {
  benchmark_score_require_columns(fold_deltas, c("edition_id", "delta"), "Fold deltas")
  if (anyDuplicated(fold_deltas$edition_id) || nrow(fold_deltas) < 2L || any(!is.finite(fold_deltas$delta))) {
    stop("Fold deltas require unique editions and finite values", call. = FALSE)
  }
  data.frame(
    omitted_edition_id = fold_deltas$edition_id,
    estimate = vapply(seq_len(nrow(fold_deltas)), function(i) mean(fold_deltas$delta[-i]), numeric(1)),
    stringsAsFactors = FALSE
  )
}

#' Deterministic paired bootstrap over exactly 12 tournament deltas
#' @export
paired_tournament_bootstrap <- function(fold_deltas, reps = 10000L, seed) {
  benchmark_score_require_columns(fold_deltas, c("edition_id", "delta"), "Fold deltas")
  if (nrow(fold_deltas) != 12L || anyDuplicated(fold_deltas$edition_id) || any(!is.finite(fold_deltas$delta))) {
    stop("Paired bootstrap requires exactly 12 tournament deltas", call. = FALSE)
  }
  reps <- as.integer(reps)
  seed <- as.integer(seed)
  if (reps != 10000L || is.na(seed)) {
    stop("Paired bootstrap requires 10,000 replicates and one registered integer seed", call. = FALSE)
  }
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(seed, kind = "L'Ecuyer-CMRG")
  values <- fold_deltas$delta
  draws <- replicate(reps, mean(sample(values, length(values), replace = TRUE)))
  interval <- stats::quantile(draws, c(0.025, 0.975), names = FALSE, type = 8)
  data.frame(
    estimate = mean(values), lower = interval[1], upper = interval[2],
    replicates = reps, seed = seed, resampling_unit = "tournament", quantile_type = 8L,
    stringsAsFactors = FALSE
  )
}

#' Pair exact candidate/incumbent fixtures and retain fold-level diagnostics
#' @export
make_paired_fold_comparisons <- function(
    scores, challenger_id, incumbent_id, tournaments, expected_fixture_ids,
    metric = "rps", target = "regulation_1x2", reps = 10000L, seed = 920001L
) {
  required <- c("model_id", "edition_id", "fixture_id", "target", "metric", "value", "covered")
  benchmark_score_require_columns(scores, required, "Benchmark fixture scores")
  benchmark_score_require_columns(tournaments, c("edition_id", "competition_id"), "Tournament registry")
  expected_fixture_ids <- as.character(expected_fixture_ids)
  selected <- scores[scores$metric == metric & scores$target == target & scores$covered, , drop = FALSE]
  challenger <- selected[selected$model_id == challenger_id, c("edition_id", "fixture_id", "value"), drop = FALSE]
  incumbent <- selected[selected$model_id == incumbent_id, c("edition_id", "fixture_id", "value"), drop = FALSE]
  if (
    anyDuplicated(challenger$fixture_id) || anyDuplicated(incumbent$fixture_id) ||
    !setequal(challenger$fixture_id, expected_fixture_ids) ||
    !setequal(incumbent$fixture_id, expected_fixture_ids)
  ) {
    stop("Candidate and incumbent must contain the exact paired fixture set", call. = FALSE)
  }
  paired <- merge(challenger, incumbent, by = "fixture_id", suffixes = c("_challenger", "_incumbent"), sort = TRUE)
  if (nrow(paired) != length(expected_fixture_ids) || any(paired$edition_id_challenger != paired$edition_id_incumbent)) {
    stop("Candidate and incumbent must contain the exact paired fixture set", call. = FALSE)
  }
  paired$edition_id <- paired$edition_id_challenger
  paired$delta <- paired$value_challenger - paired$value_incumbent
  fold_groups <- split(paired, paired$edition_id)
  folds <- do.call(rbind, lapply(fold_groups, function(rows) {
    data.frame(
      edition_id = rows$edition_id[1], challenger_estimate = mean(rows$value_challenger),
      incumbent_estimate = mean(rows$value_incumbent), delta = mean(rows$delta),
      paired_fixture_count = nrow(rows), stringsAsFactors = FALSE
    )
  }))
  folds$competition_id <- tournaments$competition_id[match(folds$edition_id, tournaments$edition_id)]
  if (any(is.na(folds$competition_id)) || nrow(folds) != 12L) {
    stop("Paired comparison requires all 12 registered tournament folds", call. = FALSE)
  }
  folds$improved <- folds$delta < 0
  folds$regression_limit_pass <- folds$delta <= 0.015
  folds <- folds[match(tournaments$edition_id, folds$edition_id), , drop = FALSE]
  rownames(folds) <- NULL
  breadth <- data.frame(
    fold_wins = sum(folds$delta < 0),
    world_cup_wins = sum(folds$delta < 0 & folds$competition_id == "world_cup"),
    euro_wins = sum(folds$delta < 0 & folds$competition_id == "euro"),
    maximum_fold_regression = max(c(0, folds$delta)), stringsAsFactors = FALSE
  )
  list(
    fixtures = paired[, c("fixture_id", "edition_id", "value_challenger", "value_incumbent", "delta")],
    folds = folds,
    headline = data.frame(
      challenger_id = challenger_id, incumbent_id = incumbent_id, metric = metric,
      delta = mean(folds$delta), stringsAsFactors = FALSE
    ),
    bootstrap = paired_tournament_bootstrap(folds[, c("edition_id", "delta")], reps = reps, seed = seed),
    breadth = breadth,
    leave_one_out = leave_one_tournament_out_deltas(folds[, c("edition_id", "delta")])
  )
}
