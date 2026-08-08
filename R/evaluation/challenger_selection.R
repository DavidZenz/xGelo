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
    phase11_rf_dynamic_elo_open = "dynamic_attack|dynamic_defence|venue|elo_diff",
    phase11_rf_dynamic_elo_context_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context",
    phase11_rf_dynamic_elo_context_drop_host_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context_without_host",
    phase11_rf_dynamic_elo_context_drop_neutral_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context_without_neutral",
    phase11_rf_dynamic_elo_context_drop_rest_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context_without_rest",
    phase11_rf_dynamic_elo_context_drop_travel_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context_without_travel",
    phase11_rf_dynamic_elo_context_drop_stage_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context_without_stage",
    phase11_rf_dynamic_elo_context_xg_gated_open = "dynamic_attack|dynamic_defence|venue|elo_diff|context|xg_gate",
    phase11_structural_sparse_prior_open = "dynamic_attack|dynamic_defence|venue|elo_diff|structural_prior",
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

#' Compare active Phase 11 open candidates with inherited baselines.
#'
#' This wrapper keeps the existing paired-fold implementation as the single
#' comparison engine while adding explicit mode and research-boundary labels.
#' Enriched and external evidence is written by the Phase 11 runner as a
#' separate companion table and is never passed through this open leaderboard.
#' @export
hybrid_all_baseline_comparisons <- function(
    scores, tournaments, panel_fixtures, candidate_ids, baseline_ids,
    parent_hashes, seed = 920001L, score_file_sha256 = NULL
) {
  result <- challenger_all_baseline_comparisons(
    scores = scores,
    tournaments = tournaments,
    panel_fixtures = panel_fixtures,
    candidate_ids = candidate_ids,
    baseline_ids = baseline_ids,
    parent_hashes = parent_hashes,
    seed = seed,
    score_file_sha256 = score_file_sha256
  )
  result$mode_id <- "open_default"
  result$mode_pool <- "open_only"
  result$research_only <- TRUE
  result$wc2026_sealed <- TRUE
  result$phase12_decision_authority <- FALSE
  result
}

