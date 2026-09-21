# UEFA Champions League 2026/27 rules and Article 18 ranking contract.
#
# This module owns only editioned competition semantics.  Match arithmetic and
# canonical lifecycle/score interpretation remain Phase 14 responsibilities;
# the UCL adapter consumes those results and never promotes provider ordering.

.ucl_rule_root <- function() {
  candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
    candidate <- parent
  }
}

.ucl_rule_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_rule_canonical <- function(value) {
  if (is.data.frame(value)) {
    data <- value[, sort(names(value)), drop = FALSE]
    if (nrow(data)) {
      keys <- lapply(data, function(column) vapply(column, .ucl_rule_scalar, character(1)))
      data <- data[do.call(order, c(keys, list(method = "radix", na.last = TRUE))), , drop = FALSE]
    }
    rows <- if (!nrow(data)) character() else vapply(seq_len(nrow(data)), function(index) {
      paste(vapply(data[index, , drop = FALSE], .ucl_rule_scalar, character(1)), collapse = "\x1f")
    }, character(1))
    return(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"))
  }
  if (is.list(value)) {
    if (is.null(names(value))) return(paste(vapply(value, .ucl_rule_canonical, character(1)), collapse = "\x1c"))
    value <- value[sort(names(value))]
    return(paste(paste(names(value), vapply(value, .ucl_rule_canonical, character(1)), sep = "="), collapse = "\x1c"))
  }
  if (length(value) > 1L) return(paste(vapply(value, .ucl_rule_scalar, character(1)), collapse = "\x1f"))
  .ucl_rule_scalar(value)
}

.ucl_rule_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL rules require digest", call. = FALSE)
  digest::digest(charToRaw(enc2utf8(.ucl_rule_canonical(value))), algo = "sha256", serialize = FALSE)
}

.ucl_rule_url_map <- function() {
  c(
    article_17 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-17-Match-system-league-phase-Online",
    article_18 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-18-Equality-of-points-league-phase-Online",
    article_19 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-19-Draw-system-knockout-phase-Online",
    article_20 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-20-Match-system-knockout-phase-Online",
    article_21 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online",
    article_22 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-22-Match-system-final-Online",
    annex_b = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Annex-B-UEFA-Champions-League-Competition-System-Online"
  )
}

