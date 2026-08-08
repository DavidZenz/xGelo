#' Research-only selection services for Phase 10 statistical challengers

challenger_selection_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

challenger_selection_require_ids <- function(values, name) {
  values <- as.character(values)
  if (!length(values) || anyDuplicated(values) || any(is.na(values) | !nzchar(values))) {
    stop(name, " must contain unique non-empty identities", call. = FALSE)
  }
  values
}

challenger_selection_parent_graph_sha256 <- function(parent_hashes) {
  parent_hashes <- as.character(parent_hashes)
  if (!length(parent_hashes) || any(!grepl("^[0-9a-f]{64}$", parent_hashes))) {
    stop("parent_hashes must contain canonical SHA-256 values", call. = FALSE)
  }
  labels <- names(parent_hashes)
  if (is.null(labels) || any(!nzchar(labels)) || anyDuplicated(labels)) {
    labels <- sprintf("parent_%03d", seq_along(parent_hashes))
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for challenger selection", call. = FALSE)
  }
  order_index <- order(labels, method = "radix")
  digest::digest(
    paste(labels[order_index], parent_hashes[order_index], sep = "=", collapse = "|"),
    algo = "sha256", serialize = FALSE
  )
}

challenger_selection_scores <- function(scores, score_file_sha256 = NULL) {
  if (is.data.frame(scores)) return(scores)
  if (!is.character(scores) || length(scores) != 1L || is.na(scores) || !nzchar(scores) ||
      !file.exists(scores)) {
    stop("scores must be a data frame or one existing durable score path", call. = FALSE)
  }
  if (!is.character(score_file_sha256) || length(score_file_sha256) != 1L ||
      !grepl("^[0-9a-f]{64}$", score_file_sha256)) {
    stop("durable score reads require one canonical expected SHA-256", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for durable score validation", call. = FALSE)
  }
  actual <- digest::digest(file = scores, algo = "sha256", serialize = FALSE)
  if (!identical(tolower(actual), tolower(score_file_sha256))) {
    stop("durable Phase 9 fixture-score SHA-256 mismatch", call. = FALSE)
  }
  utils::read.csv(scores, stringsAsFactors = FALSE)
}

challenger_selection_active_features <- function(candidate_id) {
  switch(
    candidate_id,
    poisson_team_ridge = "team_attack|team_defence|venue",
    poisson_team_ridge_elo = "team_attack|team_defence|venue|elo_diff",
    dynamic_goal_ability = "dynamic_attack|dynamic_defence|venue",
    dynamic_goal_ability_elo = "dynamic_attack|dynamic_defence|venue|elo_diff",
    poisson_team_ridge_elo_dc = "team_attack|team_defence|venue|elo_diff|dixon_coles",
    poisson_team_ridge_elo_bivpois = "team_attack|team_defence|venue|elo_diff|bivariate_poisson",
    open_nb_elo_only_ablation = "elo_diff",
    stop("candidate_id has no registered active feature set", call. = FALSE)
  )
}

challenger_selection_comparison_rows <- function(
    paired, candidate_id, baseline_id, panel_id, track_id, parent_graph_sha256
) {
  common <- list(
    candidate_id = candidate_id,
    baseline_id = baseline_id,
    comparison_panel_id = panel_id,
    track_id = track_id,
    metric = "rps",
    target = "regulation_1x2",
    active_feature_set = challenger_selection_active_features(candidate_id),
    parent_hashes = parent_graph_sha256
  )
  make_rows <- function(data, diagnostic) {
    data.frame(
      common,
      diagnostic = diagnostic,
      edition_id = if ("edition_id" %in% names(data)) as.character(data$edition_id) else "",
      omitted_edition_id = if ("omitted_edition_id" %in% names(data)) as.character(data$omitted_edition_id) else "",
      competition_id = if ("competition_id" %in% names(data)) as.character(data$competition_id) else "",
      candidate_estimate = if ("challenger_estimate" %in% names(data)) as.numeric(data$challenger_estimate) else NA_real_,
      baseline_estimate = if ("incumbent_estimate" %in% names(data)) as.numeric(data$incumbent_estimate) else NA_real_,
      delta = if ("delta" %in% names(data)) as.numeric(data$delta) else if ("estimate" %in% names(data)) as.numeric(data$estimate) else NA_real_,
      paired_fixture_count = if ("paired_fixture_count" %in% names(data)) as.integer(data$paired_fixture_count) else NA_integer_,
      lower = if ("lower" %in% names(data)) as.numeric(data$lower) else NA_real_,
      upper = if ("upper" %in% names(data)) as.numeric(data$upper) else NA_real_,
      fold_wins = if ("fold_wins" %in% names(data)) as.integer(data$fold_wins) else NA_integer_,
      world_cup_wins = if ("world_cup_wins" %in% names(data)) as.integer(data$world_cup_wins) else NA_integer_,
      euro_wins = if ("euro_wins" %in% names(data)) as.integer(data$euro_wins) else NA_integer_,
      maximum_fold_regression = if ("maximum_fold_regression" %in% names(data)) as.numeric(data$maximum_fold_regression) else NA_real_,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  pooled <- data.frame(
    challenger_estimate = mean(paired$fixtures$value_challenger),
    incumbent_estimate = mean(paired$fixtures$value_incumbent),
    delta = mean(paired$fixtures$delta),
    paired_fixture_count = nrow(paired$fixtures),
    stringsAsFactors = FALSE
  )
  headline <- data.frame(
    challenger_estimate = mean(paired$folds$challenger_estimate),
    incumbent_estimate = mean(paired$folds$incumbent_estimate),
    delta = paired$headline$delta,
    paired_fixture_count = nrow(paired$fixtures),
    stringsAsFactors = FALSE
  )
  rbind(
    make_rows(paired$folds, "fold"),
    make_rows(headline, "equal_tournament_headline"),
    make_rows(pooled, "fixture_weighted_secondary"),
    make_rows(paired$bootstrap, "tournament_bootstrap"),
    make_rows(paired$breadth, "fold_breadth"),
    make_rows(paired$leave_one_out, "leave_one_tournament_out")
  )
}

#' Pair every Phase 10 candidate with all five frozen Phase 9 baselines
#'
#' @param scores Fixture-score data or a checksum-validated durable CSV path.
#' @param tournaments Frozen 12-edition registry.
#' @param panel_fixtures Frozen panel membership registry.
#' @param candidate_ids Exact Phase 10 candidate identities.
#' @param baseline_ids Exact Phase 9 baseline identities.
#' @param parent_hashes Checked parent identities represented in every row.
#' @param seed Registered tournament-bootstrap seed.
#' @param score_file_sha256 Required expected hash when `scores` is a path.
#' @return Long comparison evidence with folds and diagnostics.
#' @export
challenger_all_baseline_comparisons <- function(
    scores, tournaments, panel_fixtures, candidate_ids, baseline_ids,
    parent_hashes, seed = 920001L, score_file_sha256 = NULL
) {
  scores <- challenger_selection_scores(scores, score_file_sha256)
  candidate_ids <- challenger_selection_require_ids(candidate_ids, "candidate_ids")
  baseline_ids <- challenger_selection_require_ids(baseline_ids, "baseline_ids")
  challenger_selection_require_columns(
    scores,
    c("model_id", "edition_id", "track_id", "fixture_id", "target", "metric", "value", "covered"),
    "challenger fixture scores"
  )
  challenger_selection_require_columns(
    tournaments, c("edition_id", "competition_id"), "tournament registry"
  )
  if (!identical(length(unique(as.character(tournaments$edition_id))), 12L)) {
    stop("challenger comparisons require the exact 12-edition registry", call. = FALSE)
  }
  missing_models <- setdiff(c(candidate_ids, baseline_ids), unique(as.character(scores$model_id)))
  if (length(missing_models)) {
    stop("challenger fixture scores omit registered models: ", paste(missing_models, collapse = ", "), call. = FALSE)
  }
  tracks <- sort(unique(as.character(scores$track_id)), method = "radix")
  if (!identical(tracks, c("frozen", "updating"))) {
    stop("challenger comparisons require exact frozen and updating tracks", call. = FALSE)
  }
  parent_graph_sha256 <- challenger_selection_parent_graph_sha256(parent_hashes)

  output <- list()
  cursor <- 0L
  for (candidate_id in candidate_ids) {
    for (baseline_id in baseline_ids) {
      panel_id <- if (identical(baseline_id, "production_hybrid_nb")) "feature_rich" else "open_core"
      expected_fixture_ids <- benchmark_panel_fixture_ids(panel_fixtures, panel_id)
      expected_count <- if (identical(panel_id, "feature_rich")) 609L else 630L
      if (!identical(length(expected_fixture_ids), expected_count)) {
        stop("comparison panel fixture count drifted from 630/609", call. = FALSE)
      }
      for (track_id in tracks) {
        selected <- scores[
          as.character(scores$track_id) == track_id &
            as.character(scores$model_id) %in% c(candidate_id, baseline_id) &
            as.character(scores$fixture_id) %in% expected_fixture_ids,
          , drop = FALSE
        ]
        candidate_fixtures <- as.character(selected$fixture_id[selected$model_id == candidate_id])
        baseline_fixtures <- as.character(selected$fixture_id[selected$model_id == baseline_id])
        if (!setequal(candidate_fixtures, expected_fixture_ids) ||
            !setequal(baseline_fixtures, expected_fixture_ids)) {
          stop("candidate and baseline fixture IDs differ from the explicit comparison panel", call. = FALSE)
        }
        paired <- make_paired_fold_comparisons(
          selected, candidate_id, baseline_id, tournaments, expected_fixture_ids,
          metric = "rps", target = "regulation_1x2", reps = 10000L, seed = seed
        )
        cursor <- cursor + 1L
        output[[cursor]] <- challenger_selection_comparison_rows(
          paired, candidate_id, baseline_id, panel_id, track_id, parent_graph_sha256
        )
      }
    }
  }
  result <- do.call(rbind, output)
  rownames(result) <- NULL
  result
}

#' Select the research representative among shared-mean dependence variants
#' @export
select_dependence_representative <- function(
    evidence, meaningful_gain = -0.001, practical_tie = 0.0005
) {
  required <- c(
    "candidate_id", "updating_rps_delta", "brier_veto", "log_loss_veto",
    "calibration_veto", "fold_breadth_veto", "stability_veto"
  )
  challenger_selection_require_columns(evidence, required, "dependence evidence")
  expected <- c(
    "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
    "poisson_team_ridge_elo_bivpois"
  )
  if (anyDuplicated(evidence$candidate_id) || !setequal(as.character(evidence$candidate_id), expected)) {
    stop("dependence evidence must contain the exact shared-mean candidate family", call. = FALSE)
  }
  if (length(meaningful_gain) != 1L || !is.finite(meaningful_gain) ||
      length(practical_tie) != 1L || !is.finite(practical_tie) || practical_tie < 0) {
    stop("dependence thresholds must be finite registered scalars", call. = FALSE)
  }
  veto_columns <- c(
    "brier_veto", "log_loss_veto", "calibration_veto",
    "fold_breadth_veto", "stability_veto"
  )
  if (any(vapply(evidence[veto_columns], function(x) anyNA(as.logical(x)), logical(1))) ||
      any(!is.finite(as.numeric(evidence$updating_rps_delta)))) {
    stop("dependence evidence contains incomplete decision inputs", call. = FALSE)
  }
  corrections <- evidence[evidence$candidate_id != "poisson_team_ridge_elo", , drop = FALSE]
  corrections$valid <- !apply(corrections[veto_columns], 1L, function(x) any(as.logical(x)))
  valid <- corrections[corrections$valid, , drop = FALSE]
  if (!nrow(valid)) stop("no dependence correction clears the supporting vetoes", call. = FALSE)
  valid <- valid[order(valid$updating_rps_delta, valid$candidate_id, method = "radix"), , drop = FALSE]
  representative <- valid[1L, , drop = FALSE]
  dc <- valid[valid$candidate_id == "poisson_team_ridge_elo_dc", , drop = FALSE]
  if (nrow(dc) && abs(dc$updating_rps_delta - representative$updating_rps_delta) <= practical_tie) {
    representative <- dc
  }
  meaningful <- representative$updating_rps_delta <= meaningful_gain
  list(
    representative_id = as.character(representative$candidate_id),
    preferred_candidate_id = if (meaningful) as.character(representative$candidate_id) else "poisson_team_ridge_elo",
    meaningful_gain = isTRUE(meaningful),
    updating_rps_delta = as.numeric(representative$updating_rps_delta),
    supporting_vetoes_clear = TRUE,
    selection_basis = if (meaningful) "valid_meaningful_dependence_gain" else "valid_correction_without_meaningful_gain"
  )
}

#' Build the three frozen, non-exclusive Phase 10 research slots
#' @export
build_statistical_shortlist <- function(evidence, dependence_representative) {
  required <- c(
    "candidate_id", "updating_equal_tournament_rps", "practically_non_inferior",
    "complexity_rank", "evidence_sha256"
  )
  challenger_selection_require_columns(evidence, required, "shortlist evidence")
  challenger_selection_require_ids(evidence$candidate_id, "shortlist evidence candidate_id")
  updating_rps <- suppressWarnings(as.numeric(as.character(evidence$updating_equal_tournament_rps)))
  complexity_rank <- suppressWarnings(as.numeric(as.character(evidence$complexity_rank)))
  practically_non_inferior <- as.logical(evidence$practically_non_inferior)
  evidence_sha256 <- as.character(evidence$evidence_sha256)
  if (!nrow(evidence) || any(!is.finite(updating_rps)) ||
      any(!is.finite(complexity_rank)) || anyNA(practically_non_inferior) ||
      any(is.na(evidence_sha256) | !grepl("^[0-9a-f]{64}$", evidence_sha256))) {
    stop("shortlist evidence contains invalid identities, metrics, ranks, or hashes", call. = FALSE)
  }
  evidence$updating_equal_tournament_rps <- updating_rps
  evidence$complexity_rank <- complexity_rank
  evidence$practically_non_inferior <- practically_non_inferior
  evidence$evidence_sha256 <- evidence_sha256
  best <- evidence[order(
    evidence$updating_equal_tournament_rps, evidence$complexity_rank,
    evidence$candidate_id, method = "radix"
  )[1L], , drop = FALSE]
  simpler <- evidence[evidence$practically_non_inferior, , drop = FALSE]
  if (!nrow(simpler)) stop("shortlist evidence has no practically non-inferior candidate", call. = FALSE)
  simpler <- simpler[order(
    simpler$complexity_rank, simpler$updating_equal_tournament_rps,
    simpler$candidate_id, method = "radix"
  )[1L], , drop = FALSE]
  dependence <- evidence[
    as.character(evidence$candidate_id) == as.character(dependence_representative),
    , drop = FALSE
  ]
  if (nrow(dependence) != 1L) {
    stop("dependence representative must resolve to one evidence row", call. = FALSE)
  }
  selected <- rbind(best, simpler, dependence)
  shortlist <- data.frame(
    slot = c("best_proper_score", "simplest_non_inferior", "dependence_representative"),
    candidate_id = as.character(selected$candidate_id),
    evidence_sha256 = as.character(selected$evidence_sha256),
    selection_basis = c(
      "lowest_updating_equal_tournament_rps",
      "lowest_complexity_practically_non_inferior",
      "registered_dependence_representative"
    ),
    non_exclusive = TRUE,
    stringsAsFactors = FALSE
  )
  validate_statistical_shortlist(shortlist)
  shortlist
}

#' Validate the exact research-only shortlist schema and slot order
#' @export
validate_statistical_shortlist <- function(shortlist) {
  durable <- "shortlist_slot" %in% names(shortlist)
  required <- if (durable) {
    c(
      "shortlist_slot", "challenger_id", "evidence_sha256", "selection_basis",
      "selection_protocol_sha256", "non_exclusive"
    )
  } else {
    c("slot", "candidate_id", "evidence_sha256", "selection_basis", "non_exclusive")
  }
  challenger_selection_require_columns(shortlist, required, "statistical shortlist")
  slot_column <- if (durable) "shortlist_slot" else "slot"
  candidate_column <- if (durable) "challenger_id" else "candidate_id"
  if (!identical(names(shortlist), required) || !identical(
    as.character(shortlist[[slot_column]]),
    c("best_proper_score", "simplest_non_inferior", "dependence_representative")
  )) {
    stop("statistical shortlist schema or frozen slot order drifted", call. = FALSE)
  }
  if (nrow(shortlist) != 3L ||
      any(is.na(shortlist[[candidate_column]]) | !nzchar(shortlist[[candidate_column]])) ||
      any(!grepl("^[0-9a-f]{64}$", shortlist$evidence_sha256)) ||
      any(is.na(shortlist$non_exclusive) | !shortlist$non_exclusive)) {
    stop("statistical shortlist contains invalid research evidence", call. = FALSE)
  }
  if (durable && any(!grepl("^[0-9a-f]{64}$", shortlist$selection_protocol_sha256))) {
    stop("statistical shortlist selection protocol identity is invalid", call. = FALSE)
  }
  forbidden <- "promot|release|winner|final_holdout|wc2026"
  if (any(grepl(forbidden, names(shortlist), ignore.case = TRUE)) ||
      any(grepl(forbidden, unlist(shortlist, use.names = FALSE), ignore.case = TRUE))) {
    stop("statistical shortlist crossed its research-only boundary", call. = FALSE)
  }
  TRUE
}
