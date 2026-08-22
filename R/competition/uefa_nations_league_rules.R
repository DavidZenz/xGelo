#' Canonical UEFA Nations League 2026/27 rules and topology contracts.
#'
#' This module owns competition semantics and source-derived topology only. It
#' deliberately does not calculate standings; the universal Phase 14 reducer
#' remains the arithmetic seam for later ranking adapters.

uefa_nl_ruleset_version <- function() {
  "uefa-nations-league-2026-27-v2"
}

uefa_nl_edition_id <- function() {
  "uefa_nations_league_2026_27"
}

uefa_nl_source_bundle_id <- function() {
  "nl-2026-27-official-uefa-v2"
}

uefa_nl_stage_status_values <- function() {
  c("official", "projected", "unresolved", "completed", "suppressed")
}

uefa_nl_rules_project_root <- function(project_root = ".") {
  candidate <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

uefa_nl_rules_scalar <- function(value) {
  if (is.function(value)) return(paste(deparse(value), collapse = "\n"))
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

uefa_nl_rules_missing <- function(value) {
  length(value) == 0L || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))
}

uefa_nl_rules_canonical_sha256 <- function(data, key = NULL) {
  if (exists("phase13_canonical_sha256", mode = "function", inherits = TRUE)) {
    return(phase13_canonical_sha256(data, key = key))
  }
  if (!is.data.frame(data) || !ncol(data)) stop("Nations League canonical hash requires named data", call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Nations League hashes", call. = FALSE)
  if (is.null(key)) key <- names(data)[[1L]]
  key <- intersect(as.character(key), names(data))
  if (!length(key)) stop("Nations League canonical hash key is missing", call. = FALSE)
  canonical <- data[, sort(names(data)), drop = FALSE]
  if (nrow(canonical)) {
    ordering <- lapply(canonical[key], function(column) vapply(column, uefa_nl_rules_scalar, character(1)))
    canonical <- canonical[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- if (!nrow(canonical)) character() else vapply(seq_len(nrow(canonical)), function(index) {
    paste(vapply(canonical[index, , drop = FALSE], uefa_nl_rules_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  digest::digest(paste(c(paste(names(canonical), collapse = "\x1f"), rows), collapse = "\x1e"), algo = "sha256", serialize = FALSE)
}

uefa_nl_rules_row_sha256 <- function(data, hash_col = "row_sha256") {
  if (exists("phase13_row_sha256", mode = "function", inherits = TRUE)) {
    return(phase13_row_sha256(data, hash_col = hash_col))
  }
  fields <- setdiff(names(data), hash_col)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Nations League hashes", call. = FALSE)
  vapply(seq_len(nrow(data)), function(index) {
    digest::digest(
      paste(vapply(data[index, fields, drop = FALSE], uefa_nl_rules_scalar, character(1)), collapse = "|"),
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1))
}

uefa_nl_rules_source_sha256 <- function(value) {
  if (exists("phase13_source_sha256", mode = "function", inherits = TRUE)) return(phase13_source_sha256(value))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Nations League hashes", call. = FALSE)
  bytes <- if (is.raw(value)) value else charToRaw(enc2utf8(as.character(value)))
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

uefa_nl_rules_canonical_object <- function(value) {
  if (is.data.frame(value)) {
    data <- value[, sort(names(value)), drop = FALSE]
    if (nrow(data)) {
      ordering <- lapply(data, function(column) vapply(column, uefa_nl_rules_scalar, character(1)))
      data <- data[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
    }
    return(paste(
      paste(names(data), collapse = "\x1f"),
      paste(vapply(seq_len(nrow(data)), function(index) {
        paste(vapply(data[index, , drop = FALSE], uefa_nl_rules_scalar, character(1)), collapse = "\x1f")
      }, character(1)), collapse = "\x1e"),
      sep = "\x1d"
    ))
  }
  if (is.list(value)) {
    values <- value
    if (!is.null(names(values))) values <- values[sort(names(values))]
    return(paste(vapply(values, uefa_nl_rules_canonical_object, character(1)), collapse = "\x1c"))
  }
  if (length(value) > 1L) return(paste(vapply(value, uefa_nl_rules_scalar, character(1)), collapse = "\x1f"))
  uefa_nl_rules_scalar(value)
}

uefa_nl_2026_27_rules <- function() {
  ruleset_version <- uefa_nl_ruleset_version()
  list(
    edition_id = uefa_nl_edition_id(),
    ruleset_version = ruleset_version,
    league_phase = list(
      leagues = c(A = 4L, B = 4L, C = 4L, D = 2L),
      groups_per_league = c(A = 4L, B = 4L, C = 4L, D = 2L),
      allowed_group_sizes = list(A = 4L, B = 4L, C = 4L, D = 3:4),
      expected_team_counts = c(A = 16L, B = 16L, C = 16L, D = NA_integer_),
      expected_matches_per_team = c(A = 6L, B = 6L, C = 6L, D = NA_integer_),
      home_and_away = TRUE,
      fixture_count_formula = "team_count * (team_count - 1)"
    ),
    group_tiebreak = c(
      "head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals",
      "recursive_tied_subset", "overall_goal_difference", "overall_goals",
      "overall_away_goals", "wins", "away_wins", "discipline_points",
      "access_list_position"
    ),
    group_tiebreak_tokens = c(
      "head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals",
      "recursive_tied_subset", "overall_goal_difference", "overall_goals",
      "overall_away_goals", "wins", "away_wins", "discipline_points",
      "access_list_position"
    ),
    cross_group = list(
      ranking_scope = "individual_league",
      exclude_fourth_for_positions = 1:3,
      exclude_fourth_position_aware = TRUE,
      fourth_place_exclusion = "exclude_results_against_fourth_place_only_for_positions_1_to_3",
      retain_three_team_group_results = TRUE,
      derive_cardinality_from_source = TRUE
    ),
    rank_bands = list(
      A = list(min = 1L, max = 16L, access_list_min = 1L, access_list_max = 16L),
      B = list(min = 17L, max = 32L, access_list_min = 17L, access_list_max = 32L),
      C = list(min = 33L, max = 48L, access_list_min = 33L, access_list_max = 48L),
      D = list(min = 49L, max = NA_integer_, access_list_min = 49L, access_list_max = NA_integer_)
    ),
    access_list_bands = data.frame(
      league_id = c("A", "B", "C", "D"),
      access_list_min = c(1L, 17L, 33L, 49L),
      access_list_max = c(16L, 32L, 48L, NA_integer_),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    transitions = list(
      direct_promotion = list(
        B_to_A = "group_winners",
        C_to_B = "group_winners",
        D_to_C = "group_winners"
      ),
      direct_relegation = list(
        A_to_B = "fourth_place",
        B_to_C = "fourth_place",
        C_to_D = "interim_overall_ranks_47_48"
      ),
      play_offs = list(
        a_b_playoff = list(higher_league = "A", lower_league = "B", higher_ranks = 9:12, lower_ranks = 21:24),
        b_c_playoff = list(higher_league = "B", lower_league = "C", higher_ranks = 25:28, lower_ranks = 37:40),
        c_d_playoff = list(higher_league = "C", lower_league = "D", higher_ranks = 45:46, lower_ranks = 51:52)
      )
    ),
    stages = list(
      league_phase = list(
        stage_id = "league_phase", stage_type = "league_phase", legs = 2L,
        seed_policy = "none", different_group = FALSE,
        first_leg_home_policy = "published_schedule",
        tie_break_policy = "group_standings",
        cancellation_condition = "none"
      ),
      league_a_quarter_final = list(
        stage_id = "league_a_quarter_final", stage_type = "quarter_final", legs = 2L,
        seed_policy = "league_a_group_winner_seeded_against_different_group_runner_up",
        different_group = TRUE, first_leg_home_policy = "runner_up_home",
        tie_break_policy = "aggregate_extra_time_then_penalties",
        cancellation_condition = "none"
      ),
      league_a_semi_final = list(
        stage_id = "league_a_semi_final", stage_type = "semi_final", legs = 1L,
        seed_policy = "open_draw", different_group = FALSE,
        first_leg_home_policy = "designated_venue",
        tie_break_policy = "extra_time_then_penalties",
        cancellation_condition = "none"
      ),
      league_a_third_place = list(
        stage_id = "league_a_third_place", stage_type = "third_place", legs = 1L,
        seed_policy = "semi_final_losers", different_group = FALSE,
        first_leg_home_policy = "designated_venue",
        tie_break_policy = "penalties_without_extra_time",
        cancellation_condition = "none"
      ),
      league_a_final = list(
        stage_id = "league_a_final", stage_type = "final", legs = 1L,
        seed_policy = "semi_final_winners", different_group = FALSE,
        first_leg_home_policy = "designated_venue",
        tie_break_policy = "extra_time_then_penalties",
        cancellation_condition = "none"
      ),
      a_b_playoff = list(
        stage_id = "a_b_playoff", stage_type = "play_off", legs = 2L,
        seed_policy = "higher_league_seeded", different_group = FALSE,
        first_leg_home_policy = "lower_league_home",
        tie_break_policy = "aggregate_extra_time_then_penalties",
        cancellation_condition = "none"
      ),
      b_c_playoff = list(
        stage_id = "b_c_playoff", stage_type = "play_off", legs = 2L,
        seed_policy = "higher_league_seeded", different_group = FALSE,
        first_leg_home_policy = "lower_league_home",
        tie_break_policy = "aggregate_extra_time_then_penalties",
        cancellation_condition = "none"
      ),
      c_d_playoff = list(
        stage_id = "c_d_playoff", stage_type = "play_off", legs = 2L,
        seed_policy = "higher_league_seeded", different_group = FALSE,
        first_leg_home_policy = "lower_league_home",
        tie_break_policy = "aggregate_extra_time_then_penalties",
        cancellation_condition = "cancel_if_any_due_participant_qualifies_for_euro_2028_playoffs"
      )
    ),
    match_resolution = list(
      article_14 = list(
        league_phase_pairwise = TRUE,
        home_and_away = TRUE,
        reciprocal_legs = TRUE,
        one_home_leg_per_team = TRUE
      ),
      article_16 = list(
        play_off_legs = 2L,
        lower_league_first_leg_home = TRUE,
        aggregate_winner = "greater_two_leg_aggregate",
        tied_aggregate = "article_18"
      ),
      article_17 = list(
        quarter_final_legs = 2L,
        group_winners_seeded = TRUE,
        different_group = TRUE,
        runner_up_first_leg_home = TRUE,
        semi_final_single_leg = TRUE,
        team_a_ordering = "host_association_first_in_semi_final_1",
        semi_final_1_host_association_first = TRUE,
        final_team_a_source = "semi_final_1_winner",
        third_place_team_a_source = "semi_final_1_loser"
      ),
      article_18 = list(
        regulation_minutes = 90L,
        extra_time_minutes = 30L,
        aggregate_tie = "extra_time_then_penalties",
        semi_final_tie = "extra_time_then_penalties",
        final_tie = "extra_time_then_penalties",
        third_place_tie = "penalties_without_extra_time",
        shootout_tallies_separate = TRUE,
        final_goals_definition = "regulation_plus_extra_time"
      )
    ),
    source_admission = list(
      required_resource_types = c("fixtures", "groups", "standings", "results", "status"),
      stage_capture_separate = TRUE,
      stage_capture_statuses = c("official", "completed"),
      projected_status_requires = c("projection_run_id", "draw_policy_id"),
      unresolved_status_requires = "unresolved_reason",
      suppressed_status_requires = "suppression_reason",
      official_status_requires = c("source_fixture_id", "source_artifact_id"),
      fabricated_official_rows_rejected = TRUE,
      c_d_external_eligibility = "explicit_euro_playoff_eligibility_required"
    ),
    article_12 = list(
      league_phase = "four_A_four_B_four_C_groups_of_four_and_two_D_groups_of_three_or_four",
      downstream_stages = c("league_a_quarter_final", "league_a_semi_final", "league_a_third_place", "league_a_final", "a_b_playoff", "b_c_playoff", "c_d_playoff")
    ),
    article_13 = list(
      access_list_bands = c(A = "1-16", B = "17-32", C = "33-48", D = "49+"),
      seeded_group_formation = TRUE,
      absent_metadata_status = "unresolved_access_list"
    ),
    article_19 = list(
      fourth_place_exclusion_position_aware = TRUE,
      final_overall_ranking = TRUE,
      current_source_team_count = 54L,
      regulation_rank_universe_is_source_derived = TRUE
    )
  )
}

uefa_nl_stage_topology <- function(rules = uefa_nl_2026_27_rules()) {
  definitions <- rules$stages
  rows <- lapply(definitions, function(stage) {
    data.frame(
      edition_id = rules$edition_id,
      ruleset_version = rules$ruleset_version,
      stage_id = as.character(stage$stage_id),
      stage_type = as.character(stage$stage_type),
      legs = as.integer(stage$legs),
      seed_policy = as.character(stage$seed_policy),
      different_group = as.logical(stage$different_group),
      first_leg_home_policy = as.character(stage$first_leg_home_policy),
      tie_break_policy = as.character(stage$tie_break_policy),
      cancellation_condition = as.character(stage$cancellation_condition),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output <- output[order(output$stage_id, method = "radix"), , drop = FALSE]
  row.names(output) <- NULL
  output
}

uefa_nl_access_band <- function(position) {
  if (position >= 1L && position <= 16L) return("A")
  if (position >= 17L && position <= 32L) return("B")
  if (position >= 33L && position <= 48L) return("C")
  if (position >= 49L) return("D")
  NA_character_
}

uefa_nl_team_id_valid <- function(values) {
  values <- trimws(as.character(values))
  !is.na(values) & nzchar(values) & grepl("^team[-_][A-Za-z0-9._-]+$", values)
}

uefa_nl_group_label <- function(league_id, index) {
  paste0(as.character(league_id), as.integer(index))
}

uefa_nl_stage_topology_hash <- function(stage_topology) {
  uefa_nl_rules_canonical_sha256(stage_topology, key = "stage_id")
}

uefa_nl_validate_access_list <- function(
    access_list = NULL,
    teams = NULL,
    edition_id = uefa_nl_edition_id()) {
  required <- c(
    "edition_id", "team_id", "access_list_position", "league_id", "group_id",
    "draw_pot", "group_formation_status", "source_artifact_id"
  )
  if (is.null(access_list)) {
    team_rows <- if (is.data.frame(teams)) {
      teams
    } else if (is.null(teams)) {
      data.frame(team_id = character(), league_id = character(), group_id = character(), source_artifact_id = character(), stringsAsFactors = FALSE)
    } else {
      data.frame(team_id = as.character(teams), stringsAsFactors = FALSE)
    }
    if (!"team_id" %in% names(team_rows)) stop("Nations League unresolved access-list teams require team_id", call. = FALSE)
    if (!"league_id" %in% names(team_rows)) team_rows$league_id <- NA_character_
    if (!"group_id" %in% names(team_rows)) team_rows$group_id <- NA_character_
    if (!"source_artifact_id" %in% names(team_rows)) team_rows$source_artifact_id <- NA_character_
    output <- data.frame(
      edition_id = as.character(edition_id),
      team_id = as.character(team_rows$team_id),
      access_list_position = rep(NA_integer_, nrow(team_rows)),
      league_id = as.character(team_rows$league_id),
      group_id = as.character(team_rows$group_id),
      draw_pot = rep(NA_character_, nrow(team_rows)),
      group_formation_status = rep("unresolved_access_list", nrow(team_rows)),
      source_artifact_id = as.character(team_rows$source_artifact_id),
      status = rep("unresolved_access_list", nrow(team_rows)),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    if (nrow(output) && (any(!uefa_nl_team_id_valid(output$team_id)) || anyDuplicated(output$team_id))) {
      stop("Nations League unresolved access-list teams have invalid or duplicate stable team IDs", call. = FALSE)
    }
    output <- output[order(output$team_id, method = "radix"), , drop = FALSE]
    row.names(output) <- NULL
    return(list(
      status = "unresolved_access_list",
      missing_rule_input = "access_list",
      rows = output,
      access_list = output,
      access_list_position = output$access_list_position,
      draw_pot = output$draw_pot,
      group_formation_status = output$group_formation_status,
      table_sha256 = uefa_nl_rules_canonical_sha256(output, key = "team_id")
    ))
  }

  if (!is.data.frame(access_list)) stop("Nations League access list must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(access_list))
  if (length(missing)) stop("Nations League access list is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  output <- as.data.frame(access_list, stringsAsFactors = FALSE, check.names = FALSE)
  if (any(is.na(output$edition_id) | as.character(output$edition_id) != as.character(edition_id))) stop("Nations League access list has a foreign edition", call. = FALSE)
  if (!nrow(output)) stop("Nations League admitted access list must not be empty", call. = FALSE)
  output$team_id <- trimws(as.character(output$team_id))
  if (any(!uefa_nl_team_id_valid(output$team_id)) || anyDuplicated(output$team_id)) stop("Nations League access list has invalid or duplicate stable team IDs", call. = FALSE)
  positions <- suppressWarnings(as.numeric(as.character(output$access_list_position)))
  if (any(is.na(positions) | !is.finite(positions) | positions < 1 | positions != floor(positions)) || anyDuplicated(positions)) {
    stop("Nations League access list positions must be unique positive integers", call. = FALSE)
  }
  output$access_list_position <- as.integer(positions)
  output$league_id <- toupper(trimws(as.character(output$league_id)))
  if (any(!output$league_id %in% c("A", "B", "C", "D"))) stop("Nations League access list has an unknown league", call. = FALSE)
  expected_league <- vapply(output$access_list_position, uefa_nl_access_band, character(1))
  if (any(is.na(expected_league) | expected_league != output$league_id)) stop("Nations League access list position is outside its Article 13 league band", call. = FALSE)
  for (field in c("group_id", "draw_pot", "source_artifact_id")) {
    values <- trimws(as.character(output[[field]]))
    if (any(is.na(values) | !nzchar(values))) stop("Nations League access list has missing ", field, call. = FALSE)
    output[[field]] <- values
  }
  output$group_formation_status <- trimws(as.character(output$group_formation_status))
  if (any(is.na(output$group_formation_status) | !output$group_formation_status %in% c("admitted", "validated"))) {
    stop("Nations League access list has an invalid group formation status", call. = FALSE)
  }
  if ("status" %in% names(output)) {
    output$status <- trimws(as.character(output$status))
    if (any(!output$status %in% c("admitted", "validated"))) stop("Nations League access list has an invalid status", call. = FALSE)
  }
  output <- output[order(output$access_list_position, output$team_id, method = "radix"), , drop = FALSE]
  row.names(output) <- NULL
  list(
    status = "validated",
    missing_rule_input = "",
    rows = output,
    access_list = output,
    access_list_position = output$access_list_position,
    draw_pot = output$draw_pot,
    group_formation_status = rep("validated", nrow(output)),
    table_sha256 = uefa_nl_rules_canonical_sha256(output, key = "team_id")
  )
}

uefa_nl_group_key <- function(value, groups) {
  value <- as.character(value)
  candidates <- list(
    group_id = if ("group_id" %in% names(groups)) as.character(groups$group_id) else character(),
    published_group_id = if ("published_group_id" %in% names(groups)) as.character(groups$published_group_id) else character(),
    source_group_id = if ("source_group_id" %in% names(groups)) as.character(groups$source_group_id) else character(),
    display_name = if ("display_name" %in% names(groups)) as.character(groups$display_name) else character()
  )
  for (candidate in candidates) {
    positions <- which(candidate == value)
    if (!length(positions)) next
    keys <- unique(as.character(groups$group_id[positions]))
    if (length(keys) == 1L) return(keys[[1L]])
  }
  NA_character_
}

uefa_nl_validate_group_formation <- function(
    access_list,
    groups,
    group_formation_seed = 15013L,
    edition_id = uefa_nl_edition_id()) {
  if (!is.data.frame(groups) || !all(c("team_id", "league_id", "group_id", "source_artifact_id") %in% names(groups))) {
    stop("Nations League group formation requires team/group lineage rows", call. = FALSE)
  }
  seed <- suppressWarnings(as.integer(group_formation_seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("Nations League group formation seed must be one non-negative integer", call. = FALSE)
  group_rows <- as.data.frame(groups, stringsAsFactors = FALSE, check.names = FALSE)
  if (anyDuplicated(as.character(group_rows$team_id))) stop("Nations League published groups contain duplicate teams", call. = FALSE)
  if (any(!uefa_nl_team_id_valid(group_rows$team_id))) stop("Nations League published groups contain non-canonical team IDs", call. = FALSE)
  if ("edition_id" %in% names(group_rows) && any(is.na(group_rows$edition_id) | as.character(group_rows$edition_id) != as.character(edition_id))) {
    stop("Nations League published groups have a foreign edition", call. = FALSE)
  }
  for (field in c("league_id", "group_id", "source_artifact_id")) {
    values <- trimws(as.character(group_rows[[field]]))
    if (any(is.na(values) | !nzchar(values))) stop("Nations League published groups have missing ", field, call. = FALSE)
    group_rows[[field]] <- values
  }
  if (is.null(access_list) || identical(access_list$status, "unresolved_access_list")) {
    rows <- if (is.null(access_list)) {
      uefa_nl_validate_access_list(NULL, group_rows, edition_id)$rows
    } else {
      as.data.frame(access_list$rows, stringsAsFactors = FALSE, check.names = FALSE)
    }
    rows$group_formation_status <- "unresolved_access_list"
    rows$status <- "unresolved_access_list"
    rows <- rows[order(rows$team_id, method = "radix"), , drop = FALSE]
    row.names(rows) <- NULL
    return(list(
      status = "unresolved_access_list",
      missing_rule_input = "access_list",
      group_formation_status = "unresolved_access_list",
      group_formation_seed = seed,
      rows = rows,
      table_sha256 = uefa_nl_rules_canonical_sha256(rows, key = "team_id")
    ))
  }
  access_rows <- if (is.list(access_list) && !is.null(access_list$rows)) access_list$rows else access_list
  validated <- uefa_nl_validate_access_list(access_rows, edition_id = edition_id)
  access_rows <- validated$rows
  if (!setequal(as.character(access_rows$team_id), as.character(group_rows$team_id))) {
    stop("Nations League access list does not cover the published group team set exactly", call. = FALSE)
  }
  group_rows$league_id <- toupper(as.character(group_rows$league_id))
  if (any(!group_rows$league_id %in% c("A", "B", "C", "D"))) stop("Nations League published groups have an unknown league", call. = FALSE)
  access_rows$group_key <- vapply(access_rows$group_id, uefa_nl_group_key, character(1), groups = group_rows)
  if (any(is.na(access_rows$group_key))) stop("Nations League access list contains a foreign group assignment", call. = FALSE)
  group_by_team <- group_rows[match(access_rows$team_id, group_rows$team_id), , drop = FALSE]
  if (any(as.character(access_rows$league_id) != as.character(group_by_team$league_id))) stop("Nations League access list league assignment disagrees with published groups", call. = FALSE)
  if (any(as.character(access_rows$group_key) != as.character(group_by_team$group_id))) stop("Nations League access list group assignment disagrees with published groups", call. = FALSE)
  expected_band <- vapply(access_rows$access_list_position, uefa_nl_access_band, character(1))
  if (any(expected_band != access_rows$league_id)) stop("Nations League group formation has a wrong league band", call. = FALSE)
  if (anyDuplicated(paste(access_rows$group_key, access_rows$draw_pot, sep = "::"))) {
    stop("Nations League group formation assigns a draw pot more than once in a group", call. = FALSE)
  }
  access_rows$group_id <- access_rows$group_key
  access_rows$group_key <- NULL
  access_rows$group_formation_status <- "validated"
  access_rows$status <- "validated"
  access_rows <- access_rows[order(access_rows$access_list_position, access_rows$team_id, method = "radix"), , drop = FALSE]
  row.names(access_rows) <- NULL
  list(
    status = "validated",
    missing_rule_input = "",
    group_formation_status = "validated",
    group_formation_seed = seed,
    rows = access_rows,
    table_sha256 = uefa_nl_rules_canonical_sha256(access_rows, key = "team_id")
  )
}

uefa_nl_stage_slot_schema <- function() {
  c(
    "edition_id", "stage_id", "stage_type", "stage_status", "leg_number",
    "participant_slot_home", "participant_slot_away", "home_team_id", "away_team_id",
    "source_fixture_id", "source_artifact_id", "projection_run_id", "draw_policy_id",
    "scheduled_at_utc", "unresolved_reason", "suppression_reason", "ruleset_version",
    "ruleset_sha256", "row_sha256", "regulation_home_goals", "regulation_away_goals",
    "extra_time_home_goals", "extra_time_away_goals", "penalty_shootout_home_goals",
    "penalty_shootout_away_goals", "final_home_goals", "final_away_goals",
    "completed_at_utc"
  )
}

uefa_nl_stage_slot_empty <- function() {
  data.frame(
    edition_id = character(), stage_id = character(), stage_type = character(), stage_status = character(),
    leg_number = integer(), participant_slot_home = character(), participant_slot_away = character(),
    home_team_id = character(), away_team_id = character(), source_fixture_id = character(),
    source_artifact_id = character(), projection_run_id = character(), draw_policy_id = character(),
    scheduled_at_utc = character(), unresolved_reason = character(), suppression_reason = character(),
    ruleset_version = character(), ruleset_sha256 = character(), row_sha256 = character(),
    regulation_home_goals = integer(), regulation_away_goals = integer(),
    extra_time_home_goals = integer(), extra_time_away_goals = integer(),
    penalty_shootout_home_goals = integer(), penalty_shootout_away_goals = integer(),
    final_home_goals = integer(), final_away_goals = integer(), completed_at_utc = character(),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_nl_stage_slot_value_missing <- function(values) {
  is.na(values) | !nzchar(trimws(as.character(values)))
}

uefa_nl_stage_slot_score <- function(values, field, allow_missing = TRUE) {
  numeric_values <- suppressWarnings(as.numeric(as.character(values)))
  present <- !is.na(values) & nzchar(trimws(as.character(values)))
  invalid <- present & (is.na(numeric_values) | !is.finite(numeric_values) | numeric_values < 0 | numeric_values != floor(numeric_values))
  if (any(invalid)) stop("Nations League stage slot ", field, " must contain non-negative integers", call. = FALSE)
  if (!allow_missing && any(!present)) stop("Nations League stage slot ", field, " is required", call. = FALSE)
  output <- rep(NA_integer_, length(numeric_values))
  output[present] <- as.integer(numeric_values[present])
  output
}

uefa_nl_validate_stage_slots <- function(slots, edition_id = uefa_nl_edition_id(), ruleset_sha256 = NULL) {
  if (!is.data.frame(slots)) stop("Nations League stage slots must be a data frame", call. = FALSE)
  required <- uefa_nl_stage_slot_schema()
  missing <- setdiff(required, names(slots))
  if (length(missing)) stop("Nations League stage slots are missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(slots)) return(invisible(TRUE))
  ruleset_sha256 <- ruleset_sha256 %||% uefa_nl_ruleset_sha256()
  values <- as.data.frame(slots, stringsAsFactors = FALSE, check.names = FALSE)
  if (any(is.na(values$edition_id) | as.character(values$edition_id) != as.character(edition_id))) stop("Nations League stage slots contain a foreign edition", call. = FALSE)
  if (any(is.na(values$stage_id) | !as.character(values$stage_id) %in% uefa_nl_stage_topology()$stage_id)) stop("Nations League stage slots contain an unknown stage", call. = FALSE)
  status <- tolower(trimws(as.character(values$stage_status)))
  if (any(is.na(status) | !status %in% uefa_nl_stage_status_values())) stop("Nations League stage slots contain an unsupported status", call. = FALSE)
  expected_types <- uefa_nl_stage_topology()$stage_type[match(as.character(values$stage_id), uefa_nl_stage_topology()$stage_id)]
  if (any(is.na(values$stage_type) | as.character(values$stage_type) != expected_types)) stop("Nations League stage slots have a stage type mismatch", call. = FALSE)
  legs <- suppressWarnings(as.numeric(as.character(values$leg_number)))
  if (any(is.na(legs) | legs < 1 | legs != floor(legs))) stop("Nations League stage slots require positive integer leg numbers", call. = FALSE)
  max_legs <- uefa_nl_stage_topology()$legs[match(as.character(values$stage_id), uefa_nl_stage_topology()$stage_id)]
  if (any(legs > max_legs)) stop("Nations League stage slots contain an invalid leg number", call. = FALSE)
  if (anyDuplicated(paste(values$stage_id, legs, values$participant_slot_home, values$participant_slot_away, sep = "::"))) {
    stop("Nations League stage slots contain duplicate participant slots", call. = FALSE)
  }
  if (any(is.na(values$ruleset_version) | as.character(values$ruleset_version) != uefa_nl_ruleset_version())) stop("Nations League stage slots have a ruleset version mismatch", call. = FALSE)
  if (any(is.na(values$ruleset_sha256) | tolower(as.character(values$ruleset_sha256)) != tolower(as.character(ruleset_sha256)))) stop("Nations League stage slots have a ruleset hash mismatch", call. = FALSE)
  if (any(is.na(values$row_sha256) | !grepl("^[0-9a-fA-F]{64}$", as.character(values$row_sha256)))) stop("Nations League stage slots require canonical row hashes", call. = FALSE)
  expected_row_hashes <- uefa_nl_rules_row_sha256(values)
  if (any(tolower(as.character(values$row_sha256)) != tolower(expected_row_hashes))) stop("Nations League stage slot row hash mismatch", call. = FALSE)
  source_status <- status %in% c("official", "completed")
  if (any(source_status & (uefa_nl_stage_slot_value_missing(values$source_fixture_id) | uefa_nl_stage_slot_value_missing(values$source_artifact_id)))) {
    stop("Official or completed Nations League stage slots require source fixture and artifact lineage", call. = FALSE)
  }
  projected <- status == "projected"
  if (any(projected & (uefa_nl_stage_slot_value_missing(values$projection_run_id) | uefa_nl_stage_slot_value_missing(values$draw_policy_id)))) {
    stop("Projected Nations League stage slots require projection_run_id and draw_policy_id", call. = FALSE)
  }
  if (any(projected & (!uefa_nl_stage_slot_value_missing(values$source_fixture_id) | !uefa_nl_stage_slot_value_missing(values$source_artifact_id)))) {
    stop("Projected Nations League stage slots must not carry official source lineage", call. = FALSE)
  }
  unresolved <- status == "unresolved"
  if (any(unresolved & uefa_nl_stage_slot_value_missing(values$unresolved_reason))) stop("Unresolved Nations League stage slots require unresolved_reason", call. = FALSE)
  suppressed <- status == "suppressed"
  if (any(suppressed & uefa_nl_stage_slot_value_missing(values$suppression_reason))) stop("Suppressed Nations League stage slots require suppression_reason", call. = FALSE)
  completed <- status == "completed"
  score_fields <- c(
    "regulation_home_goals", "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals",
    "final_home_goals", "final_away_goals"
  )
  scores <- lapply(score_fields, function(field) uefa_nl_stage_slot_score(values[[field]], field, allow_missing = TRUE))
  names(scores) <- score_fields
  if (any(completed)) {
    if (any(uefa_nl_stage_slot_value_missing(values$completed_at_utc[completed]))) stop("Completed Nations League stage slots require completed_at_utc", call. = FALSE)
    for (field in score_fields) if (any(is.na(scores[[field]][completed]))) stop("Completed Nations League stage slots require ", field, call. = FALSE)
    if (any(scores$final_home_goals[completed] != scores$regulation_home_goals[completed] + scores$extra_time_home_goals[completed]) ||
        any(scores$final_away_goals[completed] != scores$regulation_away_goals[completed] + scores$extra_time_away_goals[completed])) {
      stop("Nations League final goals must equal regulation plus extra-time goals", call. = FALSE)
    }
  }
  if (any(!completed & !uefa_nl_stage_slot_value_missing(values$completed_at_utc))) stop("Non-completed Nations League stage slots must not carry completed_at_utc", call. = FALSE)
  for (field in score_fields) if (any(!completed & !uefa_nl_stage_slot_value_missing(values[[field]]))) stop("Non-completed Nations League stage slots must not carry ", field, call. = FALSE)
  shootout_home <- uefa_nl_stage_slot_score(values$penalty_shootout_home_goals, "penalty_shootout_home_goals")
  shootout_away <- uefa_nl_stage_slot_score(values$penalty_shootout_away_goals, "penalty_shootout_away_goals")
  shootout_present <- !is.na(shootout_home) | !is.na(shootout_away)
  if (any(xor(is.na(shootout_home), is.na(shootout_away)))) stop("Nations League shootout tallies must be supplied as a pair", call. = FALSE)
  if (any(shootout_present & (!completed | scores$final_home_goals != scores$final_away_goals))) stop("Nations League shootout tallies are only valid for tied completed scores", call. = FALSE)
  invisible(TRUE)
}

uefa_nl_build_topology <- function(
    groups = NULL,
    fixtures = NULL,
    access_list = NULL,
    group_formation_seed = 15013L,
    project_root = ".") {
  root <- uefa_nl_rules_project_root(project_root)
  default_source <- is.null(groups) && is.null(fixtures)
  groups <- groups %||% utils::read.csv(
    file.path(root, "data/competition/accepted/uefa_nations_league_2026_27/groups.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  fixtures <- fixtures %||% utils::read.csv(
    file.path(root, "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  if (!is.data.frame(groups) || !is.data.frame(fixtures)) stop("Nations League topology inputs must be data frames", call. = FALSE)
  if (!nrow(groups) || !nrow(fixtures)) stop("Nations League topology inputs must not be empty", call. = FALSE)
  group_key_field <- if ("source_group_id" %in% names(groups)) "source_group_id" else if ("group_id" %in% names(groups)) "group_id" else stop("Nations League groups require source_group_id or group_id", call. = FALSE)
  fixture_group_field <- if ("group_id" %in% names(fixtures)) "group_id" else if ("source_group_id" %in% names(fixtures)) "source_group_id" else stop("Nations League fixtures require group_id or source_group_id", call. = FALSE)
  required_group <- c("league", "edition_id", "source_artifact_id")
  missing_group <- setdiff(required_group, names(groups))
  if (length(missing_group)) stop("Nations League groups are missing columns: ", paste(missing_group, collapse = ", "), call. = FALSE)
  required_fixture <- c("edition_id", "home_team_id", "away_team_id", "source_artifact_id")
  missing_fixture <- setdiff(required_fixture, names(fixtures))
  if (length(missing_fixture)) stop("Nations League fixtures are missing columns: ", paste(missing_fixture, collapse = ", "), call. = FALSE)
  edition_values <- unique(c(as.character(groups$edition_id), as.character(fixtures$edition_id)))
  if (length(edition_values) != 1L || !identical(edition_values[[1L]], uefa_nl_edition_id())) stop("Nations League topology has a foreign edition", call. = FALSE)
  group_ids <- as.character(groups[[group_key_field]])
  if (any(is.na(group_ids) | !nzchar(trimws(group_ids))) || anyDuplicated(group_ids)) stop("Nations League groups require unique IDs", call. = FALSE)
  group_league <- toupper(trimws(as.character(groups$league)))
  if (any(!group_league %in% c("A", "B", "C", "D"))) stop("Nations League groups contain an unknown league", call. = FALSE)
  group_order <- order(group_league, group_ids, method = "radix")
  groups <- groups[group_order, , drop = FALSE]
  row.names(groups) <- NULL
  group_ids <- as.character(groups[[group_key_field]])
  group_league <- toupper(trimws(as.character(groups$league)))
  expected_group_counts <- c(A = 4L, B = 4L, C = 4L, D = 2L)
  if (!identical(as.integer(table(factor(group_league, levels = names(expected_group_counts)))), unname(expected_group_counts))) {
    stop("Nations League topology must contain four A/B/C groups and two D groups", call. = FALSE)
  }
  league_indices <- ave(seq_along(group_ids), group_league, FUN = seq_along)
  published_group_id <- if ("group_id" %in% names(groups) && !identical(group_key_field, "group_id")) as.character(groups$group_id) else {
    vapply(seq_along(group_ids), function(index) uefa_nl_group_label(group_league[[index]], league_indices[[index]]), character(1))
  }
  display_name <- if ("display_name" %in% names(groups)) as.character(groups$display_name) else paste("Group", published_group_id)
  source_bundle_values <- if ("source_bundle_id" %in% names(groups)) as.character(groups$source_bundle_id) else uefa_nl_source_bundle_id()
  source_bundle_values[is.na(source_bundle_values) | !nzchar(source_bundle_values)] <- uefa_nl_source_bundle_id()
  group_table <- data.frame(
    edition_id = uefa_nl_edition_id(),
    league_id = group_league,
    league = group_league,
    group_id = group_ids,
    published_group_id = published_group_id,
    source_group_id = group_ids,
    display_name = display_name,
    source_bundle_id = source_bundle_values,
    source_artifact_id = as.character(groups$source_artifact_id),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (any(uefa_nl_stage_slot_value_missing(group_table$source_artifact_id))) stop("Nations League group source-artifact lineage is incomplete", call. = FALSE)
  fixture_group_ids <- as.character(fixtures[[fixture_group_field]])
  if (any(!fixture_group_ids %in% group_ids)) stop("Nations League fixture contains a foreign group", call. = FALSE)
  fixture_id_field <- intersect(c("source_fixture_id", "uefa_source_fixture_id", "fixture_id"), names(fixtures))[[1L]]
  fixture_id <- as.character(fixtures[[fixture_id_field]])
  if (any(is.na(fixture_id) | !nzchar(fixture_id)) || anyDuplicated(fixture_id)) stop("Nations League fixtures require unique source IDs", call. = FALSE)
  home_team <- trimws(as.character(fixtures$home_team_id))
  away_team <- trimws(as.character(fixtures$away_team_id))
  if (any(!uefa_nl_team_id_valid(home_team)) || any(!uefa_nl_team_id_valid(away_team)) || any(home_team == away_team)) stop("Nations League fixtures contain invalid team IDs", call. = FALSE)
  fixture_bundle_values <- if ("source_bundle_id" %in% names(fixtures)) as.character(fixtures$source_bundle_id) else uefa_nl_source_bundle_id()
  fixture_bundle_values[is.na(fixture_bundle_values) | !nzchar(fixture_bundle_values)] <- uefa_nl_source_bundle_id()
  scheduled <- if ("scheduled_at_utc" %in% names(fixtures)) as.character(fixtures$scheduled_at_utc) else rep("", nrow(fixtures))
  fixture_table <- data.frame(
    edition_id = uefa_nl_edition_id(),
    source_bundle_id = fixture_bundle_values,
    stage_id = "league_phase",
    stage_type = "league_phase",
    group_id = fixture_group_ids,
    source_group_id = fixture_group_ids,
    source_fixture_id = fixture_id,
    fixture_id = if ("fixture_id" %in% names(fixtures)) as.character(fixtures$fixture_id) else fixture_id,
    home_team_id = home_team,
    away_team_id = away_team,
    scheduled_at_utc = scheduled,
    source_status = if ("source_status" %in% names(fixtures)) as.character(fixtures$source_status) else "UPCOMING",
    source_artifact_id = as.character(fixtures$source_artifact_id),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (any(uefa_nl_stage_slot_value_missing(fixture_table$source_artifact_id))) stop("Nations League fixture source-artifact lineage is incomplete", call. = FALSE)
  fixture_table$leg_number <- NA_integer_
  pair_key <- paste(fixture_table$group_id, pmin(fixture_table$home_team_id, fixture_table$away_team_id), pmax(fixture_table$home_team_id, fixture_table$away_team_id), sep = "::")
  for (key in unique(pair_key)) {
    indexes <- which(pair_key == key)
    if (length(indexes) != 2L || length(unique(fixture_table$home_team_id[indexes])) != 2L || length(unique(fixture_table$away_team_id[indexes])) != 2L) {
      stop("Nations League league-phase fixtures must contain reciprocal home-and-away pairs", call. = FALSE)
    }
    order_index <- indexes[order(fixture_table$scheduled_at_utc[indexes], fixture_table$source_fixture_id[indexes], method = "radix")]
    fixture_table$leg_number[order_index] <- seq_along(order_index)
  }
  group_team_rows <- lapply(seq_len(nrow(group_table)), function(index) {
    group_id <- group_table$group_id[[index]]
    team_ids <- sort(unique(c(
      fixture_table$home_team_id[fixture_table$group_id == group_id],
      fixture_table$away_team_id[fixture_table$group_id == group_id]
    )), method = "radix")
    data.frame(
      edition_id = uefa_nl_edition_id(),
      source_bundle_id = group_table$source_bundle_id[[index]],
      league_id = group_table$league_id[[index]],
      league = group_table$league[[index]],
      group_id = group_id,
      published_group_id = group_table$published_group_id[[index]],
      source_group_id = group_table$source_group_id[[index]],
      team_id = team_ids,
      source_artifact_id = group_table$source_artifact_id[[index]],
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  team_table <- do.call(rbind, group_team_rows)
  row.names(team_table) <- NULL
  if (anyDuplicated(team_table$team_id)) stop("Nations League teams must belong to one published group", call. = FALSE)
  group_sizes <- table(factor(team_table$group_id, levels = group_table$group_id))
  for (index in seq_len(nrow(group_table))) {
    league <- group_table$league_id[[index]]
    size <- as.integer(group_sizes[[index]])
    allowed <- if (league == "D") 3:4 else 4L
    if (!size %in% allowed) stop("Nations League group has an invalid team count", call. = FALSE)
    expected_fixtures <- size * (size - 1L)
    observed_fixtures <- sum(fixture_table$group_id == group_table$group_id[[index]])
    if (observed_fixtures != expected_fixtures) stop("Nations League group fixture count does not match its team cardinality", call. = FALSE)
  }
  if (default_source && (nrow(group_table) != 14L || nrow(fixture_table) != 156L || nrow(team_table) != 54L)) {
    stop("Current official Nations League bundle must contain 14 groups, 156 fixtures, and 54 teams", call. = FALSE)
  }
  group_table <- group_table[order(group_table$league_id, group_table$published_group_id, group_table$group_id, method = "radix"), , drop = FALSE]
  team_table <- team_table[order(team_table$league_id, team_table$published_group_id, team_table$team_id, method = "radix"), , drop = FALSE]
  fixture_table <- fixture_table[order(fixture_table$group_id, fixture_table$scheduled_at_utc, fixture_table$source_fixture_id, method = "radix"), , drop = FALSE]
  row.names(group_table) <- row.names(team_table) <- row.names(fixture_table) <- NULL
  access_result <- uefa_nl_validate_access_list(access_list, team_table, uefa_nl_edition_id())
  formation_result <- uefa_nl_validate_group_formation(access_result, team_table, group_formation_seed, uefa_nl_edition_id())
  access_rows <- formation_result$rows
  access_match <- match(team_table$team_id, access_rows$team_id)
  team_table$access_list_position <- as.integer(access_rows$access_list_position[access_match])
  team_table$draw_pot <- as.character(access_rows$draw_pot[access_match])
  team_table$group_formation_status <- as.character(access_rows$group_formation_status[access_match])
  team_table$group_formation_seed <- as.integer(group_formation_seed)
  team_table$row_sha256 <- uefa_nl_rules_row_sha256(team_table)
  fixture_table$row_sha256 <- uefa_nl_rules_row_sha256(fixture_table)
  stage_topology <- uefa_nl_stage_topology()
  rules <- uefa_nl_2026_27_rules()
  rules_hash <- uefa_nl_ruleset_sha256(rules)
  stage_hash <- uefa_nl_stage_topology_hash(stage_topology)
  topology_body <- list(groups = group_table, teams = team_table, fixtures = fixture_table, stages = stage_topology, group_formation_seed = as.integer(group_formation_seed), access_list_status = access_result$status)
  topology_hash <- uefa_nl_ruleset_sha256(topology_body)
  list(
    edition_id = uefa_nl_edition_id(),
    ruleset_version = uefa_nl_ruleset_version(),
    rules = rules,
    ruleset_sha256 = rules_hash,
    stage_topology = stage_topology,
    stages = stage_topology,
    stage_topology_sha256 = stage_hash,
    topology_sha256 = topology_hash,
    groups = group_table,
    teams = team_table,
    fixtures = fixture_table,
    topology = stage_topology,
    group_count = as.integer(nrow(group_table)),
    fixture_count = as.integer(nrow(fixture_table)),
    team_count = as.integer(nrow(team_table)),
    official_counts = c(groups = nrow(group_table), fixtures = nrow(fixture_table), teams = nrow(team_table)),
    source_bundle_id = uefa_nl_source_bundle_id(),
    source_artifact_ids = sort(unique(c(as.character(group_table$source_artifact_id), as.character(fixture_table$source_artifact_id))), method = "radix"),
    access_list = access_rows,
    access_list_status = access_result$status,
    missing_rule_input = access_result$missing_rule_input,
    group_formation = formation_result,
    group_formation_status = formation_result$group_formation_status,
    group_formation_seed = as.integer(group_formation_seed),
    stage_slots = uefa_nl_stage_slot_empty()
  )
}

uefa_nl_ruleset_sha256 <- function(rules = uefa_nl_2026_27_rules(), topology = NULL) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Nations League ruleset hashes", call. = FALSE)
  value <- if (is.null(topology)) rules else list(rules = rules, topology = topology)
  digest::digest(uefa_nl_rules_canonical_object(value), algo = "sha256", serialize = FALSE)
}

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

uefa_nl_rank_rules <- function(rules = NULL) {
  rules <- rules %||% uefa_nl_2026_27_rules()
  if (!is.list(rules) || is.null(rules$ruleset_version)) {
    stop("Nations League ranking rules must be a validated ruleset", call. = FALSE)
  }
  rules
}

# Article 15/19 ranking lives behind the Phase 14 universal standings seam.
# These helpers deliberately keep score arithmetic local to the criteria that
# UEFA defines beyond the universal snapshot (head-to-head and away metrics).

uefa_nl_rank_table_scalar <- function(value) {
  if (!length(value) || is.na(value[[1L]])) return(NA_character_)
  trimws(as.character(value[[1L]]))
}

uefa_nl_rank_input_table <- function(value, team_ids, value_field, context) {
  if (is.list(value) && !is.null(value$rows)) value <- value$rows
  if (is.null(value)) {
    return(list(values = setNames(rep(NA_real_, length(team_ids)), team_ids), missing = value_field, rows = NULL))
  }
  if (is.data.frame(value)) {
    team_candidates <- intersect(c("team_id", "canonical_team_id", "id"), names(value))
    if (!length(team_candidates) || !value_field %in% names(value)) {
      return(list(values = setNames(rep(NA_real_, length(team_ids)), team_ids), missing = value_field, rows = value))
    }
    input_team_ids <- trimws(as.character(value[[team_candidates[[1L]]]]))
    if (any(is.na(input_team_ids) | !nzchar(input_team_ids)) || anyDuplicated(input_team_ids)) {
      stop("Nations League ", context, " has missing or duplicate team IDs", call. = FALSE)
    }
    numeric_values <- suppressWarnings(as.numeric(as.character(value[[value_field]])))
    present <- !is.na(value[[value_field]]) & nzchar(trimws(as.character(value[[value_field]])))
    invalid <- present & (is.na(numeric_values) | !is.finite(numeric_values) | numeric_values != floor(numeric_values) | numeric_values < 0)
    if (any(invalid)) stop("Nations League ", context, " has invalid ", value_field, call. = FALSE)
    output <- setNames(rep(NA_real_, length(team_ids)), team_ids)
    positions <- match(input_team_ids, team_ids)
    output[positions[!is.na(positions)]] <- numeric_values[!is.na(positions)]
    missing_teams <- team_ids[is.na(output)]
    return(list(values = output, missing = if (length(missing_teams)) value_field else character(), rows = value))
  }
  if (is.atomic(value) && !is.null(names(value))) {
    numeric_values <- suppressWarnings(as.numeric(as.character(value)))
    present <- !is.na(value) & nzchar(trimws(as.character(value)))
    invalid <- present & (is.na(numeric_values) | !is.finite(numeric_values) | numeric_values != floor(numeric_values) | numeric_values < 0)
    if (any(invalid)) stop("Nations League ", context, " has invalid ", value_field, call. = FALSE)
    output <- setNames(rep(NA_real_, length(team_ids)), team_ids)
    positions <- match(names(value), team_ids)
    output[positions[!is.na(positions)]] <- numeric_values[!is.na(positions)]
    return(list(values = output, missing = if (anyNA(output)) value_field else character(), rows = NULL))
  }
  stop("Nations League ", context, " must be a keyed data frame or named vector", call. = FALSE)
}

uefa_nl_rank_match_ids <- function(rows) {
  if (!is.data.frame(rows) || !nrow(rows)) return(character())
  fields <- intersect(c("match_id", "fixture_id", "source_fixture_id", "source_match_id"), names(rows))
  if (!length(fields)) return(character())
  field <- fields[[1L]]
  values <- trimws(as.character(rows[[field]]))
  sort(unique(values[!is.na(values) & nzchar(values)]), method = "radix")
}

uefa_nl_rank_match_id <- function(rows) {
  fields <- intersect(c("match_id", "fixture_id", "source_fixture_id", "source_match_id"), names(rows))
  if (!length(fields)) stop("Nations League ranking matches require a canonical match ID", call. = FALSE)
  field <- fields[[1L]]
  values <- trimws(as.character(rows[[field]]))
  if (any(is.na(values) | !nzchar(values)) || anyDuplicated(values)) {
    stop("Nations League ranking matches require unique canonical match IDs", call. = FALSE)
  }
  values
}

uefa_nl_rank_completed_status <- function(values) {
  if (is.null(values)) return(rep(TRUE, 0L))
  tolower(trimws(as.character(values))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

uefa_nl_rank_prepare_matches <- function(match_rows, team_ids, standings) {
  if (is.null(match_rows)) match_rows <- data.frame(stringsAsFactors = FALSE)
  if (!is.data.frame(match_rows)) stop("Nations League ranking matches must be a data frame", call. = FALSE)
  if (!nrow(match_rows)) return(list(rows = match_rows, eligible = logical(), missing = character(), match_id = character()))
  required <- c("home_team_id", "away_team_id")
  missing_columns <- setdiff(required, names(match_rows))
  if (length(missing_columns)) stop("Nations League ranking matches are missing columns: ", paste(missing_columns, collapse = ", "), call. = FALSE)
  rows <- as.data.frame(match_rows, stringsAsFactors = FALSE, check.names = FALSE)
  rows$home_team_id <- trimws(as.character(rows$home_team_id))
  rows$away_team_id <- trimws(as.character(rows$away_team_id))
  if (any(is.na(rows$home_team_id) | is.na(rows$away_team_id) | rows$home_team_id == rows$away_team_id)) {
    stop("Nations League ranking matches contain invalid team pairs", call. = FALSE)
  }
  rows$match_id <- uefa_nl_rank_match_id(rows)
  if (!"final_home_goals" %in% names(rows) && "home_goals" %in% names(rows)) rows$final_home_goals <- rows$home_goals
  if (!"final_away_goals" %in% names(rows) && "away_goals" %in% names(rows)) rows$final_away_goals <- rows$away_goals
  score_missing <- setdiff(c("final_home_goals", "final_away_goals"), names(rows))
  if (length(score_missing)) return(list(rows = rows, eligible = rep(FALSE, nrow(rows)), missing = "completed_scores", match_id = rows$match_id))
  home_goals <- suppressWarnings(as.numeric(as.character(rows$final_home_goals)))
  away_goals <- suppressWarnings(as.numeric(as.character(rows$final_away_goals)))
  score_present <- !is.na(home_goals) & !is.na(away_goals)
  invalid_scores <- score_present & (!is.finite(home_goals) | !is.finite(away_goals) | home_goals < 0 | away_goals < 0 | home_goals != floor(home_goals) | away_goals != floor(away_goals))
  if (any(invalid_scores)) stop("Nations League ranking matches have invalid final scores", call. = FALSE)
  rows$final_home_goals <- as.integer(home_goals)
  rows$final_away_goals <- as.integer(away_goals)
  counts <- if ("counts_for_standings" %in% names(rows)) {
    values <- rows$counts_for_standings
    if (!is.logical(values)) values <- tolower(trimws(as.character(values))) %in% c("true", "t", "1", "yes", "y")
    as.logical(values)
  } else rep(TRUE, nrow(rows))
  status <- if ("match_status" %in% names(rows)) uefa_nl_rank_completed_status(rows$match_status) else rep(TRUE, nrow(rows))
  eligible <- counts & status & score_present
  missing_inputs <- character()
  if (any(counts & status & !score_present)) missing_inputs <- c(missing_inputs, "completed_scores")
  evidence_fields <- intersect(c("evidence_completed_at_utc", "completed_at_utc"), names(rows))
  evidence_field <- if (length(evidence_fields)) evidence_fields[[1L]] else NULL
  if (!is.null(evidence_field)) {
    evidence <- suppressWarnings(as.POSIXct(as.character(rows[[evidence_field]]), tz = "UTC"))
    missing_evidence <- counts & status & score_present & is.na(evidence)
    if (any(missing_evidence)) missing_inputs <- c(missing_inputs, "evidence_completed_at_utc")
    eligible <- eligible & !is.na(evidence)
    cutoff <- if ("state_cutoff_utc" %in% names(standings)) suppressWarnings(as.POSIXct(as.character(standings$state_cutoff_utc[[1L]]), tz = "UTC")) else as.POSIXct(NA, tz = "UTC")
    if (!is.na(cutoff[[1L]])) eligible <- eligible & evidence <= cutoff[[1L]]
  }
  if ("group_id" %in% names(rows) && "group_id" %in% names(standings)) {
    group_id <- as.character(standings$group_id[[1L]])
    foreign_group <- !is.na(rows$group_id) & nzchar(as.character(rows$group_id)) & as.character(rows$group_id) != group_id
    eligible[foreign_group] <- FALSE
  }
  foreign_team <- !rows$home_team_id %in% team_ids | !rows$away_team_id %in% team_ids
  eligible[foreign_team] <- FALSE
  list(rows = rows, eligible = eligible, missing = unique(missing_inputs), match_id = rows$match_id)
}

uefa_nl_rank_metrics_from_matches <- function(rows, eligible, team_ids) {
  if (!is.data.frame(rows) || !nrow(rows)) {
    return(data.frame(team_id = as.character(team_ids), points = 0, goal_difference = 0, goals_for = 0, away_goals = 0, wins = 0, away_wins = 0, stringsAsFactors = FALSE, check.names = FALSE))
  }
  rows <- rows[as.logical(eligible), , drop = FALSE]
  result <- lapply(as.character(team_ids), function(team_id) {
    home <- rows$home_team_id == team_id
    away <- rows$away_team_id == team_id
    gf <- c(rows$final_home_goals[home], rows$final_away_goals[away])
    ga <- c(rows$final_away_goals[home], rows$final_home_goals[away])
    data.frame(
      team_id = team_id,
      points = as.integer(3L * sum(gf > ga) + sum(gf == ga)),
      goal_difference = as.integer(sum(gf) - sum(ga)),
      goals_for = as.integer(sum(gf)),
      away_goals = as.integer(sum(rows$final_away_goals[away])),
      wins = as.integer(sum(gf > ga)),
      away_wins = as.integer(sum(rows$final_away_goals[away] > rows$final_home_goals[away])),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  do.call(rbind, result)
}

uefa_nl_rank_group_metric_groups <- function(ids, values, decreasing = TRUE) {
  values <- as.numeric(values)
  unique_values <- sort(unique(values[!is.na(values)]), decreasing = decreasing, method = "radix")
  lapply(unique_values, function(value) ids[values == value])
}

uefa_nl_group_tiebreak_trace <- function(
    group_id = NA_character_, league = NA_character_, criterion = character(),
    tied_subset = character(), counted_match_ids = character(), decision = character(),
    recursion_depth = 0L, remaining_tied_subset = character(), rules = uefa_nl_2026_27_rules()) {
  n <- max(length(criterion), length(tied_subset), length(counted_match_ids), length(decision), 1L)
  collapse_ids <- function(value) {
    if (is.list(value)) value <- value[[1L]]
    value <- sort(unique(as.character(value)[!is.na(value) & nzchar(as.character(value))]), method = "radix")
    paste(value, collapse = ";")
  }
  data.frame(
    ranking_scope = rep("group", n),
    league = rep(uefa_nl_rank_table_scalar(league), n),
    group_id = rep(uefa_nl_rank_table_scalar(group_id), n),
    criterion = rep(as.character(criterion), length.out = n),
    tied_subset = vapply(seq_len(n), function(index) collapse_ids(if (length(tied_subset)) tied_subset[[min(index, length(tied_subset))]] else character()), character(1)),
    counted_match_ids = vapply(seq_len(n), function(index) collapse_ids(if (length(counted_match_ids)) counted_match_ids[[min(index, length(counted_match_ids))]] else character()), character(1)),
    decision = rep(as.character(decision), length.out = n),
    recursion_depth = as.integer(rep(recursion_depth, length.out = n)),
    remaining_tied_subset = vapply(seq_len(n), function(index) collapse_ids(if (length(remaining_tied_subset)) remaining_tied_subset[[min(index, length(remaining_tied_subset))]] else character()), character(1)),
    ruleset_version = rep(as.character(rules$ruleset_version), n),
    ruleset_sha256 = rep(uefa_nl_ruleset_sha256(rules), n),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_nl_rank_finalize <- function(data, rules) {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  data$row_sha256 <- NULL
  data$table_sha256 <- NULL
  data$row_sha256 <- uefa_nl_rules_row_sha256(data)
  key <- intersect(c("ranking_scope", "league", "group_id", "interim_rank", "computed_rank", "team_id"), names(data))
  if (!length(key)) key <- names(data)[[1L]]
  data$table_sha256 <- rep(uefa_nl_rules_canonical_sha256(data, key = key), nrow(data))
  row.names(data) <- NULL
  data
}

uefa_nl_rank_add_columns <- function(data, rules, ranking_scope = "group") {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"league_id" %in% names(data) && "league" %in% names(data)) data$league_id <- as.character(data$league)
  if (!"league" %in% names(data) && "league_id" %in% names(data)) data$league <- as.character(data$league_id)
  if (!"group_id" %in% names(data)) data$group_id <- NA_character_
  if (!"team_id" %in% names(data)) data$team_id <- character(nrow(data))
  data$ranking_scope <- ranking_scope
  if (!"group_position" %in% names(data)) data$group_position <- NA_integer_
  if (!"computed_rank" %in% names(data)) data$computed_rank <- NA_integer_
  if (!"interim_rank" %in% names(data)) data$interim_rank <- NA_integer_
  if (!"counted_match_ids" %in% names(data)) data$counted_match_ids <- ""
  if (!"excluded_match_ids" %in% names(data)) data$excluded_match_ids <- ""
  if (!"discipline_points" %in% names(data)) data$discipline_points <- NA_integer_
  if (!"access_list_position" %in% names(data)) data$access_list_position <- NA_integer_
  if (!"ordering_status" %in% names(data)) data$ordering_status <- "ready"
  if (!"missing_rule_input" %in% names(data)) data$missing_rule_input <- ""
  if (!"suppression_reason" %in% names(data)) data$suppression_reason <- "none"
  if (!"block_status" %in% names(data)) data$block_status <- "not_blocked"
  if (!"blocked" %in% names(data)) data$blocked <- FALSE
  if (!"source_artifact_id" %in% names(data)) data$source_artifact_id <- ""
  if (!"source_bundle_id" %in% names(data)) data$source_bundle_id <- uefa_nl_source_bundle_id()
  if (!"ruleset_version" %in% names(data)) data$ruleset_version <- rules$ruleset_version
  if (!"ruleset_sha256" %in% names(data)) data$ruleset_sha256 <- uefa_nl_ruleset_sha256(rules)
  data$computed_rank <- as.integer(data$computed_rank)
  data$interim_rank <- as.integer(data$interim_rank)
  data$group_position <- as.integer(data$group_position)
  data$discipline_points <- suppressWarnings(as.integer(data$discipline_points))
  data$access_list_position <- suppressWarnings(as.integer(data$access_list_position))
  data
}

uefa_nl_rank_preflight <- function(standings, match_rows, discipline_points, access_list, group_id, rules) {
  if (!is.data.frame(standings)) stop("Nations League group standings must be a data frame", call. = FALSE)
  if (!"team_id" %in% names(standings)) stop("Nations League group standings require team_id", call. = FALSE)
  team_ids <- trimws(as.character(standings$team_id))
  if (!length(team_ids) || any(is.na(team_ids) | !nzchar(team_ids)) || anyDuplicated(team_ids)) stop("Nations League group standings have missing or duplicate team IDs", call. = FALSE)
  if (is.null(group_id) && "group_id" %in% names(standings)) group_id <- standings$group_id[[1L]]
  group_id <- uefa_nl_rank_table_scalar(group_id)
  if (is.na(group_id)) stop("Nations League group ranking requires group_id", call. = FALSE)
  rules <- uefa_nl_rank_rules(rules)
  discipline <- uefa_nl_rank_input_table(discipline_points, team_ids, "discipline_points", "discipline points")
  access <- uefa_nl_rank_input_table(access_list, team_ids, "access_list_position", "access list")
  missing <- unique(c(discipline$missing, access$missing))
  required_standing_fields <- c("points", "goal_difference", "goals_for", "wins")
  if (!all(required_standing_fields %in% names(standings))) missing <- c(missing, "universal_standings")
  if (all("points" %in% names(standings))) {
    points <- suppressWarnings(as.numeric(as.character(standings$points)))
    if (any(is.na(points) | !is.finite(points))) missing <- c(missing, "points")
  }
  prepared_matches <- uefa_nl_rank_prepare_matches(match_rows, team_ids, standings)
  missing <- unique(c(missing, prepared_matches$missing))
  league <- if ("league" %in% names(standings)) standings$league[[1L]] else if ("league_id" %in% names(standings)) standings$league_id[[1L]] else NA_character_
  list(standings = standings, team_ids = team_ids, group_id = group_id, league = uefa_nl_rank_table_scalar(league), rules = rules, discipline = discipline, access = access, matches = prepared_matches, missing = unique(missing))
}

uefa_nl_missing_rule_input_condition <- function(missing_rule_input, result = NULL) {
  missing_rule_input <- unique(as.character(missing_rule_input))
  missing_rule_input <- missing_rule_input[!is.na(missing_rule_input) & nzchar(missing_rule_input)]
  structure(list(message = paste0("Nations League ordering blocked: missing rule input: ", paste(missing_rule_input, collapse = ", ")), missing_rule_input = missing_rule_input, result = result), class = c("phase15_nl_missing_rule_input", "error", "condition"))
}

uefa_nl_blocked_ordering_result <- function(standings, missing_rule_input, rules = uefa_nl_2026_27_rules(), group_id = NULL) {
  rules <- uefa_nl_rank_rules(rules)
  output <- uefa_nl_rank_add_columns(standings, rules, ranking_scope = "group")
  if (!is.null(group_id)) output$group_id <- as.character(group_id)
  missing_rule_input <- unique(as.character(missing_rule_input))
  missing_rule_input <- missing_rule_input[!is.na(missing_rule_input) & nzchar(missing_rule_input)]
  output$computed_rank <- rep(NA_integer_, nrow(output))
  output$interim_rank <- rep(NA_integer_, nrow(output))
  output$ordering_status <- "blocked"
  output$missing_rule_input <- paste(missing_rule_input, collapse = ";")
  output$block_status <- "blocked"
  output$blocked <- TRUE
  output$suppression_reason <- "missing_rule_input"
  output <- uefa_nl_rank_finalize(output, rules)
  attr(output, "tiebreak_trace") <- uefa_nl_group_tiebreak_trace(group_id = if (nrow(output)) output$group_id[[1L]] else group_id, league = if (nrow(output)) output$league[[1L]] else NA_character_, criterion = "blocked", tied_subset = list(if (nrow(output)) output$team_id else character()), counted_match_ids = "", decision = paste(missing_rule_input, collapse = ";"), rules = rules)
  output
}

uefa_nl_rank_group <- function(standings, match_rows = NULL, discipline_points = NULL, access_list = NULL, rules = uefa_nl_2026_27_rules(), group_id = NULL) {
  rules <- uefa_nl_rank_rules(rules)
  preflight <- uefa_nl_rank_preflight(standings, match_rows, discipline_points, access_list, group_id, rules)
  if (length(preflight$missing)) return(uefa_nl_blocked_ordering_result(preflight$standings, preflight$missing, rules, preflight$group_id))
  standings <- preflight$standings
  team_ids <- preflight$team_ids
  matches <- preflight$matches$rows
  eligible <- preflight$matches$eligible
  match_metrics <- uefa_nl_rank_metrics_from_matches(matches, eligible, team_ids)
  overall <- match_metrics
  for (field in c("goal_difference", "goals_for", "wins")) if (field %in% names(standings)) overall[[field]] <- as.numeric(standings[[field]][match(team_ids, standings$team_id)])
  overall$discipline_points <- as.integer(preflight$discipline$values[overall$team_id])
  overall$access_list_position <- as.integer(preflight$access$values[overall$team_id])
  trace_parts <- list()
  trace_index <- 0L
  add_trace <- function(criterion, subset, counted_ids, decision, depth = 0L, remaining = character()) {
    trace_index <<- trace_index + 1L
    trace_parts[[trace_index]] <<- uefa_nl_group_tiebreak_trace(group_id = preflight$group_id, league = preflight$league, criterion = criterion, tied_subset = list(subset), counted_match_ids = list(counted_ids), decision = decision, recursion_depth = depth, remaining_tied_subset = list(remaining), rules = rules)
  }
  h2h_values <- function(ids, criterion) {
    subset_rows <- matches[eligible & matches$home_team_id %in% ids & matches$away_team_id %in% ids, , drop = FALSE]
    metrics <- uefa_nl_rank_metrics_from_matches(subset_rows, rep(TRUE, nrow(subset_rows)), ids)
    field <- switch(criterion, head_to_head_points = "points", head_to_head_goal_difference = "goal_difference", head_to_head_goals = "goals_for")
    list(values = metrics[[field]], counted_ids = uefa_nl_rank_match_ids(subset_rows))
  }
  overall_values <- function(ids, criterion) {
    rows <- overall[match(ids, overall$team_id), , drop = FALSE]
    values <- switch(criterion, overall_goal_difference = rows$goal_difference, overall_goals = rows$goals_for, overall_away_goals = rows$away_goals, wins = rows$wins, away_wins = rows$away_wins, discipline_points = rows$discipline_points, access_list_position = rows$access_list_position)
    list(values = values, counted_ids = uefa_nl_rank_match_ids(matches[eligible, , drop = FALSE]))
  }
  h2h_criteria <- c("head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals")
  overall_criteria <- c("overall_goal_difference", "overall_goals", "overall_away_goals", "wins", "away_wins", "discipline_points", "access_list_position")
  order_overall <- function(ids, criterion_index, depth) {
    if (length(ids) <= 1L) return(ids)
    for (index in seq.int(criterion_index, length(overall_criteria))) {
      criterion <- overall_criteria[[index]]
      evaluated <- overall_values(ids, criterion)
      groups <- uefa_nl_rank_group_metric_groups(ids, evaluated$values, criterion != "discipline_points")
      decision <- paste(vapply(groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > ")
      add_trace(criterion, ids, evaluated$counted_ids, decision, depth, ids)
      if (length(groups) > 1L) return(unlist(lapply(groups, function(group) if (length(group) <= 1L) group else order_overall(group, index + 1L, depth)), use.names = FALSE))
    }
    sort(ids, method = "radix")
  }
  order_tied_subset <- function(ids, depth = 0L) {
    if (length(ids) <= 1L) return(ids)
    for (criterion in h2h_criteria) {
      evaluated <- h2h_values(ids, criterion)
      groups <- uefa_nl_rank_group_metric_groups(ids, evaluated$values, TRUE)
      decision <- paste(vapply(groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > ")
      add_trace(criterion, ids, evaluated$counted_ids, decision, depth, ids)
      if (length(groups) > 1L) {
        return(unlist(lapply(groups, function(group) {
          if (length(group) <= 1L) return(group)
          add_trace("recursive_tied_subset", group, evaluated$counted_ids, "reapply_head_to_head", depth + 1L, group)
          order_tied_subset(group, depth + 1L)
        }), use.names = FALSE))
      }
    }
    order_overall(ids, 1L, depth)
  }
  points <- as.numeric(standings$points[match(team_ids, standings$team_id)])
  initial_groups <- uefa_nl_rank_group_metric_groups(team_ids, points, TRUE)
  add_trace("points", team_ids, uefa_nl_rank_match_ids(matches[eligible, , drop = FALSE]), paste(vapply(initial_groups, function(group) paste(sort(group), collapse = "+"), character(1)), collapse = " > "), 0L, team_ids)
  ordered_ids <- unlist(lapply(initial_groups, function(group) if (length(group) <= 1L) group else order_tied_subset(group, 0L)), use.names = FALSE)
  if (length(ordered_ids) != length(team_ids) || anyDuplicated(ordered_ids) || !setequal(ordered_ids, team_ids)) stop("Nations League Article 15 ordering did not return the complete team set", call. = FALSE)
  output <- standings[match(ordered_ids, standings$team_id), , drop = FALSE]
  output <- uefa_nl_rank_add_columns(output, rules, ranking_scope = "group")
  output$league <- preflight$league
  output$league_id <- preflight$league
  output$group_id <- preflight$group_id
  output$team_id <- ordered_ids
  output$computed_rank <- as.integer(seq_len(nrow(output)))
  output$group_position <- output$computed_rank
  output$discipline_points <- as.integer(preflight$discipline$values[ordered_ids])
  output$access_list_position <- as.integer(preflight$access$values[ordered_ids])
  output$counted_match_ids <- vapply(ordered_ids, function(team_id) paste(uefa_nl_rank_match_ids(matches[eligible & (matches$home_team_id == team_id | matches$away_team_id == team_id), , drop = FALSE]), collapse = ";"), character(1))
  output$excluded_match_ids <- ""
  output$ordering_status <- "ready"
  output$missing_rule_input <- ""
  output$block_status <- "not_blocked"
  output$blocked <- FALSE
  output$suppression_reason <- "none"
  output$ruleset_version <- rules$ruleset_version
  output$ruleset_sha256 <- uefa_nl_ruleset_sha256(rules)
  output <- uefa_nl_rank_finalize(output, rules)
  trace <- if (length(trace_parts)) do.call(rbind, trace_parts) else uefa_nl_group_tiebreak_trace(rules = rules)
  row.names(trace) <- NULL
  attr(output, "tiebreak_trace") <- trace
  attr(output, "trace") <- trace
  output
}

uefa_nl_make_standings_adapter <- function(match_rows, discipline_points, access_list, group_id, rules = uefa_nl_2026_27_rules()) {
  rules <- uefa_nl_rank_rules(rules)
  adapter <- function(snapshot) {
    ranked <- uefa_nl_rank_group(snapshot, match_rows, discipline_points, access_list, rules, group_id)
    if (any(ranked$ordering_status == "blocked") || any(is.na(ranked$computed_rank))) {
      missing <- unique(unlist(strsplit(ranked$missing_rule_input, ";", fixed = TRUE)))
      missing <- missing[nzchar(missing)]
      stop(uefa_nl_missing_rule_input_condition(missing, ranked))
    }
    ranked[, c("team_id", "computed_rank"), drop = FALSE]
  }
  attr(adapter, "adapter_id") <- "uefa_nl_article15_v2"
  attr(adapter, "ruleset_version") <- rules$ruleset_version
  attr(adapter, "ruleset_sha256") <- uefa_nl_ruleset_sha256(rules)
  attr(adapter, "group_id") <- as.character(group_id)
  adapter
}

uefa_nl_build_group_standings_state <- function(match_rows, discipline_points = NULL, access_list = NULL, group_id = NULL, rules = uefa_nl_2026_27_rules(), edition_id = NULL, state_cutoff_utc = NULL, source_bundle_id = NULL, team_ids = NULL) {
  rules <- uefa_nl_rank_rules(rules)
  if (!exists("phase14_compute_standings", mode = "function", inherits = TRUE)) stop("Phase 14 standings reducer must be loaded before building Nations League state", call. = FALSE)
  if (!is.data.frame(match_rows)) stop("Nations League state matches must be a data frame", call. = FALSE)
  rows <- as.data.frame(match_rows, stringsAsFactors = FALSE, check.names = FALSE)
  edition_id <- edition_id %||% rules$edition_id
  if (is.null(group_id) && "group_id" %in% names(rows) && nrow(rows)) group_id <- rows$group_id[[1L]]
  if (is.null(source_bundle_id) && "source_bundle_id" %in% names(rows) && nrow(rows)) source_bundle_id <- rows$source_bundle_id[[1L]]
  source_bundle_id <- source_bundle_id %||% uefa_nl_source_bundle_id()
  if (is.null(state_cutoff_utc)) {
    evidence_fields <- intersect(c("evidence_completed_at_utc", "completed_at_utc"), names(rows))
    evidence_field <- if (length(evidence_fields)) evidence_fields[[1L]] else NULL
    if (!is.null(evidence_field) && nrow(rows)) {
      evidence <- suppressWarnings(as.POSIXct(as.character(rows[[evidence_field]]), tz = "UTC"))
      evidence <- evidence[!is.na(evidence)]
      if (length(evidence)) state_cutoff_utc <- format(max(evidence), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
  }
  state_cutoff_utc <- state_cutoff_utc %||% "2099-12-31T23:59:59Z"
  universal <- phase14_compute_standings(matches = rows, edition_id = edition_id, group_id = group_id, state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id, ruleset_adapter = NULL, team_ids = team_ids)
  preflight <- uefa_nl_rank_preflight(universal, rows, discipline_points, access_list, group_id, rules)
  if (length(preflight$missing)) {
    blocked <- uefa_nl_blocked_ordering_result(universal, preflight$missing, rules, group_id)
    return(list(edition_id = edition_id, group_id = group_id, state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id, universal_standings = universal, standings = blocked, ranking = blocked, ordering_status = "blocked", block_status = "blocked", missing_rule_input = paste(preflight$missing, collapse = ";"), tiebreak_trace = attr(blocked, "tiebreak_trace", exact = TRUE), ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_nl_ruleset_sha256(rules)))
  }
  adapter <- uefa_nl_make_standings_adapter(rows, discipline_points, access_list, group_id, rules)
  phase14_standings <- phase14_compute_standings(matches = rows, edition_id = edition_id, group_id = group_id, state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id, ruleset_adapter = adapter, team_ids = team_ids)
  ranking <- uefa_nl_rank_group(phase14_standings, rows, discipline_points, access_list, rules, group_id)
  list(edition_id = edition_id, group_id = group_id, state_cutoff_utc = state_cutoff_utc, source_bundle_id = source_bundle_id, universal_standings = universal, phase14_standings = phase14_standings, standings = ranking, ranking = ranking, ordering_status = "ready", block_status = "not_blocked", missing_rule_input = "", tiebreak_trace = attr(ranking, "tiebreak_trace", exact = TRUE), ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_nl_ruleset_sha256(rules))
}

uefa_nl_rank_bind_group_standings <- function(group_standings) {
  if (is.data.frame(group_standings)) return(as.data.frame(group_standings, stringsAsFactors = FALSE, check.names = FALSE))
  if (!is.list(group_standings)) stop("Nations League individual rankings require group standings", call. = FALSE)
  frames <- group_standings[vapply(group_standings, is.data.frame, logical(1))]
  if (!length(frames)) stop("Nations League individual rankings require non-empty group standings", call. = FALSE)
  frame_names <- names(frames)
  frames <- lapply(seq_along(frames), function(index) {
    frame <- as.data.frame(frames[[index]], stringsAsFactors = FALSE, check.names = FALSE)
    if (!"group_id" %in% names(frame) && length(frame_names) && nzchar(frame_names[[index]])) frame$group_id <- frame_names[[index]]
    frame
  })
  output <- do.call(rbind, frames)
  row.names(output) <- NULL
  output
}

uefa_nl_rank_blocked_scope <- function(data, missing_rule_input, rules, ranking_scope) {
  output <- uefa_nl_rank_add_columns(data, rules, ranking_scope = ranking_scope)
  missing_rule_input <- unique(as.character(missing_rule_input))
  missing_rule_input <- missing_rule_input[!is.na(missing_rule_input) & nzchar(missing_rule_input)]
  output$individual_rank <- rep(NA_integer_, nrow(output))
  output$computed_rank <- rep(NA_integer_, nrow(output))
  output$interim_rank <- rep(NA_integer_, nrow(output))
  output$ordering_status <- "blocked"
  output$missing_rule_input <- paste(missing_rule_input, collapse = ";")
  output$block_status <- "blocked"
  output$blocked <- TRUE
  output$suppression_reason <- "missing_rule_input"
  uefa_nl_rank_finalize(output, rules)
}

uefa_nl_rank_group_position <- function(data) {
  if (!"group_position" %in% names(data)) data$group_position <- NA_integer_
  positions <- suppressWarnings(as.integer(as.character(data$group_position)))
  fallback <- is.na(positions) & "computed_rank" %in% names(data)
  positions[fallback] <- suppressWarnings(as.integer(as.character(data$computed_rank[fallback])))
  positions
}

uefa_nl_rank_individual_league <- function(
    group_standings,
    match_rows = NULL,
    rules = uefa_nl_2026_27_rules()) {
  rules <- uefa_nl_rank_rules(rules)
  standings <- uefa_nl_rank_bind_group_standings(group_standings)
  if (!"team_id" %in% names(standings)) stop("Nations League individual standings require team_id", call. = FALSE)
  standings$team_id <- trimws(as.character(standings$team_id))
  if (any(is.na(standings$team_id) | !nzchar(standings$team_id)) || anyDuplicated(standings$team_id)) stop("Nations League individual standings have missing or duplicate team IDs", call. = FALSE)
  if (!"league" %in% names(standings) && "league_id" %in% names(standings)) standings$league <- as.character(standings$league_id)
  if (!"league_id" %in% names(standings) && "league" %in% names(standings)) standings$league_id <- as.character(standings$league)
  if (!"league" %in% names(standings)) stop("Nations League individual standings require league", call. = FALSE)
  standings$league <- toupper(trimws(as.character(standings$league)))
  if (any(!standings$league %in% c("A", "B", "C", "D"))) stop("Nations League individual standings contain an unknown league", call. = FALSE)
  standings$group_position <- uefa_nl_rank_group_position(standings)
  missing <- character()
  if (any(is.na(standings$group_position))) missing <- c(missing, "group_position")
  ordering_status <- if ("ordering_status" %in% names(standings)) as.character(standings$ordering_status) else rep("ready", nrow(standings))
  if (any(is.na(ordering_status) | ordering_status == "blocked")) missing <- c(missing, "group_ordering")
  if ("computed_rank" %in% names(standings) && any(is.na(standings$computed_rank))) missing <- c(missing, "group_ordering")
  if (!"group_id" %in% names(standings)) standings$group_id <- NA_character_
  if (any(is.na(standings$group_id) | !nzchar(as.character(standings$group_id)))) missing <- c(missing, "group_id")
  if (!"discipline_points" %in% names(standings) || any(is.na(standings$discipline_points))) missing <- c(missing, "discipline_points")
  if (!"access_list_position" %in% names(standings) || any(is.na(standings$access_list_position))) missing <- c(missing, "access_list_position")
  if (length(missing)) return(uefa_nl_rank_blocked_scope(standings, unique(missing), rules, "individual_league"))
  matches <- match_rows %||% data.frame(stringsAsFactors = FALSE)
  if (!is.data.frame(matches)) stop("Nations League individual ranking matches must be a data frame", call. = FALSE)
  group_ids <- unique(as.character(standings$group_id))
  group_results <- list()
  group_index <- 0L
  for (group_id in sort(group_ids, method = "radix")) {
    group_rows <- standings[standings$group_id == group_id, , drop = FALSE]
    group_index <- group_index + 1L
    group_team_ids <- as.character(group_rows$team_id)
    group_matches <- if ("group_id" %in% names(matches)) matches[as.character(matches$group_id) == group_id, , drop = FALSE] else matches
    prepared <- uefa_nl_rank_prepare_matches(group_matches, group_team_ids, group_rows)
    if (length(prepared$missing)) missing <- unique(c(missing, prepared$missing))
    group_positions <- group_rows$group_position
    fourth <- group_rows$team_id[group_positions == 4L]
    fourth_exists <- length(fourth) == 1L
    rows <- lapply(seq_len(nrow(group_rows)), function(row_index) {
      source <- group_rows[row_index, , drop = FALSE]
      team_id <- as.character(source$team_id[[1L]])
      team_position <- as.integer(source$group_position[[1L]])
      eligible <- prepared$eligible
      team_match <- eligible & (prepared$rows$home_team_id == team_id | prepared$rows$away_team_id == team_id)
      excluded <- rep(FALSE, nrow(prepared$rows))
      if (fourth_exists && team_position %in% 1:3) {
        excluded <- team_match & (prepared$rows$home_team_id %in% fourth | prepared$rows$away_team_id %in% fourth)
      }
      counted <- team_match & !excluded
      metric <- if (nrow(prepared$rows)) {
        uefa_nl_rank_metrics_from_matches(prepared$rows[counted, , drop = FALSE], rep(TRUE, sum(counted)), team_id)
      } else {
        data.frame(team_id = team_id, points = as.numeric(source$points[[1L]]), goal_difference = as.numeric(source$goal_difference[[1L]]), goals_for = as.numeric(source$goals_for[[1L]]), away_goals = if ("away_goals" %in% names(source)) as.numeric(source$away_goals[[1L]]) else 0, wins = as.numeric(source$wins[[1L]]), away_wins = if ("away_wins" %in% names(source)) as.numeric(source$away_wins[[1L]]) else 0, stringsAsFactors = FALSE, check.names = FALSE)
      }
      output <- source
      output$ranking_scope <- "individual_league"
      output$individual_rank <- NA_integer_
      output$interim_rank <- NA_integer_
      output$individual_points <- as.integer(metric$points[[1L]])
      output$individual_goal_difference <- as.integer(metric$goal_difference[[1L]])
      output$individual_goals <- as.integer(metric$goals_for[[1L]])
      output$individual_away_goals <- as.integer(metric$away_goals[[1L]])
      output$individual_wins <- as.integer(metric$wins[[1L]])
      output$individual_away_wins <- as.integer(metric$away_wins[[1L]])
      output$counted_match_ids <- paste(uefa_nl_rank_match_ids(prepared$rows[counted, , drop = FALSE]), collapse = ";")
      output$excluded_match_ids <- paste(uefa_nl_rank_match_ids(prepared$rows[excluded, , drop = FALSE]), collapse = ";")
      output$comparison_status <- if (length(prepared$missing)) "blocked" else "ready"
      output
    })
    group_results[[group_index]] <- do.call(rbind, rows)
  }
  output <- do.call(rbind, group_results)
  if (length(missing)) return(uefa_nl_rank_blocked_scope(output, unique(missing), rules, "individual_league"))
  output$ordering_status <- "ready"
  output$missing_rule_input <- ""
  output$block_status <- "not_blocked"
  output$blocked <- FALSE
  output$suppression_reason <- "none"
  output$ranking_scope <- "individual_league"
  output$ruleset_version <- rules$ruleset_version
  output$ruleset_sha256 <- uefa_nl_ruleset_sha256(rules)
  output$individual_rank <- NA_integer_
  output$computed_rank <- NA_integer_
  output$interim_rank <- NA_integer_
  for (league in sort(unique(output$league), method = "radix")) {
    indexes <- which(output$league == league)
    order_index <- order(
      output$group_position[indexes],
      -output$individual_points[indexes],
      -output$individual_goal_difference[indexes],
      -output$individual_goals[indexes],
      -output$individual_away_goals[indexes],
      -output$individual_wins[indexes],
      -output$individual_away_wins[indexes],
      output$discipline_points[indexes],
      -output$access_list_position[indexes],
      output$team_id[indexes],
      method = "radix"
    )
    output$individual_rank[indexes[order_index]] <- seq_along(indexes)
  }
  output <- uefa_nl_rank_add_columns(output, rules, ranking_scope = "individual_league")
  output <- output[order(output$league, output$individual_rank, output$team_id, method = "radix"), , drop = FALSE]
  uefa_nl_rank_finalize(output, rules)
}

uefa_nl_rank_interim_overall <- function(
    individual_rankings,
    rules = uefa_nl_2026_27_rules()) {
  rules <- uefa_nl_rank_rules(rules)
  rankings <- uefa_nl_rank_bind_group_standings(individual_rankings)
  if (!"individual_rank" %in% names(rankings) && "computed_rank" %in% names(rankings)) rankings$individual_rank <- as.integer(rankings$computed_rank)
  if (!all(c("team_id", "league", "individual_rank") %in% names(rankings))) stop("Nations League interim rankings require team_id, league, and individual_rank", call. = FALSE)
  ordering_status <- if ("ordering_status" %in% names(rankings)) as.character(rankings$ordering_status) else rep("ready", nrow(rankings))
  if (any(is.na(ordering_status) | ordering_status == "blocked") || any(is.na(rankings$individual_rank))) return(uefa_nl_rank_blocked_scope(rankings, "group_ordering", rules, "interim_overall"))
  rankings$league <- toupper(as.character(rankings$league))
  if (any(!rankings$league %in% names(rules$rank_bands))) stop("Nations League interim rankings contain an unknown league", call. = FALSE)
  rankings$interim_rank <- NA_integer_
  for (league in c("A", "B", "C", "D")) {
    indexes <- which(rankings$league == league)
    if (!length(indexes)) next
    ordered <- indexes[order(rankings$individual_rank[indexes], rankings$team_id[indexes], method = "radix")]
    start <- as.integer(rules$rank_bands[[league]]$min)
    rankings$interim_rank[ordered] <- start + seq_along(ordered) - 1L
  }
  rankings$computed_rank <- rankings$interim_rank
  rankings$ranking_scope <- "interim_overall"
  rankings$ranking_stage <- "interim_overall"
  rankings$ordering_status <- "ready"
  rankings$missing_rule_input <- ""
  rankings$block_status <- "not_blocked"
  rankings$blocked <- FALSE
  rankings$suppression_reason <- "none"
  rankings$ruleset_version <- rules$ruleset_version
  rankings$ruleset_sha256 <- uefa_nl_ruleset_sha256(rules)
  rankings <- rankings[order(rankings$interim_rank, rankings$team_id, method = "radix"), , drop = FALSE]
  uefa_nl_rank_finalize(rankings, rules)
}

uefa_nl_rank_final_stage_id <- function(value) {
  tokens <- tolower(gsub("[^a-z0-9]+", "_", trimws(as.character(value))))
  tokens[tokens %in% c("qf", "quarter_final", "quarterfinal", "league_a_qf", "league_a_quarterfinal")] <- "league_a_quarter_final"
  tokens[tokens %in% c("qf_winner", "qf_loser", "qf_winners", "qf_losers", "quarter_final_winner", "quarter_final_loser", "quarter_final_winners", "quarter_final_losers")] <- "league_a_quarter_final"
  tokens[tokens %in% c("sf", "semi_final", "semifinal", "league_a_sf", "league_a_semifinal")] <- "league_a_semi_final"
  tokens[tokens %in% c("third", "third_place", "third_place_match", "thirdplace", "league_a_third_place_match")] <- "league_a_third_place"
  tokens[tokens %in% c("third_place_winner", "third_place_loser", "third_place_winners", "third_place_losers", "league_a_third_place_winner", "league_a_third_place_loser")] <- "league_a_third_place"
  tokens[tokens %in% c("final", "league_a_title_final")] <- "league_a_final"
  tokens[tokens %in% c("final_winner", "final_loser", "final_winners", "final_losers", "league_a_final_winner", "league_a_final_loser")] <- "league_a_final"
  tokens[tokens %in% c("ab", "a_b", "a_b_playoff", "a_b_play_off")] <- "a_b_playoff"
  tokens[tokens %in% c("bc", "b_c", "b_c_playoff", "b_c_play_off")] <- "b_c_playoff"
  tokens[tokens %in% c("cd", "c_d", "c_d_playoff", "c_d_play_off", "c_d_playoff_cancellation")] <- "c_d_playoff"
  tokens
}

uefa_nl_rank_final_stage_frame <- function(stage_results) {
  if (is.null(stage_results)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  if (is.data.frame(stage_results)) return(as.data.frame(stage_results, stringsAsFactors = FALSE, check.names = FALSE))
  if (!is.list(stage_results)) stop("Nations League final ranking stage results must be a data frame or list", call. = FALSE)

  nested <- intersect(c("stage_capture", "capture", "stages", "outcomes", "results"), names(stage_results))
  if (length(nested)) {
    candidate <- stage_results[[nested[[1L]]]]
    if (is.data.frame(candidate)) return(as.data.frame(candidate, stringsAsFactors = FALSE, check.names = FALSE))
    if (is.list(candidate)) stage_results <- candidate
  }

  frames <- list()
  frame_index <- 0L
  stage_names <- names(stage_results)
  if (is.null(stage_names)) stage_names <- character()
  consumed <- character()
  paired_specs <- list(
    league_a_quarter_final = list(
      winners = c("quarter_final_winners", "qf_winners", "league_a_quarter_final_winners"),
      losers = c("quarter_final_losers", "qf_losers", "league_a_quarter_final_losers")
    ),
    league_a_final = list(
      winners = c("final_winners", "final_winner", "league_a_final_winners", "league_a_final_winner"),
      losers = c("final_losers", "final_loser", "league_a_final_losers", "league_a_final_loser")
    ),
    league_a_third_place = list(
      winners = c("third_place_winners", "third_place_winner", "third_winners", "third_winner"),
      losers = c("third_place_losers", "third_place_loser", "third_losers", "third_loser")
    )
  )
  for (stage_id in names(paired_specs)) {
    winner_name <- intersect(paired_specs[[stage_id]]$winners, stage_names)
    loser_name <- intersect(paired_specs[[stage_id]]$losers, stage_names)
    if (!length(winner_name) || !length(loser_name)) next
    winners <- as.character(stage_results[[winner_name[[1L]]]])
    losers <- as.character(stage_results[[loser_name[[1L]]]])
    row_count <- max(length(winners), length(losers))
    frames[[frame_index <- frame_index + 1L]] <- data.frame(
      stage_id = rep(stage_id, row_count),
      tie_id = paste(stage_id, seq_len(row_count), sep = "::"),
      stage_status = rep("completed", row_count),
      winner_team_id = rep(winners, length.out = row_count),
      loser_team_id = rep(losers, length.out = row_count),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    consumed <- c(consumed, winner_name[[1L]], loser_name[[1L]])
  }
  for (stage_name in setdiff(stage_names, consumed)) {
    value <- stage_results[[stage_name]]
    stage_id <- uefa_nl_rank_final_stage_id(stage_name)
    if (is.data.frame(value)) {
      frame <- as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
      if (!"stage_id" %in% names(frame)) frame$stage_id <- stage_id
      frames[[frame_index <- frame_index + 1L]] <- frame
      next
    }
    if (is.atomic(value) && length(value)) {
      field <- if (grepl("loser|defeat", tolower(stage_name))) "loser_team_id" else "winner_team_id"
      frame <- data.frame(
        stage_id = rep(stage_id, length(value)),
        stage_status = rep("completed", length(value)),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      frame[[field]] <- as.character(value)
      frames[[frame_index <- frame_index + 1L]] <- frame
      next
    }
    if (is.list(value) && length(value)) {
      scalar_fields <- intersect(c(
        "winner_team_id", "loser_team_id", "winner", "loser", "winning_team_id", "losing_team_id",
        "stage_status", "status", "stage_id", "tie_id"
      ), names(value))
      if (length(scalar_fields)) {
        frame <- as.data.frame(value[scalar_fields], stringsAsFactors = FALSE, check.names = FALSE)
        if (!"stage_id" %in% names(frame)) frame$stage_id <- stage_id
        if (!"stage_status" %in% names(frame)) frame$stage_status <- "completed"
        frames[[frame_index <- frame_index + 1L]] <- frame
      }
    }
  }
  if (!length(frames)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    for (field in setdiff(all_names, names(frame))) frame[[field]] <- rep(NA_character_, nrow(frame))
    frame[, all_names, drop = FALSE]
  })
  output <- do.call(rbind, lapply(frames, function(frame) {
    frame$stage_id <- uefa_nl_rank_final_stage_id(frame$stage_id)
    frame
  }))
  row.names(output) <- NULL
  output
}

uefa_nl_rank_final_stage_status <- function(rows) {
  if (!nrow(rows)) return(character())
  field <- if ("stage_status" %in% names(rows)) "stage_status" else if ("resolution_status" %in% names(rows)) "resolution_status" else if ("status" %in% names(rows)) "status" else NULL
  if (is.null(field)) return(rep("completed", nrow(rows)))
  values <- tolower(trimws(as.character(rows[[field]])))
  values[is.na(values) | !nzchar(values)] <- "completed"
  values
}

uefa_nl_rank_final_stage_column <- function(rows, fields) {
  fields <- intersect(fields, names(rows))
  if (!length(fields)) return(rep(NA_character_, nrow(rows)))
  values <- trimws(as.character(rows[[fields[[1L]]]]))
  values[is.na(values) | !nzchar(values)] <- NA_character_
  values
}

uefa_nl_rank_final_stage_scores <- function(rows) {
  home_fields <- intersect(c("final_home_goals", "home_goals", "regulation_home_goals"), names(rows))
  away_fields <- intersect(c("final_away_goals", "away_goals", "regulation_away_goals"), names(rows))
  if (!length(home_fields) || !length(away_fields)) return(list(home = rep(NA_real_, nrow(rows)), away = rep(NA_real_, nrow(rows))))
  home <- suppressWarnings(as.numeric(as.character(rows[[home_fields[[1L]]]])))
  away <- suppressWarnings(as.numeric(as.character(rows[[away_fields[[1L]]]])))
  list(home = home, away = away)
}

uefa_nl_rank_final_stage_tie_key <- function(rows, stage_id) {
  tie_fields <- intersect(c("tie_id", "matchup_id", "pair_id", "participant_pair_id"), names(rows))
  if (length(tie_fields)) {
    values <- trimws(as.character(rows[[tie_fields[[1L]]]]))
    values[is.na(values) | !nzchar(values)] <- NA_character_
  } else {
    values <- rep(NA_character_, nrow(rows))
  }
  home <- uefa_nl_rank_final_stage_column(rows, c("home_team_id", "home_id"))
  away <- uefa_nl_rank_final_stage_column(rows, c("away_team_id", "away_id"))
  slots_home <- uefa_nl_rank_final_stage_column(rows, c("participant_slot_home", "slot_home"))
  slots_away <- uefa_nl_rank_final_stage_column(rows, c("participant_slot_away", "slot_away"))
  fallback <- ifelse(
    !is.na(slots_home) & !is.na(slots_away),
    paste(pmin(slots_home, slots_away), pmax(slots_home, slots_away), sep = "::"),
    ifelse(!is.na(home) & !is.na(away), paste(pmin(home, away), pmax(home, away), sep = "::"), paste0(stage_id, "::", seq_len(nrow(rows))))
  )
  values[is.na(values)] <- fallback[is.na(values)]
  paste(stage_id, values, sep = "::")
}

uefa_nl_rank_final_stage_outcomes <- function(stage_results) {
  rows <- uefa_nl_rank_final_stage_frame(stage_results)
  if (!nrow(rows)) return(list(rows = rows, outcomes = data.frame(stringsAsFactors = FALSE), blocked = FALSE, missing = character(), supplied = FALSE))
  if (!"stage_id" %in% names(rows)) stop("Nations League final ranking stage results require stage_id", call. = FALSE)
  rows$stage_id <- uefa_nl_rank_final_stage_id(rows$stage_id)
  direct_rank_field <- intersect(c("final_overall_rank", "final_rank"), names(rows))
  outcome_fields <- intersect(c(
    "winner_team_id", "winning_team_id", "winner_id", "winner_team", "outcome_winner_team_id", "winner",
    "loser_team_id", "losing_team_id", "loser_id", "loser_team", "outcome_loser_team_id", "loser",
    "home_team_id", "home_id", "away_team_id", "away_id"
  ), names(rows))
  if (length(direct_rank_field) && "team_id" %in% names(rows) && !length(outcome_fields)) {
    return(list(rows = rows, outcomes = data.frame(stringsAsFactors = FALSE), blocked = FALSE, missing = character(), supplied = TRUE))
  }
  status <- uefa_nl_rank_final_stage_status(rows)
  blocked <- status %in% c("blocked", "invalid", "rejected")
  missing <- character()
  outcomes <- list()
  outcome_index <- 0L

  for (stage_id in unique(rows$stage_id)) {
    stage_rows <- rows[rows$stage_id == stage_id, , drop = FALSE]
    stage_status <- status[rows$stage_id == stage_id]
    if (any(stage_status %in% c("blocked", "invalid", "rejected"))) next
    preview_winner <- uefa_nl_rank_final_stage_column(stage_rows, c("winner_team_id", "winning_team_id", "winner_id", "winner_team", "outcome_winner_team_id", "winner"))
    preview_scores <- uefa_nl_rank_final_stage_scores(stage_rows)
    official_evidence <- stage_status == "official" & (
      !is.na(preview_winner) |
        (!is.na(preview_scores$home) & !is.na(preview_scores$away))
    )
    completed <- stage_status %in% c("completed", "complete", "finished", "after_extra_time", "after_penalties", "full_time", "full-time") | official_evidence
    if (!any(completed)) next
    stage_rows <- stage_rows[completed, , drop = FALSE]
    stage_status <- stage_status[completed]
    winner <- uefa_nl_rank_final_stage_column(stage_rows, c("winner_team_id", "winning_team_id", "winner_id", "winner_team", "outcome_winner_team_id", "winner"))
    loser <- uefa_nl_rank_final_stage_column(stage_rows, c("loser_team_id", "losing_team_id", "loser_id", "loser_team", "outcome_loser_team_id", "loser"))
    home <- uefa_nl_rank_final_stage_column(stage_rows, c("home_team_id", "home_id"))
    away <- uefa_nl_rank_final_stage_column(stage_rows, c("away_team_id", "away_id"))
    scores <- uefa_nl_rank_final_stage_scores(stage_rows)
    tie_keys <- uefa_nl_rank_final_stage_tie_key(stage_rows, stage_id)
    for (tie_key in unique(tie_keys)) {
      tie_rows <- stage_rows[tie_keys == tie_key, , drop = FALSE]
      tie_winner <- unique(winner[tie_keys == tie_key][!is.na(winner[tie_keys == tie_key])])
      tie_loser <- unique(loser[tie_keys == tie_key][!is.na(loser[tie_keys == tie_key])])
      participants <- unique(c(
        uefa_nl_rank_final_stage_column(tie_rows, c("home_team_id", "home_id")),
        uefa_nl_rank_final_stage_column(tie_rows, c("away_team_id", "away_id")),
        tie_winner, tie_loser
      ))
      participants <- participants[!is.na(participants) & nzchar(participants)]
      if (length(tie_winner) > 1L || length(tie_loser) > 1L || length(tie_winner) == 1L && length(tie_loser) > 1L) {
        blocked <- TRUE
        missing <- c(missing, paste0(stage_id, "_outcome"))
        next
      }
      if (!length(tie_winner)) {
        if (length(participants) != 2L || any(is.na(scores$home[tie_keys == tie_key]) | is.na(scores$away[tie_keys == tie_key]))) {
          blocked <- TRUE
          missing <- c(missing, paste0(stage_id, "_outcome"))
          next
        }
        aggregate <- setNames(numeric(length(participants)), participants)
        tie_home <- home[tie_keys == tie_key]
        tie_away <- away[tie_keys == tie_key]
        tie_home_scores <- scores$home[tie_keys == tie_key]
        tie_away_scores <- scores$away[tie_keys == tie_key]
        for (score_index in seq_along(tie_home_scores)) {
          aggregate[[tie_home[[score_index]]]] <- aggregate[[tie_home[[score_index]]]] + tie_home_scores[[score_index]]
          aggregate[[tie_away[[score_index]]]] <- aggregate[[tie_away[[score_index]]]] + tie_away_scores[[score_index]]
        }
        top <- names(aggregate)[aggregate == max(aggregate)]
        if (length(top) != 1L) {
          shoot_home_fields <- intersect(c("penalty_shootout_home_goals", "shootout_home_goals"), names(tie_rows))
          shoot_away_fields <- intersect(c("penalty_shootout_away_goals", "shootout_away_goals"), names(tie_rows))
          if (length(shoot_home_fields) && length(shoot_away_fields)) {
            shoot_home <- suppressWarnings(as.numeric(as.character(tie_rows[[shoot_home_fields[[1L]]]])))
            shoot_away <- suppressWarnings(as.numeric(as.character(tie_rows[[shoot_away_fields[[1L]]]])))
            shoot_index <- which(!is.na(shoot_home) & !is.na(shoot_away))
            if (length(shoot_index)) {
              last <- shoot_index[[length(shoot_index)]]
              shoot_winner <- if (shoot_home[[last]] > shoot_away[[last]]) tie_home[[last]] else if (shoot_away[[last]] > shoot_home[[last]]) tie_away[[last]] else NA_character_
              if (!is.na(shoot_winner)) top <- shoot_winner
            }
          }
        }
        if (length(top) != 1L) {
          blocked <- TRUE
          missing <- c(missing, paste0(stage_id, "_outcome"))
          next
        }
        tie_winner <- top
      }
      if (!length(tie_loser) && length(participants) == 2L) tie_loser <- setdiff(participants, tie_winner)
      if (length(tie_winner) != 1L || length(tie_loser) != 1L || identical(tie_winner, tie_loser)) {
        blocked <- TRUE
        missing <- c(missing, paste0(stage_id, "_outcome"))
        next
      }
      outcome_index <- outcome_index + 1L
      outcomes[[outcome_index]] <- data.frame(
        stage_id = stage_id,
        tie_id = tie_key,
        winner_team_id = tie_winner,
        loser_team_id = tie_loser,
        stage_status = "completed",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
  }
  outcome_frame <- if (length(outcomes)) do.call(rbind, outcomes) else data.frame(
    stage_id = character(), tie_id = character(), winner_team_id = character(), loser_team_id = character(), stage_status = character(),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  row.names(outcome_frame) <- NULL
  list(rows = rows, outcomes = outcome_frame, blocked = blocked, missing = unique(missing), supplied = TRUE)
}

uefa_nl_rank_final_blocked <- function(rankings, missing_rule_input, rules, stage_status = "blocked") {
  output <- as.data.frame(rankings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"interim_rank" %in% names(output) && "interim_overall_rank" %in% names(output)) output$interim_rank <- as.integer(output$interim_overall_rank)
  output <- uefa_nl_rank_add_columns(output, rules, ranking_scope = "final_overall")
  if (!"interim_overall_rank" %in% names(output)) output$interim_overall_rank <- as.integer(output$interim_rank)
  output$final_overall_rank <- rep(NA_integer_, nrow(output))
  output$computed_rank <- rep(NA_integer_, nrow(output))
  output$ranking_scope <- "final_overall"
  output$ranking_stage <- as.character(stage_status)
  output$final_ranking_status <- "blocked"
  output$final_stage_status <- "blocked"
  output$ordering_status <- "blocked"
  output$missing_rule_input <- paste(unique(as.character(missing_rule_input)), collapse = ";")
  output$block_status <- "blocked"
  output$blocked <- TRUE
  output$suppression_reason <- "missing_rule_input"
  uefa_nl_rank_finalize(output, rules)
}

uefa_nl_rank_final_overall <- function(
    interim_rankings,
    stage_results = NULL,
    rules = uefa_nl_2026_27_rules(),
    transition_slots = NULL) {
  rules <- uefa_nl_rank_rules(rules)
  rankings <- uefa_nl_rank_bind_group_standings(interim_rankings)
  if (!"interim_rank" %in% names(rankings) && "interim_overall_rank" %in% names(rankings)) rankings$interim_rank <- as.integer(rankings$interim_overall_rank)
  if (!all(c("team_id", "interim_rank") %in% names(rankings))) stop("Nations League final rankings require team_id and interim_rank", call. = FALSE)
  rankings$team_id <- trimws(as.character(rankings$team_id))
  rankings$interim_rank <- suppressWarnings(as.integer(as.character(rankings$interim_rank)))
  if (any(is.na(rankings$team_id) | !nzchar(rankings$team_id)) || anyDuplicated(rankings$team_id)) stop("Nations League final rankings have missing or duplicate team IDs", call. = FALSE)
  if (any(is.na(rankings$interim_rank)) || anyDuplicated(rankings$interim_rank)) return(uefa_nl_rank_final_blocked(rankings, "interim_overall_rank", rules))
  if (!"league" %in% names(rankings) && "league_id" %in% names(rankings)) rankings$league <- as.character(rankings$league_id)
  if (!"league" %in% names(rankings)) return(uefa_nl_rank_final_blocked(rankings, "league", rules))
  rankings$league <- toupper(trimws(as.character(rankings$league)))
  if (any(!rankings$league %in% c("A", "B", "C", "D"))) return(uefa_nl_rank_final_blocked(rankings, "league", rules))
  ordering_status <- if ("ordering_status" %in% names(rankings)) as.character(rankings$ordering_status) else rep("ready", nrow(rankings))
  blocked <- is.na(ordering_status) | ordering_status %in% c("blocked", "invalid")
  if ("block_status" %in% names(rankings)) blocked <- blocked | as.character(rankings$block_status) == "blocked"
  if (any(blocked)) return(uefa_nl_rank_final_blocked(rankings, "group_ordering", rules))
  rankings$interim_overall_rank <- as.integer(rankings$interim_rank)
  if ("ranking_stage" %in% names(rankings)) rankings$interim_ranking_stage <- as.character(rankings$ranking_stage)

  combined_stage_results <- stage_results
  if (is.null(combined_stage_results) && !is.null(transition_slots)) combined_stage_results <- transition_slots
  stage_info <- uefa_nl_rank_final_stage_outcomes(combined_stage_results)
  if (isTRUE(stage_info$blocked)) {
    blocked_inputs <- stage_info$missing
    if (!length(blocked_inputs)) blocked_inputs <- "stage_outcome"
    return(uefa_nl_rank_final_blocked(rankings, blocked_inputs, rules))
  }
  outcomes <- stage_info$outcomes
  outcome_for <- function(stage_id) outcomes[outcomes$stage_id == stage_id, , drop = FALSE]
  final_outcome <- outcome_for("league_a_final")
  third_outcome <- outcome_for("league_a_third_place")
  final_complete <- nrow(final_outcome) >= 1L && nrow(third_outcome) >= 1L
  final_teams <- if (final_complete) c(final_outcome$winner_team_id[[1L]], final_outcome$loser_team_id[[1L]], third_outcome$winner_team_id[[1L]], third_outcome$loser_team_id[[1L]]) else character()
  if (final_complete && (any(!final_teams %in% rankings$team_id) || anyDuplicated(final_teams))) return(uefa_nl_rank_final_blocked(rankings, "final_stage_participants", rules))

  direct_rank_field <- intersect(c("final_overall_rank", "final_rank"), names(stage_info$rows))
  if (length(direct_rank_field) && "team_id" %in% names(stage_info$rows)) {
    direct_rows <- stage_info$rows[, c("team_id", direct_rank_field[[1L]]), drop = FALSE]
    direct_rows$team_id <- as.character(direct_rows$team_id)
    direct_rows$direct_rank <- suppressWarnings(as.integer(as.character(direct_rows[[direct_rank_field[[1L]]]])))
    direct_rows <- direct_rows[!is.na(direct_rows$direct_rank), c("team_id", "direct_rank"), drop = FALSE]
    if (nrow(direct_rows) == nrow(rankings) && setequal(direct_rows$team_id, rankings$team_id) && !anyDuplicated(direct_rows$direct_rank) && all(sort(direct_rows$direct_rank) == seq_len(nrow(rankings)))) {
      rankings$final_overall_rank <- direct_rows$direct_rank[match(rankings$team_id, direct_rows$team_id)]
      rankings$computed_rank <- rankings$final_overall_rank
      rankings$ranking_scope <- "final_overall"
      rankings$ranking_stage <- if (final_complete) "final_overall" else "final_overall_pre_finals"
      rankings$final_ranking_status <- "ready"
      rankings$final_stage_status <- if (final_complete) "completed" else "pre_finals"
      rankings$ordering_status <- "ready"
      rankings$missing_rule_input <- ""
      rankings$block_status <- "not_blocked"
      rankings$blocked <- FALSE
      rankings$suppression_reason <- "none"
      rankings <- rankings[order(rankings$final_overall_rank, rankings$team_id, method = "radix"), , drop = FALSE]
      return(uefa_nl_rank_finalize(rankings, rules))
    }
  }

  has_outcome <- nrow(outcomes) > 0L
  if (!stage_info$supplied || !has_outcome) {
    rankings$final_overall_rank <- rankings$interim_rank
    rankings$computed_rank <- rankings$final_overall_rank
    rankings$ranking_scope <- "final_overall"
    rankings$ranking_stage <- "final_overall_pre_finals"
    rankings$final_ranking_status <- "ready"
    rankings$final_stage_status <- "pre_finals"
  } else {
    containers <- rep(NA_character_, nrow(rankings))
    rank <- rankings$interim_rank
    containers[rank >= 1L & rank <= 4L] <- "quarter_final_winner"
    containers[rank >= 5L & rank <= 8L] <- "quarter_final_loser"
    containers[rank >= 9L & rank <= 12L] <- "a_b_band"
    containers[rank >= 13L & rank <= 16L] <- "a_relegation_band"
    containers[rank >= 17L & rank <= 20L] <- "a_b_band"
    containers[rank >= 21L & rank <= 24L] <- "a_relegation_band"
    containers[rank >= 25L & rank <= 28L] <- "b_c_band"
    containers[rank >= 29L & rank <= 32L] <- "b_relegation_band"
    containers[rank >= 33L & rank <= 36L] <- "b_c_band"
    containers[rank >= 37L & rank <= 40L] <- "b_relegation_band"
    containers[rank >= 41L & rank <= 44L] <- "c_stable_band"
    containers[rank >= 45L & rank <= 46L] <- "c_d_band"
    containers[rank >= 47L & rank <= 48L] <- "c_relegation_band"
    containers[rank >= 49L & rank <= 50L] <- "c_d_band"
    containers[rank >= 51L & rank <= 52L] <- "c_relegation_band"
    containers[rank >= 53L] <- "d_stable_band"
    assignment_error <- FALSE
    assignment_missing <- character()
    apply_outcomes <- function(stage_id, winner_container, loser_container = winner_container) {
      stage_rows <- outcome_for(stage_id)
      if (!nrow(stage_rows)) return(invisible(NULL))
      for (row_index in seq_len(nrow(stage_rows))) {
        winner <- stage_rows$winner_team_id[[row_index]]
        loser <- stage_rows$loser_team_id[[row_index]]
        for (team_id in c(winner, loser)) {
          if (!team_id %in% rankings$team_id) {
            assignment_error <<- TRUE
            assignment_missing <<- c(assignment_missing, paste0(stage_id, "_participant"))
          }
        }
        winner_index <- match(winner, rankings$team_id)
        loser_index <- match(loser, rankings$team_id)
        if (!is.na(winner_index) && !is.na(loser_index)) {
          if (!is.na(containers[[winner_index]]) && containers[[winner_index]] != winner_container) assignment_error <<- TRUE
          if (!is.na(containers[[loser_index]]) && containers[[loser_index]] != loser_container) assignment_error <<- TRUE
          containers[[winner_index]] <<- winner_container
          containers[[loser_index]] <<- loser_container
        }
      }
    }
    apply_outcomes("league_a_quarter_final", "quarter_final_winner", "quarter_final_loser")
    apply_outcomes("a_b_playoff", "a_b_band", "a_relegation_band")
    apply_outcomes("b_c_playoff", "b_c_band", "b_relegation_band")
    apply_outcomes("c_d_playoff", "c_d_band", "c_relegation_band")
    if (assignment_error || anyNA(containers)) return(uefa_nl_rank_final_blocked(rankings, unique(c(assignment_missing, "stage_participants")), rules))
    starts <- c(quarter_final_winner = 1L, quarter_final_loser = 5L, a_b_band = 9L, a_relegation_band = 17L, b_c_band = 25L, b_relegation_band = 33L, c_stable_band = 41L, c_d_band = 45L, c_relegation_band = 49L, d_stable_band = 53L)
    widths <- c(quarter_final_winner = 4L, quarter_final_loser = 4L, a_b_band = 8L, a_relegation_band = 8L, b_c_band = 8L, b_relegation_band = 8L, c_stable_band = 4L, c_d_band = 4L, c_relegation_band = 4L, d_stable_band = 3L)
    final_rank <- rep(NA_integer_, nrow(rankings))
    for (container in names(starts)) {
      indexes <- which(containers == container)
      if (!length(indexes)) next
      if (length(indexes) > widths[[container]]) return(uefa_nl_rank_final_blocked(rankings, "article_19_rank_band", rules))
      ordered <- indexes[order(rankings$interim_rank[indexes], rankings$team_id[indexes], method = "radix")]
      final_rank[ordered] <- starts[[container]] + seq_along(ordered) - 1L
    }
    if (anyNA(final_rank)) return(uefa_nl_rank_final_blocked(rankings, "article_19_rank_band", rules))
    if (final_complete) {
      final_index <- match(final_teams, rankings$team_id)
      final_rank[final_index] <- seq_along(final_teams)
      if (anyDuplicated(final_rank)) return(uefa_nl_rank_final_blocked(rankings, "final_stage_rank_overwrite", rules))
    }
    rankings$final_overall_rank <- as.integer(final_rank)
    rankings$computed_rank <- rankings$final_overall_rank
    rankings$ranking_scope <- "final_overall"
    rankings$ranking_stage <- if (final_complete) "final_overall" else "final_overall_pre_finals"
    rankings$final_ranking_status <- "ready"
    rankings$final_stage_status <- if (final_complete) "completed" else "pre_finals"
  }
  rankings$ordering_status <- "ready"
  rankings$missing_rule_input <- ""
  rankings$block_status <- "not_blocked"
  rankings$blocked <- FALSE
  rankings$suppression_reason <- "none"
  rankings$ruleset_version <- rules$ruleset_version
  rankings$ruleset_sha256 <- uefa_nl_ruleset_sha256(rules)
  rankings <- rankings[order(rankings$final_overall_rank, rankings$team_id, method = "radix"), , drop = FALSE]
  uefa_nl_rank_finalize(rankings, rules)
}

uefa_nl_transition_row <- function(
    edition_id, stage_id, transition_type, league = NA_character_, higher_league = NA_character_, lower_league = NA_character_,
    higher_league_team_id = NA_character_, lower_league_team_id = NA_character_, team_id = NA_character_,
    higher_league_rank = NA_integer_, lower_league_rank = NA_integer_, group_id = NA_character_, group_position = NA_integer_,
    interim_rank = NA_integer_, first_leg_home_team_id = NA_character_, eligibility_status = "not_applicable",
    selection_status = "selected", unresolved_reason = "", cd_playoff_status = "not_applicable", cancellation_reason = "",
    retained_next_edition_league = NA_character_, retained_next_edition_rank = NA_integer_,
    playoff_eligibility_probability = NA_real_, playoff_win_probability = NA_real_, playoff_loss_probability = NA_real_, rules = uefa_nl_2026_27_rules()) {
  data.frame(
    edition_id = as.character(edition_id), stage_id = as.character(stage_id), transition_type = as.character(transition_type),
    ranking_scope = "interim_overall", league = as.character(league), higher_league = as.character(higher_league), lower_league = as.character(lower_league),
    higher_league_team_id = as.character(higher_league_team_id), lower_league_team_id = as.character(lower_league_team_id), team_id = as.character(team_id),
    higher_league_rank = as.integer(higher_league_rank), lower_league_rank = as.integer(lower_league_rank), group_id = as.character(group_id),
    group_position = as.integer(group_position), interim_rank = as.integer(interim_rank), first_leg_home_team_id = as.character(first_leg_home_team_id),
    eligibility_status = as.character(eligibility_status), selection_status = as.character(selection_status), unresolved_reason = as.character(unresolved_reason),
    cd_playoff_status = as.character(cd_playoff_status), cancellation_reason = as.character(cancellation_reason),
    retained_next_edition_league = as.character(retained_next_edition_league), retained_next_edition_rank = as.integer(retained_next_edition_rank),
    playoff_eligibility_probability = as.numeric(playoff_eligibility_probability), playoff_win_probability = as.numeric(playoff_win_probability), playoff_loss_probability = as.numeric(playoff_loss_probability),
    ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_nl_ruleset_sha256(rules), row_sha256 = NA_character_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_nl_transition_eligibility <- function(table, candidate_ids) {
  if (is.null(table) || !is.data.frame(table) || !"team_id" %in% names(table)) return(list(status = "unresolved_external_eligibility", complete = FALSE, qualifying = character(), reason = "euro_playoff_eligibility_missing"))
  fields <- intersect(c("qualifies_for_euro_playoff", "euro_playoff_eligibility", "eligible", "qualifies"), names(table))
  if (!length(fields)) return(list(status = "unresolved_external_eligibility", complete = FALSE, qualifying = character(), reason = "euro_playoff_eligibility_missing"))
  ids <- trimws(as.character(table$team_id))
  if (any(is.na(ids) | !nzchar(ids)) || anyDuplicated(ids)) return(list(status = "unresolved_external_eligibility", complete = FALSE, qualifying = character(), reason = "euro_playoff_eligibility_missing"))
  values <- table[[fields[[1L]]]]
  if (!is.logical(values)) {
    text <- tolower(trimws(as.character(values)))
    parsed <- rep(NA, length(text))
    parsed[text %in% c("true", "t", "1", "yes", "y", "qualifies", "eligible")] <- TRUE
    parsed[text %in% c("false", "f", "0", "no", "n", "does_not_qualify", "ineligible")] <- FALSE
    values <- parsed
  }
  positions <- match(candidate_ids, ids)
  if (any(is.na(positions)) || any(is.na(values[positions]))) return(list(status = "unresolved_external_eligibility", complete = FALSE, qualifying = character(), reason = "euro_playoff_eligibility_missing"))
  qualifying <- candidate_ids[as.logical(values[positions])]
  list(status = if (length(qualifying)) "cancellation_required" else "eligible", complete = TRUE, qualifying = qualifying, reason = "")
}

uefa_nl_resolve_cd_playoff_cancellation <- function(
    interim_rankings,
    euro_playoff_eligibility,
    rules = uefa_nl_2026_27_rules()) {
  rules <- uefa_nl_rank_rules(rules)
  rankings <- uefa_nl_rank_bind_group_standings(interim_rankings)
  if (!"interim_rank" %in% names(rankings) && "interim_overall_rank" %in% names(rankings)) rankings$interim_rank <- as.integer(rankings$interim_overall_rank)
  required <- c("team_id", "league", "interim_rank")
  if (!all(required %in% names(rankings))) stop("Nations League C/D cancellation requires team_id, league, and interim_rank", call. = FALSE)
  rankings$league <- toupper(trimws(as.character(rankings$league)))
  rankings$team_id <- trimws(as.character(rankings$team_id))
  rankings$interim_rank <- suppressWarnings(as.integer(as.character(rankings$interim_rank)))
  if (any(is.na(rankings$team_id) | !nzchar(rankings$team_id)) || anyDuplicated(rankings$team_id)) stop("Nations League C/D cancellation rankings have missing or duplicate team IDs", call. = FALSE)
  if (anyDuplicated(rankings$interim_rank[!is.na(rankings$interim_rank)])) stop("Nations League C/D cancellation rankings have duplicate interim ranks", call. = FALSE)
  edition_id <- if ("edition_id" %in% names(rankings) && nrow(rankings)) as.character(rankings$edition_id[[1L]]) else rules$edition_id
  targets <- data.frame(
    league = c("C", "C", "D", "D"),
    interim_rank = c(46L, 47L, 50L, 51L),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  candidate_targets <- data.frame(
    league = c("C", "C", "D", "D"),
    interim_rank = c(45L, 46L, 51L, 52L),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  lookup <- function(league, rank) rankings[rankings$league == league & rankings$interim_rank == rank, , drop = FALSE]
  candidate_rows <- do.call(rbind, lapply(seq_len(nrow(candidate_targets)), function(index) {
    row <- lookup(candidate_targets$league[[index]], candidate_targets$interim_rank[[index]])
    if (!nrow(row)) return(data.frame(team_id = NA_character_, league = candidate_targets$league[[index]], interim_rank = candidate_targets$interim_rank[[index]], stringsAsFactors = FALSE, check.names = FALSE))
    data.frame(team_id = as.character(row$team_id[[1L]]), league = candidate_targets$league[[index]], interim_rank = candidate_targets$interim_rank[[index]], stringsAsFactors = FALSE, check.names = FALSE)
  }))
  candidate_ids <- as.character(candidate_rows$team_id)
  eligibility_complete <- all(!is.na(candidate_ids) & nzchar(candidate_ids))
  eligibility <- if (eligibility_complete) uefa_nl_transition_eligibility(euro_playoff_eligibility, candidate_ids) else list(status = "unresolved_external_eligibility", complete = FALSE, qualifying = character(), reason = "euro_playoff_eligibility_missing")
  make_row <- function(target, status, selection_status, cd_status, reason = "", cancellation_reason = "") {
    source <- lookup(target$league, target$interim_rank)
    team_id <- if (nrow(source)) as.character(source$team_id[[1L]]) else NA_character_
    row <- uefa_nl_transition_row(
      edition_id = edition_id,
      stage_id = "c_d_playoff",
      transition_type = "c_d_playoff_cancellation",
      league = target$league,
      higher_league = "C",
      lower_league = "D",
      higher_league_team_id = if (target$league == "C") team_id else NA_character_,
      lower_league_team_id = if (target$league == "D") team_id else NA_character_,
      team_id = team_id,
      higher_league_rank = if (target$league == "C") target$interim_rank else NA_integer_,
      lower_league_rank = if (target$league == "D") target$interim_rank else NA_integer_,
      group_id = if (nrow(source) && "group_id" %in% names(source)) source$group_id[[1L]] else NA_character_,
      group_position = if (nrow(source) && "group_position" %in% names(source)) source$group_position[[1L]] else NA_integer_,
      interim_rank = target$interim_rank,
      first_leg_home_team_id = NA_character_,
      eligibility_status = status,
      selection_status = selection_status,
      unresolved_reason = reason,
      cd_playoff_status = cd_status,
      cancellation_reason = cancellation_reason,
      retained_next_edition_league = if (cd_status == "cancelled") target$league else NA_character_,
      retained_next_edition_rank = if (cd_status == "cancelled") target$interim_rank else NA_integer_,
      playoff_eligibility_probability = NA_real_,
      playoff_win_probability = NA_real_,
      playoff_loss_probability = NA_real_,
      rules = rules
    )
    row$stage_status <- if (cd_status == "cancelled") "suppressed" else "unresolved"
    row$outcome_type <- if (cd_status == "cancelled") "retained_next_edition" else "unresolved_external_eligibility"
    row$suppression_reason <- if (cd_status == "cancelled") "c_d_playoff_cancelled" else ""
    row$transition_key <- paste(row$stage_id, row$transition_type, row$league, row$interim_rank, row$team_id, sep = "::")
    row$row_sha256 <- uefa_nl_rules_row_sha256(row[, setdiff(names(row), "row_sha256"), drop = FALSE])
    row
  }

  if (!eligibility$complete) {
    output <- do.call(rbind, lapply(seq_len(nrow(targets)), function(index) {
      make_row(targets[index, , drop = FALSE], "unresolved_external_eligibility", "unresolved", "unresolved", "euro_playoff_eligibility_missing")
    }))
    attr(output, "cancellation_status") <- "unresolved_external_eligibility"
    row.names(output) <- NULL
    return(output)
  }
  if (!identical(eligibility$status, "cancellation_required")) {
    empty <- make_row(targets[1L, , drop = FALSE], "eligible", "selected", "contested")
    empty <- empty[0, , drop = FALSE]
    attr(empty, "cancellation_status") <- "not_required"
    return(empty)
  }
  output <- do.call(rbind, lapply(seq_len(nrow(targets)), function(index) {
    make_row(targets[index, , drop = FALSE], "cancellation_required", "retained", "cancelled", cancellation_reason = "due_participant_qualifies_for_euro_2028_playoffs")
  }))
  attr(output, "cancellation_status") <- "cancelled"
  row.names(output) <- NULL
  output
}

uefa_nl_select_transition_slots <- function(
    interim_rankings,
    euro_playoff_eligibility = NULL,
    rules = uefa_nl_2026_27_rules()) {
  rules <- uefa_nl_rank_rules(rules)
  rankings <- uefa_nl_rank_bind_group_standings(interim_rankings)
  if (!all(c("team_id", "league", "interim_rank") %in% names(rankings))) stop("Nations League transition selectors require team_id, league, and interim_rank", call. = FALSE)
  rankings$league <- toupper(as.character(rankings$league))
  edition_id <- if ("edition_id" %in% names(rankings) && nrow(rankings)) as.character(rankings$edition_id[[1L]]) else rules$edition_id
  lookup_rank <- function(league, rank) rankings[rankings$league == league & as.integer(rankings$interim_rank) == as.integer(rank), , drop = FALSE]
  ordering_status <- if ("ordering_status" %in% names(rankings)) as.character(rankings$ordering_status) else rep("ready", nrow(rankings))
  effective_rank <- if ("computed_rank" %in% names(rankings)) rankings$computed_rank else rankings$interim_rank
  blocked_league <- function(league) any(rankings$league == league & (is.na(ordering_status) | ordering_status == "blocked" | is.na(effective_rank)))
  league_order <- c(A = 1L, B = 2L, C = 3L, D = 4L)
  higher_lower <- function(source, target) {
    if (league_order[[target]] < league_order[[source]]) {
      list(higher = target, lower = source)
    } else {
      list(higher = source, lower = target)
    }
  }
  rows <- list()
  index <- 0L
  append_row <- function(row) { index <<- index + 1L; rows[[index]] <<- row }
  make_direct <- function(source, target, transition_type, source_row = NULL, source_rank = NA_integer_, group_position = NA_integer_) {
    blocked <- is.null(source_row) || !nrow(source_row) || blocked_league(source)
    leagues <- higher_lower(source, target)
    if (blocked) {
      append_row(uefa_nl_transition_row(edition_id, "direct_transition", transition_type, source, higher_league = leagues$higher, lower_league = leagues$lower, interim_rank = source_rank, group_position = group_position, eligibility_status = "unresolved", selection_status = "unresolved", unresolved_reason = "missing_rule_input", rules = rules))
      return(invisible(NULL))
    }
    row <- source_row[1L, , drop = FALSE]
    higher <- leagues$higher
    lower <- leagues$lower
    higher_id <- if (source == higher) row$team_id[[1L]] else NA_character_
    lower_id <- if (source == lower) row$team_id[[1L]] else NA_character_
    append_row(uefa_nl_transition_row(edition_id, "direct_transition", transition_type, source, higher, lower, higher_id, lower_id, row$team_id[[1L]], if (source == higher) row$interim_rank[[1L]] else NA_integer_, if (source == lower) row$interim_rank[[1L]] else NA_integer_, row$group_id[[1L]] %||% NA_character_, row$group_position[[1L]] %||% group_position, row$interim_rank[[1L]], eligibility_status = "not_applicable", selection_status = "selected", rules = rules))
  }
  for (league in c("B", "C", "D")) {
    target <- c(B = "A", C = "B", D = "C")[[league]]
    winners <- rankings[rankings$league == league & rankings$group_position == 1L, , drop = FALSE]
    if (nrow(winners)) for (row_index in seq_len(nrow(winners))) make_direct(league, target, "direct_promotion", winners[row_index, , drop = FALSE], winners$interim_rank[[row_index]], 1L)
  }
  for (league in c("A", "B")) {
    target <- c(A = "B", B = "C")[[league]]
    fourth <- rankings[rankings$league == league & rankings$group_position == 4L, , drop = FALSE]
    if (nrow(fourth)) for (row_index in seq_len(nrow(fourth))) make_direct(league, target, "direct_relegation", fourth[row_index, , drop = FALSE], fourth$interim_rank[[row_index]], 4L)
  }
  for (rank in c(47L, 48L)) {
    row <- lookup_rank("C", rank)
    make_direct("C", "D", "direct_relegation", row, rank, if (nrow(row)) row$group_position[[1L]] else NA_integer_)
  }
  make_pairs <- function(stage_id, high_league, low_league, high_ranks, low_ranks, transition_type, conditional = FALSE) {
    eligibility <- if (conditional) uefa_nl_transition_eligibility(euro_playoff_eligibility, character()) else list(status = "eligible", complete = TRUE, qualifying = character(), reason = "")
    for (pair_index in seq_along(high_ranks)) {
      high_rank <- high_ranks[[pair_index]]
      low_rank <- low_ranks[[pair_index]]
      high <- lookup_rank(high_league, high_rank)
      low <- lookup_rank(low_league, low_rank)
      high_rank_value <- if (nrow(high) && "computed_rank" %in% names(high)) high$computed_rank[[1L]] else if (nrow(high)) high$interim_rank[[1L]] else NA_integer_
      low_rank_value <- if (nrow(low) && "computed_rank" %in% names(low)) low$computed_rank[[1L]] else if (nrow(low)) low$interim_rank[[1L]] else NA_integer_
      upstream_blocked <- blocked_league(high_league) || blocked_league(low_league) || !nrow(high) || !nrow(low) || is.na(high_rank_value) || is.na(low_rank_value)
      candidate_ids <- c(if (nrow(high)) as.character(high$team_id[[1L]]) else character(), if (nrow(low)) as.character(low$team_id[[1L]]) else character())
      if (conditional) eligibility <- uefa_nl_transition_eligibility(euro_playoff_eligibility, candidate_ids)
      selection_status <- if (upstream_blocked) "unresolved" else if (!eligibility$complete) "unresolved" else if (eligibility$status == "cancellation_required") "cancelled" else "selected"
      eligibility_status <- if (upstream_blocked) "unresolved" else eligibility$status
      unresolved_reason <- if (upstream_blocked) "missing_rule_input" else if (!eligibility$complete) eligibility$reason else ""
      cd_status <- if (!conditional) "not_applicable" else if (selection_status == "cancelled") "cancelled" else if (selection_status == "selected") "contested" else "unresolved"
      cancellation_reason <- if (cd_status == "cancelled") "due_participant_qualifies_for_euro_2028_playoffs" else ""
      append_row(uefa_nl_transition_row(
        edition_id, stage_id, transition_type, high_league, high_league, low_league,
        if (!upstream_blocked && nrow(high)) high$team_id[[1L]] else NA_character_,
        if (!upstream_blocked && nrow(low)) low$team_id[[1L]] else NA_character_, NA_character_, high_rank, low_rank,
        if (nrow(high)) high$group_id[[1L]] else NA_character_, if (nrow(high)) high$group_position[[1L]] else NA_integer_,
        if (nrow(high)) high$interim_rank[[1L]] else high_rank,
        if (!upstream_blocked && nrow(low)) low$team_id[[1L]] else NA_character_,
        eligibility_status, selection_status, unresolved_reason, cd_status, cancellation_reason, rules = rules
      ))
    }
  }
  make_pairs("a_b_playoff", "A", "B", 9:12, 21:24, "a_b_playoff")
  make_pairs("b_c_playoff", "B", "C", 25:28, 37:40, "b_c_playoff")
  make_pairs("c_d_playoff", "C", "D", 45:46, 51:52, "c_d_playoff", conditional = TRUE)
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  output <- do.call(rbind, rows)
  cancellation <- uefa_nl_resolve_cd_playoff_cancellation(rankings, euro_playoff_eligibility, rules)
  if (nrow(cancellation) && any(cancellation$cd_playoff_status == "cancelled")) {
    output <- output[output$stage_id != "c_d_playoff", , drop = FALSE]
    for (field in setdiff(names(cancellation), names(output))) output[[field]] <- NA
    for (field in setdiff(names(output), names(cancellation))) cancellation[[field]] <- NA
    cancellation <- cancellation[, names(output), drop = FALSE]
    output <- rbind(output, cancellation)
  }
  output$transition_key <- paste(output$stage_id, output$higher_league_rank, output$lower_league_rank, output$higher_league_team_id, output$lower_league_team_id, sep = "::")
  output <- output[order(output$stage_id, output$higher_league_rank, output$lower_league_rank, output$transition_key, method = "radix"), , drop = FALSE]
  output$row_sha256 <- uefa_nl_rules_row_sha256(output[, setdiff(names(output), "row_sha256"), drop = FALSE])
  row.names(output) <- NULL
  output
}
