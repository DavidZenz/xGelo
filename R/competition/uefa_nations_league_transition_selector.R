# Prepared transition selection for the private simulation runtime.
# Only the current revised 54-team canonical ready ranking is supported.
uefa_nl_sim_prepare_transition_selector <- function(runtime, rules) {
  if (isTRUE(runtime$uefa_nl_transition_selector_prepared)) return(runtime)
  original <- runtime$uefa_nl_select_transition_slots
  if (!is.function(original) || !identical(rules, runtime$uefa_nl_2026_27_rules())) return(runtime)
  scope <- environment()
  parent.env(scope) <- runtime
  fixed_rules <- rules
  rules_hash <- uefa_nl_ruleset_sha256(rules)
  # This plan is already in the original final radix order: A/B pairs, B/C
  # pairs, then direct A relegations and B/C/D promotions by their lower rank.
  high_ranks <- c(11:14, 29:32, 15:16, rep(NA_integer_, 14L))
  low_ranks <- c(21:24, 37:40, rep(NA_integer_, 2L), 17:20, 33:36, 49:54)
  source_ranks <- c(11:14, 29:32, 15:16, 17:20, 33:36, 49:54)
  canonical_leagues <- c(rep("A", 16L), rep("B", 16L), rep("C", 16L), rep("D", 6L))
  canonical_positions <- c(rep(rep(1:4, each = 4L), 3L), rep(1:3, each = 2L))
  frame <- function(columns) structure(columns, class = "data.frame", row.names = c(NA_integer_, -24L))
  template <- list(
    edition_id = rep(as.character(rules$edition_id), 24L),
    stage_id = c(rep("a_b_playoff", 4L), rep("b_c_playoff", 4L), rep("direct_transition", 16L)),
    transition_type = c(rep("a_b_playoff", 4L), rep("b_c_playoff", 4L), rep("direct_relegation", 2L), rep("direct_promotion", 14L)),
    ranking_scope = rep("interim_overall", 24L),
    league = c(rep("A", 4L), rep("B", 4L), rep("A", 2L), rep("B", 4L), rep("C", 4L), rep("D", 6L)),
    higher_league = c(rep("A", 4L), rep("B", 4L), rep("A", 6L), rep("B", 4L), rep("C", 6L)),
    lower_league = c(rep("B", 4L), rep("C", 4L), rep("B", 6L), rep("C", 4L), rep("D", 6L)),
    higher_league_team_id = rep(NA_character_, 24L), lower_league_team_id = rep(NA_character_, 24L), team_id = rep(NA_character_, 24L),
    higher_league_rank = high_ranks, lower_league_rank = low_ranks, group_id = rep(NA_character_, 24L), group_position = rep(NA_integer_, 24L),
    interim_rank = source_ranks, first_leg_home_team_id = rep(NA_character_, 24L),
    eligibility_status = c(rep("eligible", 8L), rep("not_applicable", 16L)), selection_status = rep("selected", 24L),
    unresolved_reason = rep("", 24L), cd_playoff_status = rep("not_applicable", 24L), cancellation_reason = rep("", 24L),
    retained_next_edition_league = rep(NA_character_, 24L), retained_next_edition_rank = rep(NA_integer_, 24L),
    playoff_eligibility_probability = rep(NA_real_, 24L), playoff_win_probability = rep(NA_real_, 24L), playoff_loss_probability = rep(NA_real_, 24L),
    ruleset_version = rep(as.character(rules$ruleset_version), 24L), ruleset_sha256 = rep(rules_hash, 24L), row_sha256 = rep(NA_character_, 24L))
  required_types <- c(edition_id = "character", team_id = "character", league = "character", group_id = "character", group_position = "integer",
    interim_rank = "integer", computed_rank = "integer", ordering_status = "character", ranking_scope = "character",
    missing_rule_input = "character", block_status = "character", blocked = "logical", suppression_reason = "character",
    ruleset_version = "character", ruleset_sha256 = "character")
  allowed_attributes <- c("names", "row.names", "class", "trace", "tiebreak_trace")
  runtime$uefa_nl_select_transition_slots <- function(interim_rankings, euro_playoff_eligibility = NULL, rules = uefa_nl_2026_27_rules()) {
    fallback <- function() original(interim_rankings, euro_playoff_eligibility, rules)
    if (!identical(rules, fixed_rules) || !is.null(euro_playoff_eligibility) || !is.data.frame(interim_rankings) ||
        !identical(class(interim_rankings), "data.frame") || nrow(interim_rankings) != 54L ||
        any(!names(attributes(interim_rankings)) %in% allowed_attributes) || anyNA(names(interim_rankings)) ||
        anyDuplicated(names(interim_rankings)) || !all(names(required_types) %in% names(interim_rankings))) return(fallback())
    columns <- unclass(interim_rankings)
    if (!all(vapply(columns, function(column) is.null(attributes(column)) && typeof(column) %in% c("logical", "integer", "double", "character"), logical(1))) ||
        !identical(vapply(columns[names(required_types)], typeof, character(1)), required_types) ||
        any(vapply(columns[names(required_types)], anyNA, logical(1)))) return(fallback())
    ranks <- columns$interim_rank
    index <- match(1:54, ranks)
    if (anyNA(index) || anyDuplicated(columns$team_id) || any(!nzchar(columns$team_id)) ||
        any(!nzchar(columns$group_id)) || !identical(columns$computed_rank, ranks) ||
        !identical(columns$league[index], canonical_leagues) || !identical(columns$group_position[index], canonical_positions) ||
        any(columns$edition_id != fixed_rules$edition_id) || any(columns$ordering_status != "ready") ||
        any(columns$ranking_scope != "interim_overall") || any(columns$missing_rule_input != "") ||
        any(columns$block_status != "not_blocked") || any(columns$blocked) || any(columns$suppression_reason != "none") ||
        any(columns$ruleset_version != fixed_rules$ruleset_version) || any(columns$ruleset_sha256 != rules_hash)) return(fallback())
    output <- template
    source <- index[source_ranks]
    output$group_id <- columns$group_id[source]
    output$group_position <- columns$group_position[source]
    output$higher_league_team_id[1:10] <- columns$team_id[index[high_ranks[1:10]]]
    low_rows <- c(1:8, 11:24)
    output$lower_league_team_id[low_rows] <- columns$team_id[index[low_ranks[low_rows]]]
    output$team_id[9:24] <- columns$team_id[source[9:24]]
    output$first_leg_home_team_id[1:8] <- output$lower_league_team_id[1:8]
    output$transition_key <- paste(output$stage_id, output$higher_league_rank, output$lower_league_rank,
      output$higher_league_team_id, output$lower_league_team_id, sep = "::")
    output <- frame(output)
    output$row_sha256 <- uefa_nl_rules_row_sha256(output[, setdiff(names(output), "row_sha256"), drop = FALSE])
    output
  }
  runtime$uefa_nl_transition_selector_prepared <- TRUE
  runtime
}
