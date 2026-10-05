# Pure EURO 2028 priority outlook. This is a candidate queue before exclusions,
# not an allocation of play-off tickets and not a EURO qualifying simulation.

uefa_euro_priority_policy <- function() {
  list(
    policy_version = "uefa-euro-2028-nl-priority-v1",
    edition_id = "uefa_euro_2028_qualifying",
    nations_league_edition_id = "uefa_nations_league_2026_27",
    regulations_effective_date = "2026-07-29",
    source_url = "https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-16-Path-formation-play-offs-Online",
    article = "16.02(b-d)",
    ranking_scope = "interim_overall",
    priority_leagues = c("A", "B", "C"),
    d_policy = "highest_ranked_group_winner_only_if_insufficient_eligible_abc_winners",
    remaining_policy = "interim_overall_rank",
    exclusions = "not_applied_in_priority_outlook",
    quantile_type = 1L,
    evidence = paste(
      "Available League A, B and C group winners have priority in interim overall ranking order.",
      "If insufficient such winners are available, the highest-ranked League D group winner receives the next place unless already qualified.",
      "Remaining places follow interim overall ranking order, excluding teams already qualified for the finals or play-offs."
    )
  )
}

uefa_euro_priority_policy_sha256 <- function(policy = uefa_euro_priority_policy()) {
  digest::digest(jsonlite::toJSON(policy, auto_unbox = TRUE, null = "null", digits = NA),
                 algo = "sha256", serialize = FALSE)
}

uefa_euro_priority_metrics <- function() {
  c("p_group_winner", "p_winner_priority", "expected_interim_rank", "expected_queue_position")
}

# Availability is assessed separately: a blocked global ordering must not hide
# a known group finish. No current/final ranking fallback is permitted.
uefa_euro_priority_capture <- function(interim, groups, iteration, group_rankings = NULL, unresolved_groups = character()) {
  required <- c("team_id", "league", "group_id")
  if (!is.data.frame(groups) || !all(required %in% names(groups)) || anyDuplicated(groups$team_id)) {
    stop("EURO priority requires a unique accepted team roster", call. = FALSE)
  }
  roster <- groups[order(as.character(groups$team_id), method = "radix"), required, drop = FALSE]
  if (anyNA(roster) || any(!nzchar(as.character(roster$team_id)))) stop("EURO priority roster is incomplete", call. = FALSE)
  if (any(!roster$league %in% c("A", "B", "C", "D"))) stop("EURO priority roster has a foreign league", call. = FALSE)
  if (!is.data.frame(interim)) interim <- data.frame()
  if (nrow(interim) && (!"team_id" %in% names(interim) || anyDuplicated(interim$team_id) || any(!interim$team_id %in% roster$team_id))) {
    stop("EURO priority interim team identities are invalid", call. = FALSE)
  }
  lookup <- function(frame, field) {
    if (!is.data.frame(frame) || !all(c("team_id", field) %in% names(frame))) return(rep(NA, nrow(roster)))
    frame[[field]][match(roster$team_id, frame$team_id)]
  }
  group_rows <- if (is.null(group_rankings)) interim else if (is.data.frame(group_rankings)) group_rankings else {
    frames <- Filter(function(x) is.data.frame(x) && nrow(x), group_rankings)
    if (length(frames)) do.call(rbind, frames) else data.frame()
  }
  if (nrow(group_rows) && anyDuplicated(group_rows$team_id)) stop("EURO priority group team identities are invalid", call. = FALSE)
  positions <- suppressWarnings(as.numeric(lookup(group_rows, "group_position")))
  group_ready <- as.character(lookup(group_rows, "ordering_status")) == "ready"
  group_ready[is.na(group_ready)] <- FALSE
  group_size <- as.integer(table(roster$group_id)[as.character(roster$group_id)])
  group_ready <- group_ready & is.finite(positions) & positions >= 1 & positions <= group_size & positions == floor(positions)
  group_ready[roster$group_id %in% unresolved_groups] <- FALSE
  # A group cannot contain duplicate finishes or only a partial ordering.
  for (id in unique(roster$group_id)) {
    indexes <- which(roster$group_id == id)
    if (!all(group_ready[indexes]) || !setequal(positions[indexes], seq_along(indexes))) group_ready[indexes] <- FALSE
  }
  winners <- ifelse(group_ready, as.numeric(positions == 1), NA_real_)
  ranks <- suppressWarnings(as.numeric(lookup(interim, "interim_rank")))
  rank_ready <- as.character(lookup(interim, "ordering_status")) == "ready"
  rank_ready[is.na(rank_ready)] <- FALSE
  rank_ready <- rank_ready & is.finite(ranks) & ranks >= 1 & ranks <= nrow(roster) & ranks == floor(ranks)
  rank_ready[roster$league %in% unique(roster$league[roster$group_id %in% unresolved_groups])] <- FALSE
  ranks[!rank_ready] <- NA_real_
  if (anyDuplicated(ranks[is.finite(ranks)])) stop("EURO priority contains duplicate resolved interim ranks", call. = FALSE)
  priority <- winners
  d <- which(roster$league == "D")
  priority[d] <- NA_real_
  d_winners <- d[is.finite(winners[d]) & winners[d] == 1]
  if (length(d) && all(is.finite(winners[d])) && length(d_winners) && all(is.finite(ranks[d_winners]))) {
    priority[d] <- 0
    priority[d_winners[which.min(ranks[d_winners])]] <- 1
  }
  queue <- rep(NA_real_, nrow(roster))
  if (all(is.finite(ranks)) && setequal(ranks, seq_len(nrow(roster))) && all(is.finite(priority))) {
    tiers <- ifelse(roster$league %in% c("A", "B", "C") & priority == 1, 1L,
                    ifelse(roster$league == "D" & priority == 1, 2L, 3L))
    order_index <- order(tiers, ranks, method = "radix")
    queue[order_index] <- seq_len(nrow(roster))
  }
  data.frame(iteration = as.integer(iteration), roster, p_group_winner = winners,
             p_winner_priority = priority, expected_interim_rank = ranks,
             expected_queue_position = queue, stringsAsFactors = FALSE, row.names = NULL)
}