#' Build the non-authoritative Phase 11 research shortlist.
#'
#' The shortlist is deliberately slot-based and non-exclusive.  It records
#' evidence identities and paired diagnostics for a later phase to inspect; it
#' does not name a winner or alter any production artifact.
#' @export
build_hybrid_research_shortlist <- function(
    comparisons, candidate_evidence = NULL, protocol = NULL,
    parent_hashes = NULL, threshold = 0.001
) {
  if (!is.data.frame(comparisons)) {
    stop("comparisons must be a data frame", call. = FALSE)
  }
  if (length(threshold) != 1L || !is.finite(threshold) || threshold < 0) {
    stop("threshold must be one non-negative finite scalar", call. = FALSE)
  }
  evidence <- if (nrow(comparisons)) {
    comparisons[
      as.character(comparisons$diagnostic) == "equal_tournament_headline" &
        as.character(comparisons$track_id) == "updating" &
        as.character(comparisons$comparison_panel_id) == "open_core",
      , drop = FALSE
    ]
  } else {
    comparisons
  }
  if (!nrow(evidence) && all(c("candidate_id", "candidate_estimate") %in% names(comparisons))) {
    evidence <- comparisons
  }
  if (!nrow(evidence)) {
    return(data.frame(
      slot = character(), candidate_id = character(), mode_id = character(),
      panel_id = character(), candidate_estimate = numeric(), baseline_id = character(),
      baseline_estimate = numeric(), delta = numeric(), paired_fixture_count = integer(),
      evidence_sha256 = character(), selection_basis = character(),
      non_exclusive = logical(), research_only = logical(), wc2026_sealed = logical(),
      phase12_decision_authority = logical(), parent_graph_sha256 = character(),
      selection_protocol_sha256 = character(), stringsAsFactors = FALSE
    ))
  }
  challenger_selection_require_columns(
    evidence,
    c("candidate_id", "candidate_estimate", "baseline_id", "baseline_estimate", "delta"),
    "hybrid shortlist comparisons"
  )
  evidence$candidate_id <- as.character(evidence$candidate_id)
  evidence$baseline_id <- as.character(evidence$baseline_id)
  evidence$candidate_estimate <- suppressWarnings(as.numeric(evidence$candidate_estimate))
  evidence$baseline_estimate <- suppressWarnings(as.numeric(evidence$baseline_estimate))
  evidence$delta <- suppressWarnings(as.numeric(evidence$delta))
  if (any(!nzchar(evidence$candidate_id)) || any(!is.finite(evidence$candidate_estimate)) ||
      any(!is.finite(evidence$baseline_estimate)) || any(!is.finite(evidence$delta))) {
    stop("hybrid shortlist comparisons contain incomplete proper-score evidence", call. = FALSE)
  }

  lookup_evidence <- function(candidate_id) {
    rows <- evidence[evidence$candidate_id == candidate_id, , drop = FALSE]
    if (!nrow(rows)) stop("hybrid shortlist candidate has no paired evidence: ", candidate_id, call. = FALSE)
    rows <- rows[order(rows$candidate_estimate, rows$baseline_id, method = "radix"), , drop = FALSE]
    rows[1L, , drop = FALSE]
  }
  candidates <- sort(unique(evidence$candidate_id), method = "radix")
  aggregate <- do.call(rbind, lapply(candidates, lookup_evidence))
  rownames(aggregate) <- NULL
  aggregate$complexity_rank <- 9999
  aggregate$mode_id <- "open_default"
  aggregate$panel_id <- "open_core"
  if (!is.null(candidate_evidence) && is.data.frame(candidate_evidence) && nrow(candidate_evidence)) {
    challenger_selection_require_columns(candidate_evidence, c("candidate_id"), "candidate evidence")
    candidate_evidence$candidate_id <- as.character(candidate_evidence$candidate_id)
    match_index <- match(aggregate$candidate_id, candidate_evidence$candidate_id)
    if ("mode_id" %in% names(candidate_evidence)) {
      aggregate$mode_id <- ifelse(
        is.na(match_index), aggregate$mode_id,
        as.character(candidate_evidence$mode_id[match_index])
      )
    }
    if ("panel_id" %in% names(candidate_evidence)) {
      aggregate$panel_id <- ifelse(
        is.na(match_index), aggregate$panel_id,
        as.character(candidate_evidence$panel_id[match_index])
      )
    }
    if ("complexity_rank" %in% names(candidate_evidence)) {
      ranks <- suppressWarnings(as.numeric(candidate_evidence$complexity_rank[match_index]))
      aggregate$complexity_rank <- ifelse(is.finite(ranks), ranks, aggregate$complexity_rank)
    }
    if ("active_status" %in% names(candidate_evidence)) {
      active <- tolower(as.character(candidate_evidence$active_status[match_index]))
      aggregate <- aggregate[is.na(active) | active %in% c("active", "scored"), , drop = FALSE]
    }
  }
  if (!nrow(aggregate)) stop("hybrid shortlist has no active open candidate evidence", call. = FALSE)
  aggregate <- aggregate[aggregate$mode_id == "open_default" & aggregate$panel_id == "open_core", , drop = FALSE]
  if (!nrow(aggregate)) stop("hybrid shortlist cannot pool non-open modes", call. = FALSE)
  aggregate$practically_non_inferior <- aggregate$candidate_estimate <= (
    min(aggregate$candidate_estimate) + as.numeric(threshold)
  )
  best <- aggregate[order(
    aggregate$candidate_estimate, aggregate$candidate_id, method = "radix"
  )[1L], , drop = FALSE]
  simple <- aggregate[aggregate$practically_non_inferior, , drop = FALSE]
  simple <- simple[order(simple$complexity_rank, simple$candidate_estimate, simple$candidate_id, method = "radix"), , drop = FALSE][1L, , drop = FALSE]
  context_ids <- grep("context_open$", aggregate$candidate_id, value = TRUE)
  context <- if (length(context_ids)) {
    context_rows <- aggregate[aggregate$candidate_id %in% context_ids, , drop = FALSE]
    context_rows[order(context_rows$candidate_estimate, context_rows$candidate_id, method = "radix")[1L], , drop = FALSE]
  } else best
  selected <- rbind(best, simple, context)
  slots <- c("best_proper_score", "simplest_non_inferior", "context_representative")
  if (is.null(parent_hashes)) {
    parent_hashes <- setNames(strrep("0", 64), "phase11_parent")
  }
  parent_graph <- challenger_selection_parent_graph_sha256(parent_hashes)
  selection_protocol <- digest::digest(
    paste("phase11_hybrid_research_shortlist_v1", threshold, parent_graph, sep = "|"),
    algo = "sha256", serialize = FALSE
  )
  evidence_hash <- function(row) {
    values <- row[intersect(
      c("candidate_id", "baseline_id", "candidate_estimate", "baseline_estimate", "delta",
        "paired_fixture_count", "mode_id", "panel_id"), names(row)
    )]
    digest::digest(paste(names(values), as.character(values), sep = "=", collapse = "|"),
      algo = "sha256", serialize = FALSE
    )
  }
  output <- data.frame(
    slot = slots,
    candidate_id = as.character(selected$candidate_id),
    mode_id = as.character(selected$mode_id),
    panel_id = as.character(selected$panel_id),
    candidate_estimate = as.numeric(selected$candidate_estimate),
    baseline_id = as.character(selected$baseline_id),
    baseline_estimate = as.numeric(selected$baseline_estimate),
    delta = as.numeric(selected$delta),
    paired_fixture_count = if ("paired_fixture_count" %in% names(selected)) as.integer(selected$paired_fixture_count) else NA_integer_,
    evidence_sha256 = vapply(seq_len(nrow(selected)), function(i) evidence_hash(selected[i, , drop = FALSE]), character(1)),
    selection_basis = c(
      "lowest_open_updating_headline_proper_score",
      "lowest_complexity_within_registered_practical_tie",
      "registered_context_family_representative"
    ),
    non_exclusive = TRUE,
    research_only = TRUE,
    wc2026_sealed = TRUE,
    phase12_decision_authority = FALSE,
    parent_graph_sha256 = parent_graph,
    selection_protocol_sha256 = selection_protocol,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  validate_hybrid_research_shortlist(output)
  output
}

#' Validate the durable, research-only Phase 11 shortlist.
#' @export
validate_hybrid_research_shortlist <- function(shortlist) {
  required <- c(
    "slot", "candidate_id", "mode_id", "panel_id", "candidate_estimate",
    "baseline_id", "baseline_estimate", "delta", "paired_fixture_count",
    "evidence_sha256", "selection_basis", "non_exclusive", "research_only",
    "wc2026_sealed", "phase12_decision_authority", "parent_graph_sha256",
    "selection_protocol_sha256"
  )
  challenger_selection_require_columns(shortlist, required, "hybrid research shortlist")
  if (!identical(names(shortlist), required) || nrow(shortlist) != 3L ||
      !identical(as.character(shortlist$slot), c(
        "best_proper_score", "simplest_non_inferior", "context_representative"
      ))) {
    stop("hybrid shortlist schema or slot order drifted", call. = FALSE)
  }
  if (any(is.na(shortlist$candidate_id) | !nzchar(as.character(shortlist$candidate_id))) ||
      any(as.character(shortlist$mode_id) != "open_default") ||
      any(as.character(shortlist$panel_id) != "open_core") ||
      any(!grepl("^[0-9a-f]{64}$", as.character(shortlist$evidence_sha256))) ||
      any(!grepl("^[0-9a-f]{64}$", as.character(shortlist$parent_graph_sha256))) ||
      any(!grepl("^[0-9a-f]{64}$", as.character(shortlist$selection_protocol_sha256))) ||
      any(!as.logical(shortlist$non_exclusive)) || any(!as.logical(shortlist$research_only)) ||
      any(!as.logical(shortlist$wc2026_sealed)) || any(as.logical(shortlist$phase12_decision_authority))) {
    stop("hybrid shortlist contains invalid flags, labels, or evidence hashes", call. = FALSE)
  }
  forbidden <- "promot|release|winner|final_holdout|final_selection|decision_authority.*true"
  if (any(grepl(forbidden, unlist(shortlist, use.names = FALSE), ignore.case = TRUE))) {
    stop("hybrid shortlist crossed its research-only boundary", call. = FALSE)
  }
  TRUE
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
