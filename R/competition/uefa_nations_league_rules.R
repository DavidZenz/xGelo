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
  if (any(as.character(output$edition_id) != as.character(edition_id))) stop("Nations League access list has a foreign edition", call. = FALSE)
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
  hits <- lapply(candidates, function(candidate) which(candidate == value))
  positions <- unique(unlist(hits, use.names = FALSE))
  if (length(positions) != 1L) return(NA_character_)
  as.character(groups$group_id[[positions[[1L]]]])
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
  scores <- lapply(score_fields, function(field) uefa_nl_stage_slot_score(values[[field]], field, allow_missing = !any(completed)))
  names(scores) <- score_fields
  if (any(completed)) {
    if (any(uefa_nl_stage_slot_value_missing(values$completed_at_utc[completed]))) stop("Completed Nations League stage slots require completed_at_utc", call. = FALSE)
    for (field in score_fields) if (any(is.na(scores[[field]][completed]))) stop("Completed Nations League stage slots require ", field, call. = FALSE)
    if (any(scores$final_home_goals[completed] != scores$regulation_home_goals[completed] + scores$extra_time_home_goals[completed]) ||
        any(scores$final_away_goals[completed] != scores$regulation_away_goals[completed] + scores$extra_time_away_goals[completed])) {
      stop("Nations League final goals must equal regulation plus extra-time goals", call. = FALSE)
    }
  }
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