uefa_euro_priority_aggregate <- function(captures, groups, simulation_count) {
  if (!is.data.frame(captures)) stop("EURO priority captures must be a data frame", call. = FALSE)
  metrics <- uefa_euro_priority_metrics()
  roster <- groups[order(as.character(groups$team_id), method = "radix"), c("team_id", "league", "group_id"), drop = FALSE]
  policy <- uefa_euro_priority_policy()
  rows <- lapply(seq_len(nrow(roster)), function(index) {
    row <- roster[index, , drop = FALSE]
    team <- if (nrow(captures)) captures[captures$team_id == row$team_id, , drop = FALSE] else captures
    complete <- nrow(team) == simulation_count && "iteration" %in% names(team) &&
      !anyDuplicated(team$iteration) && setequal(team$iteration, seq_len(simulation_count))
    for (metric in metrics) {
      values <- if (metric %in% names(team)) suppressWarnings(as.numeric(team[[metric]])) else numeric()
      available <- complete && length(values) == simulation_count && all(is.finite(values))
      row[[metric]] <- if (available) mean(values) else NA_real_
      row[[paste0(metric, "_reason")]] <- if (available) "" else "incomplete_simulated_group_or_interim_ordering"
    }
    queue <- team$expected_queue_position
    available <- is.finite(row$expected_queue_position)
    row$queue_position_p10 <- if (available) unname(stats::quantile(queue, .1, type = policy$quantile_type)) else NA_real_
    row$queue_position_p90 <- if (available) unname(stats::quantile(queue, .9, type = policy$quantile_type)) else NA_real_
    row$status <- if (all(is.finite(unlist(row[metrics])))) "projected" else "unresolved"
    row$priority_policy_version <- policy$policy_version
    row$priority_policy_sha256 <- uefa_euro_priority_policy_sha256(policy)
    row
  })
  do.call(rbind, rows)
}