.ucl_rule_require_evidence <- function(evidence = NULL, evidence_path = NULL) {
  if (is.null(evidence)) {
    evidence_path <- evidence_path %||% file.path(
      .ucl_rule_root(), "data", "competition", "rules",
      "ucl_2026_27_rules_and_draw_evidence.json"
    )
    if (!file.exists(evidence_path)) stop("UCL rules evidence sidecar is missing", call. = FALSE)
    if (!requireNamespace("jsonlite", quietly = TRUE)) stop("UCL rules require jsonlite", call. = FALSE)
    evidence <- jsonlite::fromJSON(evidence_path, simplifyDataFrame = TRUE)
  }
  if (is.list(evidence) && !is.data.frame(evidence)) {
    evidence <- as.data.frame(evidence, stringsAsFactors = FALSE, check.names = FALSE)
  }
  required <- c(
    "document_id", "article_or_annex", "edition_id", "canonical_domain",
    "canonical_article", "source_url", "artifact_url", "source_url_role",
    "reviewer", "reviewed_at_utc", "raw_sha256", "canonical_sha256",
    "accepted", "complete", "unresolved_reason"
  )
  if (!is.data.frame(evidence) || !identical(names(evidence), required) || nrow(evidence) != 8L) {
    stop("UCL rules evidence must contain exactly eight records with the closed schema", call. = FALSE)
  }
  expected_ids <- c("article_17", "article_18", "article_19", "article_20",
                    "article_21", "article_22", "annex_b", "draw_procedure_2026_27")
  if (anyDuplicated(as.character(evidence$document_id)) ||
      !setequal(as.character(evidence$document_id), expected_ids) ||
      any(as.character(evidence$edition_id) != "ucl_2026_27") ||
      any(as.character(evidence$canonical_domain) != "documents.uefa.com")) {
    stop("UCL rules evidence has an invalid document identity or edition", call. = FALSE)
  }
  urls <- .ucl_rule_url_map()
  regulations <- as.character(evidence$document_id) != "draw_procedure_2026_27"
  for (id in names(urls)) {
    row <- evidence[evidence$document_id == id, , drop = FALSE]
    if (nrow(row) != 1L || !identical(as.character(row$source_url[[1L]]), unname(urls[[id]])) ||
        !identical(as.character(row$artifact_url[[1L]]), unname(urls[[id]])) ||
        !identical(as.character(row$source_url_role[[1L]]), "canonical_regulation_document") ||
        !isTRUE(row$accepted[[1L]]) || !isTRUE(row$complete[[1L]]) ||
        is.na(row$reviewer[[1L]]) || !nzchar(as.character(row$reviewer[[1L]])) ||
        is.na(row$reviewed_at_utc[[1L]]) || !grepl("^[0-9a-f]{64}$", as.character(row$raw_sha256[[1L]])) ||
        !grepl("^[0-9a-f]{64}$", as.character(row$canonical_sha256[[1L]])) ||
        !is.na(row$unresolved_reason[[1L]])) {
      stop(paste0("UCL rules evidence identity/acceptance invalid for ", id), call. = FALSE)
    }
  }
  draw <- evidence[evidence$document_id == "draw_procedure_2026_27", , drop = FALSE]
  if (nrow(draw) != 1L || !identical(as.character(draw$canonical_article[[1L]]), "Article-19-Draw-system-knockout-phase-Online") ||
      !identical(as.character(draw$source_url[[1L]]), unname(urls[["article_19"]])) ||
      !is.na(draw$artifact_url[[1L]]) || !identical(as.character(draw$source_url_role[[1L]]), "governing_rule_anchor_for_missing_artifact") ||
      !identical(as.character(draw$reviewer[[1L]]), "unreviewed") || !is.na(draw$reviewed_at_utc[[1L]]) ||
      !is.na(draw$raw_sha256[[1L]]) || !is.na(draw$canonical_sha256[[1L]]) || isTRUE(draw$accepted[[1L]]) ||
      isTRUE(draw$complete[[1L]]) || !identical(as.character(draw$unresolved_reason[[1L]]), "missing_edition_draw_procedure")) {
    stop("UCL edition-specific draw evidence must remain typed unresolved", call. = FALSE)
  }
  evidence[order(match(as.character(evidence$document_id), expected_ids)), , drop = FALSE]
}

