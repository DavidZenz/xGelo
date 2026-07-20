#' World Cup retrospective scoring and aggregation

metric_row <- function(forecast, metric, value, target = "regulation_1x2") {
  data.frame(
    match_id = forecast$match_id,
    sample = forecast$sample,
    view = forecast$view,
    stage = forecast$stage,
    round = forecast$round,
    home_team = forecast$canonical_home_team,
    away_team = forecast$canonical_away_team,
    observed_outcome = forecast$observed_outcome,
    predicted_outcome = forecast$predicted_outcome,
    confidence = forecast$confidence,
    target = target,
    metric = metric,
    value = as.numeric(value),
    stringsAsFactors = FALSE
  )
}

binary_log_score <- function(probability, observed, epsilon = 1e-15) {
  if (!is.finite(probability) || probability < 0 || probability > 1) {
    stop("probability must be one finite value in [0, 1]", call. = FALSE)
  }
  -log(max(if (isTRUE(as.logical(observed))) probability else 1 - probability, epsilon))
}

#' Score every selected World Cup match forecast
#'
#' @param selected Selected first/latest forecast views.
#' @param scorelines Archived scoreline rows. Incomplete distributions are not scored.
#' @return Long-form metric table.
#' @export
score_worldcup_matches <- function(selected, scorelines = data.frame(), tolerance = 1e-6) {
  required <- c(
    "match_id", "sample", "view", "stage", "round", "canonical_home_team",
    "canonical_away_team", "actual_home_goals", "actual_away_goals",
    "p_home", "p_draw", "p_away"
  )
  missing <- setdiff(required, names(selected))
  if (length(missing)) stop("selected forecasts missing: ", paste(missing, collapse = ", "))
  rows <- list()
  n <- 0L
  for (i in seq_len(nrow(selected))) {
    forecast <- selected[i, , drop = FALSE]
    observed <- if (forecast$actual_home_goals > forecast$actual_away_goals) {
      "home"
    } else if (forecast$actual_home_goals < forecast$actual_away_goals) {
      "away"
    } else {
      "draw"
    }
    probabilities <- c(home = forecast$p_home, draw = forecast$p_draw, away = forecast$p_away)
    predicted <- names(which.max(probabilities))
    forecast$observed_outcome <- observed
    forecast$predicted_outcome <- predicted
    forecast$confidence <- max(probabilities)
    add <- function(metric, value, target = "regulation_1x2") {
      n <<- n + 1L
      rows[[n]] <<- metric_row(forecast, metric, value, target)
    }
    add("rps", ranked_probability_score(probabilities, observed))
    add("brier", multiclass_brier(probabilities, observed))
    add("log_loss", log_score(probabilities, observed))
    add("accuracy", as.integer(predicted == observed))
    add("home_xg_absolute_error", abs(forecast$expected_home_goals - forecast$actual_home_goals), "goals")
    add("away_xg_absolute_error", abs(forecast$expected_away_goals - forecast$actual_away_goals), "goals")
    add(
      "total_xg_squared_error",
      ((forecast$expected_home_goals + forecast$expected_away_goals) -
         (forecast$actual_home_goals + forecast$actual_away_goals))^2,
      "goals"
    )
    if ("p_over_2_5" %in% names(forecast) && is.finite(forecast$p_over_2_5)) {
      actual_over <- as.integer(forecast$actual_home_goals + forecast$actual_away_goals > 2)
      add("over_2_5_brier", binary_brier(forecast$p_over_2_5, actual_over), "over_2_5")
      add("over_2_5_log_loss", binary_log_score(forecast$p_over_2_5, actual_over), "over_2_5")
    }
    if ("p_btts" %in% names(forecast) && is.finite(forecast$p_btts)) {
      actual_btts <- as.integer(forecast$actual_home_goals > 0 && forecast$actual_away_goals > 0)
      add("btts_brier", binary_brier(forecast$p_btts, actual_btts), "btts")
      add("btts_log_loss", binary_log_score(forecast$p_btts, actual_btts), "btts")
    }

    if (nrow(scorelines) && "commit_sha" %in% names(forecast)) {
      distribution <- scorelines[
        scorelines$commit_sha == forecast$commit_sha & scorelines$match_id == forecast$match_id,
        c("home_goals", "away_goals", "probability"), drop = FALSE
      ]
      complete <- nrow(distribution) > 0 &&
        abs(sum(distribution$probability) - 1) <= tolerance
      distribution_scores <- NULL
      if (complete) {
        distribution_scores <- tryCatch(
          score_scoreline_distribution(
            distribution, forecast$actual_home_goals, forecast$actual_away_goals,
            tolerance = tolerance
          ),
          error = function(e) NULL
        )
      }
      add("joint_scoreline_log_loss", if (is.null(distribution_scores)) NA_real_ else distribution_scores$joint_log_score, "scoreline")
      add("home_goal_rps", if (is.null(distribution_scores)) NA_real_ else distribution_scores$home_goal_rps, "scoreline")
      add("away_goal_rps", if (is.null(distribution_scores)) NA_real_ else distribution_scores$away_goal_rps, "scoreline")
      add("exact_score_hit", if (is.null(distribution_scores)) NA_real_ else distribution_scores$exact_score_hit, "scoreline")
    } else {
      add("joint_scoreline_log_loss", NA_real_, "scoreline")
      add("home_goal_rps", NA_real_, "scoreline")
      add("away_goal_rps", NA_real_, "scoreline")
      add("exact_score_hit", NA_real_, "scoreline")
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

bootstrap_mean <- function(values, reps, conf) {
  values <- values[is.finite(values)]
  if (!length(values)) return(c(lower = NA_real_, upper = NA_real_))
  draws <- replicate(reps, mean(sample(values, length(values), replace = TRUE)))
  alpha <- (1 - conf) / 2
  stats::quantile(draws, c(alpha, 1 - alpha), names = FALSE, type = 8)
}

#' Deterministic bootstrap intervals for metric groups
#' @export
bootstrap_worldcup_scores <- function(match_scores, reps = 2000, conf = 0.95,
                                      seed = 20260720,
                                      group_cols = c("sample", "view", "metric")) {
  missing <- setdiff(c(group_cols, "value"), names(match_scores))
  if (length(missing)) stop("match scores missing: ", paste(missing, collapse = ", "))
  set.seed(seed)
  key <- interaction(match_scores[group_cols], drop = TRUE, lex.order = TRUE)
  groups <- split(match_scores, key)
  rows <- lapply(groups, function(group) {
    interval <- bootstrap_mean(group$value, reps, conf)
    out <- group[1, group_cols, drop = FALSE]
    out$lower <- interval[1]
    out$upper <- interval[2]
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

make_cut_rows <- function(match_scores) {
  overall <- match_scores
  overall$cut_type <- "overall"
  overall$cut_value <- "all"

  stage <- match_scores
  stage$cut_type <- "stage"
  stage$cut_value <- stage$stage

  outcome <- match_scores
  outcome$cut_type <- "outcome_class"
  outcome$cut_value <- outcome$observed_outcome

  confidence <- match_scores
  confidence$cut_type <- "confidence"
  confidence$cut_value <- cut(
    confidence$confidence,
    breaks = c(-Inf, 0.45, 0.60, Inf),
    labels = c("low", "medium", "high")
  )
  rbind(overall, stage, outcome, confidence)
}

#' Aggregate match scores with equal fixture weights
#' @export
aggregate_worldcup_scores <- function(match_scores, n_official = 104L, reps = 2000,
                                      conf = 0.95, seed = 20260720) {
  if (!nrow(match_scores)) return(data.frame())
  cuts <- make_cut_rows(match_scores)
  grouping <- c("sample", "view", "target", "metric", "cut_type", "cut_value")
  key <- interaction(cuts[grouping], drop = TRUE, lex.order = TRUE)
  groups <- split(cuts, key)
  set.seed(seed)
  rows <- lapply(groups, function(group) {
    values <- group$value[is.finite(group$value)]
    interval <- bootstrap_mean(values, reps, conf)
    denominator <- if (identical(group$cut_type[1], "stage")) {
      length(unique(match_scores$match_id[match_scores$stage == group$cut_value[1]]))
    } else {
      n_official
    }
    data.frame(
      sample = group$sample[1], view = group$view[1], target = group$target[1],
      metric = group$metric[1], cut_type = group$cut_type[1], cut_value = as.character(group$cut_value[1]),
      n_scored = length(values), n_official = denominator,
      coverage = if (denominator > 0) length(values) / denominator else NA_real_,
      estimate = if (length(values)) mean(values) else NA_real_,
      lower = interval[1], upper = interval[2],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)

  # The team-balanced diagnostic gives each team equal weight after averaging
  # its fixtures, while the headline rows above keep every fixture equal.
  team_rows <- list()
  n <- 0L
  for (side in c("home_team", "away_team")) {
    temp <- match_scores
    temp$team <- temp[[side]]
    team_rows[[side]] <- temp
  }
  team_data <- do.call(rbind, team_rows)
  team_key <- interaction(team_data[c("sample", "view", "target", "metric", "team")], drop = TRUE)
  team_means <- lapply(split(team_data, team_key), function(group) {
    values <- group$value[is.finite(group$value)]
    data.frame(
      sample = group$sample[1], view = group$view[1], target = group$target[1],
      metric = group$metric[1], team = group$team[1],
      value = if (length(values)) mean(values) else NA_real_
    )
  })
  team_means <- do.call(rbind, team_means)
  aggregate_key <- interaction(team_means[c("sample", "view", "target", "metric")], drop = TRUE)
  for (group in split(team_means, aggregate_key)) {
    n <- n + 1L
    values <- group$value[is.finite(group$value)]
    interval <- bootstrap_mean(values, reps, conf)
    out <- rbind(out, data.frame(
      sample = group$sample[1], view = group$view[1], target = group$target[1],
      metric = group$metric[1], cut_type = "team_balanced", cut_value = "all_teams",
      n_scored = length(values), n_official = length(unique(team_data$team)),
      coverage = length(values) / length(unique(stats::na.omit(team_data$team))),
      estimate = if (length(values)) mean(values) else NA_real_,
      lower = interval[1], upper = interval[2], stringsAsFactors = FALSE
    ))
  }

  paired <- merge(
    match_scores[match_scores$view == "first_valid", c("sample", "target", "metric", "match_id", "value")],
    match_scores[match_scores$view == "latest_valid", c("sample", "target", "metric", "match_id", "value")],
    by = c("sample", "target", "metric", "match_id"), suffixes = c("_first", "_latest")
  )
  if (nrow(paired)) {
    paired$value <- paired$value_latest - paired$value_first
    paired_key <- interaction(paired[c("sample", "target", "metric")], drop = TRUE)
    for (group in split(paired, paired_key)) {
      values <- group$value[is.finite(group$value)]
      interval <- bootstrap_mean(values, reps, conf)
      out <- rbind(out, data.frame(
        sample = group$sample[1], view = "paired_delta_latest_minus_first",
        target = group$target[1], metric = group$metric[1],
        cut_type = "overall", cut_value = "all",
        n_scored = length(values), n_official = n_official,
        coverage = length(values) / n_official,
        estimate = if (length(values)) mean(values) else NA_real_,
        lower = interval[1], upper = interval[2], stringsAsFactors = FALSE
      ))
    }
  }
  rownames(out) <- NULL
  out
}

#' Build quantile calibration bins for 1X2 probabilities
#' @export
make_calibration_bins <- function(selected, min_bin_size = 5L, max_bins = 10L) {
  class_rows <- do.call(rbind, lapply(seq_len(nrow(selected)), function(i) {
    observed <- if (selected$actual_home_goals[i] > selected$actual_away_goals[i]) "home" else
      if (selected$actual_home_goals[i] < selected$actual_away_goals[i]) "away" else "draw"
    data.frame(
      sample = selected$sample[i], view = selected$view[i], match_id = selected$match_id[i],
      class = c("home", "draw", "away"),
      probability = c(selected$p_home[i], selected$p_draw[i], selected$p_away[i]),
      observed = as.integer(c("home", "draw", "away") == observed), stringsAsFactors = FALSE
    )
  }))
  key <- interaction(class_rows[c("sample", "view", "class")], drop = TRUE)
  rows <- list()
  n <- 0L
  for (group in split(class_rows, key)) {
    bin_count <- min(max_bins, max(1L, floor(nrow(group) / min_bin_size)))
    breaks <- unique(stats::quantile(group$probability, seq(0, 1, length.out = bin_count + 1), type = 8))
    if (length(breaks) < 2L) {
      group$bin <- factor("all")
    } else {
      breaks[1] <- -Inf
      breaks[length(breaks)] <- Inf
      group$bin <- cut(group$probability, breaks = breaks, include.lowest = TRUE, ordered_result = TRUE)
    }
    for (bin in split(group, group$bin, drop = TRUE)) {
      n <- n + 1L
      rows[[n]] <- data.frame(
        sample = bin$sample[1], view = bin$view[1], class = bin$class[1],
        bin = as.character(bin$bin[1]), n = nrow(bin),
        mean_probability = mean(bin$probability), observed_frequency = mean(bin$observed),
        sparse = nrow(bin) < min_bin_size, stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

#' Score binary knockout advancement forecasts
#' @export
score_knockout_advancement <- function(selected) {
  eligible <- selected$stage == "knockout" & is.finite(selected$p_home_advance) & is.finite(selected$p_away_advance)
  data <- selected[eligible, , drop = FALSE]
  if (!nrow(data)) return(data.frame())
  rows <- lapply(seq_len(nrow(data)), function(i) {
    actual_home <- normalize_worldcup_team_key(data$actual_winner_team[i]) ==
      normalize_worldcup_team_key(data$canonical_home_team[i])
    data.frame(
      match_id = data$match_id[i], sample = data$sample[i], view = data$view[i],
      round = data$round[i], home_team = data$canonical_home_team[i], away_team = data$canonical_away_team[i],
      actual_advancing_team = data$actual_winner_team[i], p_home_advance = data$p_home_advance[i],
      brier = binary_brier(data$p_home_advance[i], actual_home),
      log_loss = binary_log_score(data$p_home_advance[i], actual_home), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Select one deterministic pre-tournament and one pre-stage snapshot
#' @export
select_stage_reach_anchors <- function(selected, stage_probabilities, fixtures) {
  commit_rows <- selected[!duplicated(selected[c("sample", "commit_sha")]),
                          c("sample", "commit_sha", "committed_at"), drop = FALSE]
  commit_rows$committed_utc <- parse_utc_time(commit_rows$committed_at)
  commit_rows <- commit_rows[commit_rows$commit_sha %in% unique(stage_probabilities$commit_sha), , drop = FALSE]
  first_kickoff <- min(parse_utc_time(fixtures$kickoff_utc))
  stage_rounds <- c(
    round_of_32 = "Round of 32", round_of_16 = "Round of 16",
    quarterfinal = "Quarter-finals", semifinal = "Semi-finals",
    final = "Final", champion = "Final"
  )
  boundaries <- vapply(stage_rounds, function(round_name) {
    min(as.numeric(parse_utc_time(fixtures$kickoff_utc[fixtures$round == round_name])), na.rm = TRUE)
  }, numeric(1))
  boundaries <- as.POSIXct(boundaries, origin = "1970-01-01", tz = "UTC")
  rows <- list()
  n <- 0L
  for (sample_name in unique(commit_rows$sample)) {
    commits <- commit_rows[commit_rows$sample == sample_name, , drop = FALSE]
    pre_tournament <- commits[commits$committed_utc < first_kickoff, , drop = FALSE]
    if (nrow(pre_tournament)) {
      anchor <- pre_tournament[which.min(pre_tournament$committed_utc), , drop = FALSE]
      for (target_stage in names(stage_rounds)) {
        n <- n + 1L
        rows[[n]] <- data.frame(
          sample = sample_name, anchor_type = "pre_tournament", target_stage = target_stage,
          commit_sha = anchor$commit_sha, forecast_at = format_utc_time(anchor$committed_utc),
          boundary_utc = format_utc_time(boundaries[target_stage]), stringsAsFactors = FALSE
        )
      }
    }
    for (target_stage in names(stage_rounds)) {
      available <- commits[commits$committed_utc < boundaries[target_stage], , drop = FALSE]
      if (!nrow(available)) next
      anchor <- available[which.max(available$committed_utc), , drop = FALSE]
      n <- n + 1L
      rows[[n]] <- data.frame(
        sample = sample_name, anchor_type = "pre_stage", target_stage = target_stage,
        commit_sha = anchor$commit_sha, forecast_at = format_utc_time(anchor$committed_utc),
        boundary_utc = format_utc_time(boundaries[target_stage]), stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  unique(do.call(rbind, rows))
}

actual_stage_teams <- function(fixtures, target_stage) {
  round_map <- c(
    round_of_32 = "Round of 32", round_of_16 = "Round of 16",
    quarterfinal = "Quarter-finals", semifinal = "Semi-finals", final = "Final"
  )
  if (target_stage == "champion") {
    final <- fixtures[fixtures$round == "Final", , drop = FALSE]
    return(normalize_worldcup_team_key(final$actual_winner_team))
  }
  stage <- fixtures[fixtures$round == round_map[target_stage], , drop = FALSE]
  unique(c(normalize_worldcup_team_key(stage$home_team), normalize_worldcup_team_key(stage$away_team)))
}

#' Score anchored tournament stage-reach probabilities
#' @export
score_stage_reach <- function(anchors, stage_probabilities, fixtures) {
  if (!nrow(anchors)) return(data.frame())
  probability_cols <- c(
    round_of_32 = "round_of_32_probability", round_of_16 = "round_of_16_probability",
    quarterfinal = "quarterfinal_probability", semifinal = "semifinal_probability",
    final = "final_probability", champion = "champion_probability"
  )
  rows <- list()
  n <- 0L
  for (i in seq_len(nrow(anchors))) {
    anchor <- anchors[i, , drop = FALSE]
    probabilities <- stage_probabilities[stage_probabilities$commit_sha == anchor$commit_sha, , drop = FALSE]
    if (!nrow(probabilities)) next
    target <- anchor$target_stage
    actual <- actual_stage_teams(fixtures, target)
    for (j in seq_len(nrow(probabilities))) {
      probability <- probabilities[[probability_cols[target]]][j]
      observed <- normalize_worldcup_team_key(probabilities$team[j]) %in% actual
      n <- n + 1L
      rows[[n]] <- data.frame(
        sample = anchor$sample, anchor_type = anchor$anchor_type, target_stage = target,
        commit_sha = anchor$commit_sha, forecast_at = anchor$forecast_at, boundary_utc = anchor$boundary_utc,
        team = probabilities$team[j], probability = probability, observed = as.integer(observed),
        brier = binary_brier(probability, observed),
        log_loss = binary_log_score(probability, observed), stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

checksum_file <- function(path) {
  unname(tools::md5sum(path))
}

#' Write the reproducible World Cup scoring bundle
#' @export
write_worldcup_score_bundle <- function(match_scores, aggregate_scores, calibration_bins,
                                        advancement_scores, stage_reach_scores,
                                        output_dir = "outputs/evaluation/wc2026") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  artifacts <- list(
    match_scores = match_scores, aggregate_scores = aggregate_scores,
    calibration_bins = calibration_bins, advancement_scores = advancement_scores,
    stage_reach_scores = stage_reach_scores
  )
  paths <- file.path(output_dir, paste0(names(artifacts), ".csv"))
  for (i in seq_along(artifacts)) {
    write.csv(artifacts[[i]], paths[i], row.names = FALSE, na = "")
  }
  manifest_path <- file.path(output_dir, "score_manifest.csv")
  manifest <- data.frame(
    artifact = names(artifacts), path = paths,
    rows = vapply(artifacts, nrow, integer(1)),
    md5 = vapply(paths, checksum_file, character(1)), stringsAsFactors = FALSE
  )
  write.csv(manifest, manifest_path, row.names = FALSE)
  manifest
}