uefa_euro_validate_priority <- function(rows, roster = NULL, tolerance = 1e-8) {
  if (!is.data.frame(rows) || !nrow(rows) || anyDuplicated(rows$team_id)) stop("EURO priority summary requires one row per team", call. = FALSE)
  if (!is.null(roster) && (!setequal(rows$team_id, roster$team_id) || any(rows$league != roster$league[match(rows$team_id, roster$team_id)]) ||
      any(rows$group_id != roster$group_id[match(rows$team_id, roster$team_id)]))) stop("EURO priority summary roster mismatch", call. = FALSE)
  policy <- uefa_euro_priority_policy()
  if (anyNA(rows$priority_policy_version) || anyNA(rows$priority_policy_sha256) ||
      any(rows$priority_policy_version != policy$policy_version) || any(rows$priority_policy_sha256 != uefa_euro_priority_policy_sha256(policy))) {
    stop("EURO priority policy version/hash mismatch", call. = FALSE)
  }
  metrics <- uefa_euro_priority_metrics()
  expected_status <- ifelse(rowSums(is.na(rows[metrics])) > 0, "unresolved", "projected")
  if (anyNA(rows$status) || any(rows$status != expected_status)) stop("EURO priority summary status mismatch", call. = FALSE)
  for (field in metrics) {
    values <- suppressWarnings(as.numeric(rows[[field]]))
    reasons <- rows[[paste0(field, "_reason")]]
    reason_present <- !is.na(reasons) & nzchar(reasons)
    if (any(!is.na(values) & !is.finite(values)) || any(is.na(values) != reason_present)) stop("EURO priority metric availability mismatch: ", field, call. = FALSE)
    upper <- if (startsWith(field, "p_")) 1 else nrow(rows)
    lower <- if (startsWith(field, "p_")) 0 else 1
    if (any(is.finite(values) & (values < lower | values > upper))) stop("EURO priority metric outside range: ", field, call. = FALSE)
  }
  lo <- suppressWarnings(as.numeric(rows$queue_position_p10)); hi <- suppressWarnings(as.numeric(rows$queue_position_p90))
  avg <- suppressWarnings(as.numeric(rows$expected_queue_position))
  if (any(is.na(lo) != is.na(avg)) || any(is.na(hi) != is.na(avg)) || any(!is.na(lo) & (!is.finite(lo) | !is.finite(hi) | lo < 1 | hi > nrow(rows) | lo > hi))) stop("EURO priority percentile range mismatch", call. = FALSE)
  group_probability <- suppressWarnings(as.numeric(rows$p_group_winner)); priority <- suppressWarnings(as.numeric(rows$p_winner_priority))
  abc <- rows$league %in% c("A", "B", "C"); d <- rows$league == "D"
  if (any(is.na(group_probability[abc]) != is.na(priority[abc])) || any(abs(group_probability[abc] - priority[abc]) > tolerance, na.rm = TRUE) ||
      any(priority[d] > group_probability[d] + tolerance, na.rm = TRUE)) stop("EURO winner priority does not reconcile", call. = FALSE)
  if (all(is.finite(group_probability))) {
    totals <- tapply(group_probability, rows$group_id, sum)
    if (any(abs(totals - 1) > tolerance)) stop("EURO group winners not conserved", call. = FALSE)
  }
  if (any(d) && all(is.finite(priority[d])) && abs(sum(priority[d]) - 1) > tolerance) stop("EURO D priority not conserved", call. = FALSE)
  for (field in c("expected_interim_rank", "expected_queue_position")) {
    values <- suppressWarnings(as.numeric(rows[[field]]))
    if (all(is.finite(values)) && abs(sum(values) - nrow(rows) * (nrow(rows) + 1) / 2) > tolerance) stop("EURO priority ranks not conserved: ", field, call. = FALSE)
  }
  invisible(TRUE)
}