.ucl_rule_contract <- function(evidence = NULL, evidence_path = NULL) {
  evidence <- .ucl_rule_require_evidence(evidence, evidence_path)
  criteria <- data.frame(
    criterion_order = seq_len(10L),
    criterion_id = c(
      "goal_difference", "goals_scored", "away_goals_scored", "wins", "away_wins",
      "opponent_points", "opponent_goal_difference", "opponent_goals_scored",
      "disciplinary_points", "club_coefficient"
    ),
    direction = c(rep("desc", 8L), "asc", "desc"),
    evidence_document_id = c(rep("article_18", 9L), "annex_b"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  contract <- list(
    edition_id = "ucl_2026_27",
    ruleset_version = "ucl-2026-27-rules-v1",
    cardinality = list(clubs = 36L, fixtures = 144L, opponents = 8L, home = 4L, away = 4L, matchdays = 1:8),
    article18 = list(criteria = criteria, interim_max_order = 5L, ranking_phase = "league_phase"),
    rank_bands = data.frame(
      qualification_band = c("direct_round_of_16", "knockout_play_off", "eliminated"),
      rank_min = c(1L, 9L, 25L), rank_max = c(8L, 24L, 36L),
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    draw_policy_id = "ucl-2026-27-article19-annexb-v1",
    draw_evidence_id = "draw_procedure_2026_27",
    two_leg_policy = "aggregate_regulation_then_second_leg_extra_time_then_penalties_no_away_goals",
    final_policy = "single_neutral_match_extra_time_then_penalties",
    evidence = evidence
  )
  contract$ruleset_sha256 <- .ucl_rule_hash(contract[names(contract) != "ruleset_sha256"])
  contract
}

`%||%` <- if (exists("%||%", mode = "function", inherits = TRUE)) get("%||%") else function(left, right) if (!is.null(left)) left else right

.ucl_rule_metric_value <- function(standings, criterion_id, index, matches = NULL) {
  aliases <- switch(
    criterion_id,
    goal_difference = c("goal_difference", "goals_difference"),
    goals_scored = c("goals_scored", "goals_for"),
    away_goals_scored = c("away_goals_scored", "away_goals_for"),
    wins = "wins",
    away_wins = "away_wins",
    opponent_points = c("opponent_points", "opponents_points"),
    opponent_goal_difference = c("opponent_goal_difference", "opponents_goal_difference"),
    opponent_goals_scored = c("opponent_goals_scored", "opponents_goals_scored"),
    disciplinary_points = c("disciplinary_points", "discipline_points"),
    club_coefficient = c("club_coefficient", "coefficient"),
    character()
  )
  field <- aliases[aliases %in% names(standings)][1L]
  if (length(field) && !is.na(field)) return(suppressWarnings(as.numeric(standings[[field]][index])))
  if (criterion_id %in% c("away_goals_scored", "away_wins") &&
      !is.null(matches) && is.data.frame(matches) && nrow(matches)) {
    team_field <- intersect(c("club_id", "team_id", "team"), names(standings))[1L]
    if (length(team_field) && !is.na(team_field)) {
      team <- as.character(standings[[team_field]][index])
      home <- as.character(matches$home_club_id %||% matches$home_team_id) == team
      away <- as.character(matches$away_club_id %||% matches$away_team_id) == team
      home_score <- suppressWarnings(as.numeric(matches$final_home_goals %||% matches$regulation_home_goals))
      away_score <- suppressWarnings(as.numeric(matches$final_away_goals %||% matches$regulation_away_goals))
      if (criterion_id == "away_goals_scored") return(sum(away_score[away], na.rm = TRUE))
      return(sum(away & !is.na(away_score) & !is.na(home_score) & away_score > home_score))
    }
  }
  rep(NA_real_, 1L)
}

.ucl_rule_groups <- function(ids, values, direction) {
  if (length(ids) <= 1L) return(list(ids))
  if (all(is.na(values)) || any(!is.finite(values[!is.na(values)]))) return(list(ids))
  unique_values <- sort(unique(values), decreasing = identical(direction, "desc"), method = "radix")
  lapply(unique_values, function(value) ids[values == value])
}

.ucl_rule_trace_row <- function(rules, tie_group_id, criterion_order, criterion_id,
                                before, after, evidence_status, counted_ids,
                                decisive, rank_min, rank_max) {
  data.frame(
    edition_id = rules$edition_id,
    tie_group_id = as.character(tie_group_id),
    criterion_order = as.integer(criterion_order),
    criterion_id = as.character(criterion_id),
    subset_before = paste(sort(as.character(before)), collapse = ";"),
    subset_after = paste(sort(as.character(after)), collapse = ";"),
    evidence_status = as.character(evidence_status),
    source_artifact_ids = paste(sort(unique(as.character(counted_ids)[nzchar(as.character(counted_ids))])), collapse = ";"),
    decisive = isTRUE(decisive),
    rank_interval_min = as.integer(rank_min),
    rank_interval_max = as.integer(rank_max),
    ruleset_version = rules$ruleset_version,
    ruleset_sha256 = rules$ruleset_sha256,
    row_sha256 = NA_character_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

.ucl_rule_hash_rows <- function(data) {
  if (!nrow(data)) return(character())
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) .ucl_rule_hash(paste(vapply(data[index, fields, drop = FALSE], .ucl_rule_scalar, character(1)), collapse = "|")), character(1))
}

#' Apply the editioned Article 18 final/interim ranking contract.
#'
#' The returned data frame is intentionally rank-incomplete when evidence is
#' missing.  `attr(result, "trace")` is the durable criterion/subset trace.
#' Provider rank columns, when supplied, are retained as reconciliation data
#' and are never consulted to close an unresolved interval.
ucl_apply_article18 <- function(standings, matches = NULL, evidence = NULL,
                                phase = c("final", "interim"), interim = NULL,
                                rules = NULL, evidence_path = NULL) {
  if (!is.data.frame(standings)) stop("UCL Article 18 standings must be a data frame", call. = FALSE)
  team_field <- intersect(c("club_id", "team_id", "team"), names(standings))[1L]
  if (is.na(team_field) || is.null(team_field)) stop("UCL Article 18 standings require club_id or team_id", call. = FALSE)
  ids <- as.character(standings[[team_field]])
  if (!length(ids) || any(is.na(ids) | !nzchar(ids)) || anyDuplicated(ids)) stop("UCL Article 18 standings require unique club IDs", call. = FALSE)
  if (is.null(interim)) interim <- identical(match.arg(phase), "interim") else interim <- isTRUE(interim)
  phase_label <- if (interim) "interim" else "final"
  rules <- rules %||% .ucl_rule_contract(evidence = evidence, evidence_path = evidence_path)
  if (!is.null(evidence) && is.data.frame(evidence) && nrow(evidence) == 0L) evidence <- NULL
  data <- as.data.frame(standings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"points" %in% names(data)) data$points <- 0
  if (anyNA(suppressWarnings(as.numeric(data$points)))) stop("UCL Article 18 points must be numeric", call. = FALSE)
  metric_values <- lapply(rules$article18$criteria$criterion_id, function(id) {
    vapply(seq_len(nrow(data)), function(index) .ucl_rule_metric_value(data, id, index, matches), numeric(1))
  })
  names(metric_values) <- rules$article18$criteria$criterion_id
  ordered_groups <- .ucl_rule_groups(ids, as.numeric(data$points), "desc")
  trace_rows <- list()
  trace_index <- 0L
  rank_rows <- list()
  current_rank <- 1L
  max_criterion <- if (interim) rules$article18$interim_max_order else nrow(rules$article18$criteria)
  add_trace <- function(...) {
    trace_index <<- trace_index + 1L
    trace_rows[[trace_index]] <<- .ucl_rule_trace_row(rules, ...)
  }
  resolve_group <- function(group_ids, start_rank, depth = 0L) {
    if (length(group_ids) <= 1L) return(list(groups = list(group_ids), resolved = TRUE))
    remaining <- group_ids
    resolved_groups <- list()
    for (criterion_order in seq_len(max_criterion)) {
      criterion_id <- rules$article18$criteria$criterion_id[[criterion_order]]
      values <- metric_values[[criterion_id]][match(remaining, ids)]
      available <- all(!is.na(values) & is.finite(values))
      if (!available) {
        add_trace(paste0("tie-", depth + 1L), criterion_order, criterion_id,
                  remaining, remaining, "missing", character(), FALSE,
                  start_rank, start_rank + length(group_ids) - 1L)
        return(list(groups = list(group_ids), resolved = FALSE))
      }
      groups <- .ucl_rule_groups(remaining, values, rules$article18$criteria$direction[[criterion_order]])
      after <- unlist(groups, use.names = FALSE)
      decisive <- length(groups) > 1L
      add_trace(paste0("tie-", depth + 1L), criterion_order, criterion_id,
                remaining, after, "available", character(), decisive,
                start_rank, start_rank + length(group_ids) - 1L)
      if (length(groups) > 1L) {
        # A criterion that separates values is decisive.  Remaining multi-club
        # subsets still need the subsequent criteria, independently.
        out <- list()
        offset <- 0L
        all_resolved <- TRUE
        for (subgroup in groups) {
          sub_result <- resolve_group(subgroup, start_rank + offset, depth + 1L)
          out <- c(out, sub_result$groups)
          all_resolved <- all_resolved && isTRUE(sub_result$resolved)
          offset <- offset + length(subgroup)
        }
        return(list(groups = out, resolved = all_resolved))
      }
    }
    add_trace(paste0("tie-", depth + 1L), max_criterion, "unresolved_late_criterion",
              remaining, remaining, "missing", character(), FALSE,
              start_rank, start_rank + length(group_ids) - 1L)
    list(groups = list(group_ids), resolved = FALSE)
  }
  for (group in ordered_groups) {
    resolved <- resolve_group(group, current_rank)
    for (subgroup in resolved$groups) {
      rank_min <- current_rank
      rank_max <- current_rank + length(subgroup) - 1L
      exact <- isTRUE(resolved$resolved) && length(subgroup) == 1L
      for (club_id in subgroup) {
        rank_rows[[length(rank_rows) + 1L]] <- data.frame(
          club_id = club_id, rank = if (exact) as.integer(current_rank) else NA_integer_,
          rank_interval_min = as.integer(rank_min), rank_interval_max = as.integer(rank_max),
          rank_status = if (exact) "resolved" else "unresolved",
          stringsAsFactors = FALSE, check.names = FALSE
        )
      }
      current_rank <- current_rank + length(subgroup)
    }
  }
  rank_data <- do.call(rbind, rank_rows)
  rank_data <- rank_data[order(rank_data$rank_interval_min, rank_data$club_id, method = "radix"), , drop = FALSE]
  rank_data$qualification_band <- vapply(seq_len(nrow(rank_data)), function(index) {
    lo <- rank_data$rank_interval_min[[index]]; hi <- rank_data$rank_interval_max[[index]]
    if (!is.na(rank_data$rank[[index]])) {
      if (rank_data$rank[[index]] <= 8L) return("direct_round_of_16")
      if (rank_data$rank[[index]] <= 24L) return("knockout_play_off")
      return("eliminated")
    }
    if (lo <= 8L && hi >= 8L || lo <= 24L && hi >= 24L) "unresolved" else if (hi <= 8L) "direct_round_of_16" else if (lo >= 25L) "eliminated" else "knockout_play_off"
  }, character(1))
  result <- data.frame(
    edition_id = rules$edition_id,
    club_id = rank_data$club_id,
    played = if ("played" %in% names(data)) as.integer(data$played[match(rank_data$club_id, ids)]) else NA_integer_,
    wins = if ("wins" %in% names(data)) as.integer(data$wins[match(rank_data$club_id, ids)]) else NA_integer_,
    draws = if ("draws" %in% names(data)) as.integer(data$draws[match(rank_data$club_id, ids)]) else NA_integer_,
    losses = if ("losses" %in% names(data)) as.integer(data$losses[match(rank_data$club_id, ids)]) else NA_integer_,
    goals_for = if ("goals_for" %in% names(data)) as.integer(data$goals_for[match(rank_data$club_id, ids)]) else NA_integer_,
    goals_against = if ("goals_against" %in% names(data)) as.integer(data$goals_against[match(rank_data$club_id, ids)]) else NA_integer_,
    goal_difference = if ("goal_difference" %in% names(data)) as.integer(data$goal_difference[match(rank_data$club_id, ids)]) else NA_integer_,
    points = as.numeric(data$points[match(rank_data$club_id, ids)]),
    ranking_phase = phase_label,
    rank = rank_data$rank,
    rank_interval_min = rank_data$rank_interval_min,
    rank_interval_max = rank_data$rank_interval_max,
    rank_status = rank_data$rank_status,
    qualification_band = rank_data$qualification_band,
    qualification_status = ifelse(rank_data$rank_status == "resolved", "resolved", "unresolved"),
    source_bundle_id = if ("source_bundle_id" %in% names(data)) as.character(data$source_bundle_id[match(rank_data$club_id, ids)]) else NA_character_,
    ruleset_version = rules$ruleset_version,
    ruleset_sha256 = rules$ruleset_sha256,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  trace <- if (length(trace_rows)) do.call(rbind, trace_rows) else data.frame()
  if (nrow(trace)) trace$row_sha256 <- .ucl_rule_hash_rows(trace)
  result <- result[order(result$rank_interval_min, result$club_id, method = "radix"), , drop = FALSE]
  row.names(result) <- NULL
  attr(result, "trace") <- trace
  attr(result, "rules") <- rules
  attr(result, "status") <- if (any(result$rank_status == "unresolved")) "unresolved" else "ready"
  attr(result, "provider_reconciliation") <- if ("rank" %in% names(data) || "computed_rank" %in% names(data)) data[, intersect(c("club_id", "team_id", "rank", "computed_rank", "qualification_band"), names(data)), drop = FALSE] else NULL
  result
}
