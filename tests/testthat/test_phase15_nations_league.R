library(testthat)

phase15_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

phase15_test_edition_id <- "uefa_nations_league_2026_27"
phase15_test_source_bundle_id <- "nl-2026-27-official-uefa-v2"
phase15_test_ruleset_version <- "uefa-nations-league-2026-27-v2"

phase15_test_sha256 <- function(value) {
  if (is.raw(value)) {
    bytes <- value
  } else {
    bytes <- charToRaw(paste0(value, collapse = ""))
  }
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase15_test_scalar_text <- function(value) {
  if (!length(value) || is.na(value[[1L]])) return("<NA>")
  if (inherits(value, "POSIXt")) {
    return(format(as.POSIXct(value[[1L]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  as.character(value[[1L]])
}

phase15_test_canonical_table <- function(data) {
  if (!is.data.frame(data)) stop("Phase 15 hash input must be a data frame", call. = FALSE)
  if (!ncol(data)) return(data)

  data <- data[, sort(names(data)), drop = FALSE]
  if (nrow(data) > 1L) {
    values <- lapply(data, function(column) {
      vapply(seq_along(column), function(index) {
        phase15_test_scalar_text(column[index])
      }, character(1))
    })
    data <- data[do.call(order, c(values, list(method = "radix"))), , drop = FALSE]
  }
  data
}

phase15_test_canonical_text <- function(data) {
  canonical <- phase15_test_canonical_table(data)
  paste(
    utils::capture.output(
      utils::write.table(
        canonical,
        file = "",
        sep = ",",
        quote = TRUE,
        row.names = FALSE,
        col.names = TRUE,
        na = "<NA>",
        qmethod = "double"
      )
    ),
    collapse = "\n"
  )
}

phase15_test_table_sha256 <- function(data) {
  phase15_test_sha256(phase15_test_canonical_text(data))
}

phase15_test_row_sha256 <- function(row) {
  phase15_test_table_sha256(as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE))
}

phase15_test_add_row_hashes <- function(data, hash_column = "row_sha256") {
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  data[[hash_column]] <- vapply(seq_len(nrow(data)), function(index) {
    phase15_test_row_sha256(data[index, setdiff(names(data), hash_column), drop = FALSE])
  }, character(1))
  data
}

phase15_test_tree_snapshot <- function(root) {
  if (!dir.exists(root)) return(setNames(character(), character()))
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  if (!length(files)) return(setNames(character(), character()))
  files <- files[!file.info(files)$isdir]
  if (!length(files)) return(setNames(character(), character()))
  relative <- substring(files, nchar(root) + 2L)
  hashes <- vapply(files, function(path) {
    phase15_test_sha256(readBin(path, what = "raw", n = file.info(path)$size))
  }, character(1))
  setNames(hashes, relative)
}

phase15_test_require_api <- function(api_name, envir = .GlobalEnv) {
  if (length(api_name) != 1L || !is.character(api_name) || !nzchar(api_name)) {
    stop("Phase 15 API name must be one non-empty string", call. = FALSE)
  }
  if (!exists(api_name, envir = envir, mode = "function", inherits = TRUE)) {
    stop(sprintf("missing Phase 15 API: %s", api_name), call. = FALSE)
  }
  get(api_name, envir = envir, mode = "function", inherits = TRUE)
}

phase15_test_source <- function(relative_path, envir = .GlobalEnv) {
  path <- file.path(phase15_test_project_root, relative_path)
  if (!file.exists(path)) {
    stop(sprintf("missing Phase 15 source file: %s", relative_path), call. = FALSE)
  }
  sys.source(path, envir = envir)
  invisible(path)
}

phase15_test_output_root <- local({
  registered <- new.env(parent = emptyenv())

  function(candidate = NULL) {
    temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
    if (is.null(candidate)) {
      candidate <- tempfile("phase15-outcomes-", tmpdir = temp_root)
    }
    candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    prefix <- paste0(temp_root, "/")
    if (!identical(candidate, temp_root) && !startsWith(candidate, prefix)) {
      stop("Phase 15 test output root must be a child of tempdir()", call. = FALSE)
    }
    if (!dir.create(candidate, recursive = TRUE, showWarnings = FALSE) && !dir.exists(candidate)) {
      stop("Phase 15 test output root could not be created", call. = FALSE)
    }
    assign(candidate, TRUE, envir = registered)
    structure(candidate, phase15_registered = TRUE)
  }
})

phase15_test_hash_token <- function(label) {
  phase15_test_sha256(paste0("phase15-test|", label))
}

phase15_test_team_id <- function(league, group_number, position) {
  sprintf("team-%s-%d-%d", tolower(league), as.integer(group_number), as.integer(position))
}

phase15_test_access_list <- function() {
  leagues <- c("A", "B", "C", "D")
  group_counts <- c(A = 4L, B = 4L, C = 4L, D = 2L)
  team_counts <- c(A = 4L, B = 4L, C = 4L, D = 3L)
  rows <- list()
  position <- 1L
  index <- 1L

  for (league in leagues) {
    for (group_number in seq_len(group_counts[[league]])) {
      for (team_position in seq_len(team_counts[[league]])) {
        team_id <- phase15_test_team_id(league, group_number, team_position)
        rows[[index]] <- data.frame(
          edition_id = phase15_test_edition_id,
          team_id = team_id,
          access_list_position = as.integer(position),
          league_id = league,
          group_id = paste0(league, group_number),
          draw_pot = sprintf("%s-pot-%d", league, team_position),
          group_formation_status = "validated",
          source_artifact_id = paste0("artifact-access-list-", tolower(league)),
          status = "admitted",
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
        position <- position + 1L
        index <- index + 1L
      }
    }
  }
  admitted <- do.call(rbind, rows)

  current_source <- admitted
  current_source$access_list_position <- as.integer(NA)
  current_source$draw_pot <- NA_character_
  current_source$group_formation_status <- "unresolved_access_list"
  current_source$status <- "unresolved_access_list"
  current_source$source_artifact_id <- "artifact-groups-v2"

  list(admitted = admitted, current_source = current_source)
}

phase15_test_group_formation <- function() {
  access <- phase15_test_access_list()
  rows <- access$admitted
  list(
    seed = 15013L,
    status = "validated",
    rows = rows,
    reversed_rows = rows[nrow(rows):1L, , drop = FALSE],
    table_sha256 = phase15_test_table_sha256(rows),
    current_source = access$current_source
  )
}

phase15_test_group_matches <- function(team_ids, league_id, group_id, start_day = 1L) {
  pairs <- utils::combn(team_ids, 2L)
  rows <- vector("list", ncol(pairs) * 2L)
  row_index <- 1L
  match_number <- 1L

  for (pair_index in seq_len(ncol(pairs))) {
    for (leg in 1:2) {
      home_team_id <- if (leg == 1L) pairs[1L, pair_index] else pairs[2L, pair_index]
      away_team_id <- if (leg == 1L) pairs[2L, pair_index] else pairs[1L, pair_index]
      match_id <- sprintf("%s-match-%02d", group_id, match_number)
      rows[[row_index]] <- data.frame(
        edition_id = phase15_test_edition_id,
        source_bundle_id = phase15_test_source_bundle_id,
        league_id = league_id,
        group_id = group_id,
        match_id = match_id,
        fixture_id = match_id,
        source_fixture_id = paste0("source-", match_id),
        home_team_id = home_team_id,
        away_team_id = away_team_id,
        scheduled_at_utc = sprintf("2026-09-%02dT18:45:00Z", start_day + match_number - 1L),
        completed_at_utc = sprintf("2026-09-%02dT20:40:00Z", start_day + match_number - 1L),
        evidence_completed_at_utc = sprintf("2026-09-%02dT20:40:00Z", start_day + match_number - 1L),
        source_status = "completed",
        match_status = "completed",
        completion_method = "regulation",
        counts_for_standings = TRUE,
        counts_for_form = TRUE,
        regulation_home_goals = 1L,
        regulation_away_goals = 1L,
        extra_time_home_goals = 0L,
        extra_time_away_goals = 0L,
        penalty_shootout_home_goals = as.integer(NA),
        penalty_shootout_away_goals = as.integer(NA),
        final_home_goals = 1L,
        final_away_goals = 1L,
        home_goals = 1L,
        away_goals = 1L,
        source_artifact_id = "artifact-results-v2",
        source_url = "https://example.test/phase15/results",
        raw_sha256 = phase15_test_hash_token("results-raw"),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      row_index <- row_index + 1L
      match_number <- match_number + 1L
    }
  }
  do.call(rbind, rows)
}

phase15_test_group_fixture <- function(league_id, group_number, team_count) {
  group_id <- paste0(league_id, group_number)
  team_ids <- vapply(seq_len(team_count), function(position) {
    phase15_test_team_id(league_id, group_number, position)
  }, character(1))
  matches <- phase15_test_group_matches(team_ids, league_id, group_id)
  played <- if (team_count == 3L) 4L else 6L
  tied_count <- min(3L, team_count)
  standings <- data.frame(
    edition_id = phase15_test_edition_id,
    league_id = league_id,
    league = league_id,
    group_id = group_id,
    team_id = team_ids,
    group_position = as.integer(c(seq_len(tied_count), if (team_count > tied_count) team_count else integer())),
    played = as.integer(c(rep(played, tied_count), if (team_count > tied_count) played else integer())),
    wins = as.integer(c(rep(if (team_count == 3L) 0L else 2L, tied_count), if (team_count > tied_count) 0L else integer())),
    draws = as.integer(c(rep(if (team_count == 3L) 3L else 1L, tied_count), if (team_count > tied_count) 2L else integer())),
    losses = as.integer(c(rep(1L, tied_count), if (team_count > tied_count) 4L else integer())),
    goals_for = as.integer(c(rep(if (team_count == 3L) 4L else 5L, tied_count), if (team_count > tied_count) 2L else integer())),
    goals_against = as.integer(c(rep(if (team_count == 3L) 4L else 4L, tied_count), if (team_count > tied_count) 8L else integer())),
    goal_difference = as.integer(c(rep(0L, tied_count), if (team_count > tied_count) -6L else integer())),
    points = as.integer(c(rep(if (team_count == 3L) 3L else 7L, tied_count), if (team_count > tied_count) 2L else integer())),
    away_goals = as.integer(c(rep(if (team_count == 3L) 2L else 2L, tied_count), if (team_count > tied_count) 0L else integer())),
    wins_away = as.integer(c(rep(if (team_count == 3L) 0L else 1L, tied_count), if (team_count > tied_count) 0L else integer())),
    discipline_points = as.integer(seq_len(team_count)),
    access_list_position = as.integer(phase15_test_access_list()$admitted$access_list_position[
      phase15_test_access_list()$admitted$team_id %in% team_ids
    ]),
    counted_match_ids = vapply(team_ids, function(team_id) {
      paste(matches$match_id[matches$home_team_id == team_id | matches$away_team_id == team_id], collapse = ";")
    }, character(1)),
    excluded_match_ids = "",
    ordering_status = "ready",
    missing_rule_input = "",
    suppression_reason = "none",
    source_artifact_id = "artifact-standings-v2",
    source_bundle_id = phase15_test_source_bundle_id,
    ruleset_version = phase15_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    edition_id = phase15_test_edition_id,
    league_id = league_id,
    group_id = group_id,
    team_ids = team_ids,
    standings = standings,
    matches = matches,
    discipline_points = standings[, c("team_id", "discipline_points", "source_artifact_id"), drop = FALSE],
    access_list = phase15_test_access_list()$admitted[
      phase15_test_access_list()$admitted$team_id %in% team_ids,
      ,
      drop = FALSE
    ],
    expected_group_positions = standings[, c("team_id", "group_position"), drop = FALSE],
    tie_break_order = c(
      "head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals",
      "recursive_tied_subset", "overall_goal_difference", "overall_goals",
      "overall_away_goals", "wins", "away_wins", "discipline_points",
      "access_list_position"
    )
  )
}

phase15_test_three_team_group <- function() {
  phase15_test_group_fixture("D", 1L, 3L)
}

phase15_test_four_team_group <- function() {
  phase15_test_group_fixture("A", 1L, 4L)
}

phase15_test_two_leg_invariants <- function(rows, lower_league_team_id = NULL) {
  if (!is.data.frame(rows) || nrow(rows) != 2L) {
    stop("two-leg fixture must contain exactly two rows", call. = FALSE)
  }
  if (!setequal(as.integer(rows$leg_number), 1:2)) {
    stop("two-leg fixture must contain leg 1 and leg 2", call. = FALSE)
  }
  participants <- unique(c(as.character(rows$home_team_id), as.character(rows$away_team_id)))
  unordered_pairs <- paste(
    pmin(as.character(rows$home_team_id), as.character(rows$away_team_id)),
    pmax(as.character(rows$home_team_id), as.character(rows$away_team_id)),
    sep = "|"
  )
  if (length(participants) != 2L || length(unique(unordered_pairs)) != 1L) {
    stop("two-leg fixture must use the same unordered participants", call. = FALSE)
  }
  if (length(unique(as.character(rows$home_team_id))) != 2L ||
      length(unique(as.character(rows$away_team_id))) != 2L) {
    stop("each two-leg participant must host exactly once", call. = FALSE)
  }
  if (!is.null(lower_league_team_id)) {
    first_leg <- rows[which(as.integer(rows$leg_number) == 1L), , drop = FALSE]
    if (!identical(as.character(first_leg$home_team_id[[1L]]), as.character(lower_league_team_id))) {
      stop("lower-league participant must host leg 1", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase15_test_two_leg_pair <- function() {
  higher <- "team-a-playoff"
  lower <- "team-b-playoff"
  valid <- data.frame(
    edition_id = phase15_test_edition_id,
    stage_id = "a_b_playoff",
    round_id = "play_off",
    tie_id = "a-b-tie-1",
    leg_number = as.integer(c(1L, 2L)),
    higher_league_team_id = higher,
    lower_league_team_id = lower,
    home_team_id = c(lower, higher),
    away_team_id = c(higher, lower),
    participant_slot_home = c("B-rank-21", "A-rank-9"),
    participant_slot_away = c("A-rank-9", "B-rank-21"),
    source_fixture_id = c("source-ab-leg-1", "source-ab-leg-2"),
    source_artifact_id = "artifact-stage-capture-v1",
    stage_status = "official",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  invalid_duplicate_home <- valid
  invalid_duplicate_home$home_team_id <- c(lower, lower)
  list(
    valid = valid,
    invalid_duplicate_home = invalid_duplicate_home,
    higher_league_team_id = higher,
    lower_league_team_id = lower,
    expected_first_leg_home_team_id = lower
  )
}

phase15_test_host_association <- function() {
  data.frame(
    association_id = "association-host",
    host_team_id = "team-a-host",
    semi_final_1_id = "league-a-semi-final-1",
    semi_final_2_id = "league-a-semi-final-2",
    semi_final_1_team_a_policy = "host_association_first",
    semi_final_2_team_a_policy = "other_association",
    final_team_a_source = "semi_final_1_winner",
    third_place_team_a_source = "semi_final_1_loser",
    expected_host_semi_final_id = "league-a-semi-final-1",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase15_test_stage_row <- function(
    stage_id,
    round_id,
    leg_number,
    source_fixture_id,
    home_team_id,
    away_team_id,
    participant_slot_home,
    participant_slot_away,
    regulation_home_goals,
    regulation_away_goals,
    extra_time_home_goals = 0L,
    extra_time_away_goals = 0L,
    penalty_shootout_home_goals = as.integer(NA),
    penalty_shootout_away_goals = as.integer(NA)
) {
  data.frame(
    edition_id = phase15_test_edition_id,
    stage_id = stage_id,
    round_id = round_id,
    leg_number = as.integer(leg_number),
    source_fixture_id = source_fixture_id,
    home_team_id = home_team_id,
    away_team_id = away_team_id,
    participant_slot_home = participant_slot_home,
    participant_slot_away = participant_slot_away,
    scheduled_at_utc = sprintf("2027-03-%02dT19:45:00Z", 10L + as.integer(leg_number)),
    source_status = "FINISHED",
    stage_status = "completed",
    source_artifact_id = "artifact-stage-capture-v1",
    source_url = "https://example.test/phase15/stage-capture",
    retrieved_at_utc = "2027-04-01T12:00:00Z",
    raw_sha256 = phase15_test_hash_token("stage-capture-raw"),
    regulation_home_goals = as.integer(regulation_home_goals),
    regulation_away_goals = as.integer(regulation_away_goals),
    extra_time_home_goals = as.integer(extra_time_home_goals),
    extra_time_away_goals = as.integer(extra_time_away_goals),
    penalty_shootout_home_goals = as.integer(penalty_shootout_home_goals),
    penalty_shootout_away_goals = as.integer(penalty_shootout_away_goals),
    final_home_goals = as.integer(regulation_home_goals + extra_time_home_goals),
    final_away_goals = as.integer(regulation_away_goals + extra_time_away_goals),
    completed_at_utc = "2027-04-01T21:45:00Z",
    source_bundle_id = phase15_test_source_bundle_id,
    capture_id = "nl-2026-27-stage-capture-v1",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase15_test_completed_stage_capture <- function() {
  rows <- list(
    phase15_test_stage_row("league_a_quarter_final", "quarter_final", 1L, "source-qf-1", "team-a-1-1", "team-a-1-2", "A-winner-A1", "A-runner-up-A2", 1L, 0L),
    phase15_test_stage_row("league_a_quarter_final", "quarter_final", 2L, "source-qf-2", "team-a-1-2", "team-a-1-1", "A-runner-up-A2", "A-winner-A1", 0L, 0L, 1L, 0L),
    phase15_test_stage_row("league_a_semi_final", "semi_final", 1L, "source-sf-1", "team-a-host", "team-a-1-3", "QF-winner-1", "QF-winner-2", 0L, 0L, 0L, 0L, 5L, 4L),
    phase15_test_stage_row("league_a_semi_final", "semi_final", 2L, "source-sf-2", "team-a-1-4", "team-a-host", "QF-winner-3", "QF-winner-4", 2L, 1L),
    phase15_test_stage_row("league_a_final", "final", 1L, "source-final-1", "team-a-host", "team-a-1-4", "semi_final_1_winner", "semi_final_2_winner", 1L, 1L, 1L, 0L),
    phase15_test_stage_row("a_b_playoff", "play_off", 1L, "source-ab-1", "team-b-2-1", "team-a-2-1", "B-rank-21", "A-rank-9", 1L, 0L),
    phase15_test_stage_row("a_b_playoff", "play_off", 2L, "source-ab-2", "team-a-2-1", "team-b-2-1", "A-rank-9", "B-rank-21", 2L, 1L),
    phase15_test_stage_row("b_c_playoff", "play_off", 1L, "source-bc-1", "team-c-2-1", "team-b-3-1", "C-rank-37", "B-rank-25", 0L, 0L, 0L, 0L, 4L, 3L),
    phase15_test_stage_row("b_c_playoff", "play_off", 2L, "source-bc-2", "team-b-3-1", "team-c-2-1", "B-rank-25", "C-rank-37", 1L, 0L),
    phase15_test_stage_row("c_d_playoff", "play_off", 1L, "source-cd-1", "team-d-2-1", "team-c-3-1", "D-rank-51", "C-rank-45", 0L, 0L),
    phase15_test_stage_row("c_d_playoff", "play_off", 2L, "source-cd-2", "team-c-3-1", "team-d-2-1", "C-rank-45", "D-rank-51", 0L, 1L, 0L, 1L)
  )
  capture <- do.call(rbind, rows)
  rownames(capture) <- NULL
  phase15_test_add_row_hashes(capture)
}

phase15_test_calibrated_forecast <- function() {
  probabilities <- c(home = 0.45, draw = 0.25, away = 0.30)
  fixture_id <- "nl-2026-27-open-fixture-1"
  score_distribution_id <- "score-grid-nl-open-1"
  grid <- expand.grid(home_goals = 0:3, away_goals = 0:3)
  grid$outcome_class <- ifelse(
    grid$home_goals > grid$away_goals,
    "home",
    ifelse(grid$home_goals == grid$away_goals, "draw", "away")
  )
  grid$probability <- vapply(seq_len(nrow(grid)), function(index) {
    probabilities[[grid$outcome_class[[index]]]] /
      sum(grid$outcome_class == grid$outcome_class[[index]])
  }, numeric(1))
  grid$score_distribution_id <- score_distribution_id
  grid$support_max_home <- 3L
  grid$support_max_away <- 3L
  grid$raw_tail_mass <- 0
  grid$normalized <- TRUE
  grid$edition_id <- phase15_test_edition_id
  grid$fixture_id <- fixture_id
  grid <- grid[, c(
    "edition_id", "fixture_id", "score_distribution_id", "home_goals", "away_goals",
    "probability", "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )]

  lineage <- list(
    model_sha256 = phase15_test_hash_token("model"),
    release_manifest_sha256 = phase15_test_hash_token("release-manifest"),
    release_selector_sha256 = phase15_test_hash_token("release-selector"),
    feature_cutoff_sha256 = phase15_test_hash_token("feature-cutoff"),
    source_bundle_sha256 = phase15_test_hash_token("source-bundle")
  )
  forecast <- data.frame(
    edition_id = phase15_test_edition_id,
    fixture_id = fixture_id,
    match_id = fixture_id,
    home_team_id = "team-a-1-1",
    away_team_id = "team-a-1-2",
    kickoff_utc = "2026-09-05T18:45:00Z",
    forecast_status = "available",
    suppression_reason = "none",
    primary_probability_view = "calibrated_1x2",
    p_home = probabilities[["home"]],
    p_draw = probabilities[["draw"]],
    p_away = probabilities[["away"]],
    expected_home_goals = 1.40,
    expected_away_goals = 1.10,
    score_distribution_id = score_distribution_id,
    model_id = "phase14-open-nb",
    model_sha256 = lineage$model_sha256,
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    release_manifest_sha256 = lineage$release_manifest_sha256,
    release_selector_sha256 = lineage$release_selector_sha256,
    model_data_cutoff = "2026-06-10",
    feature_cutoff_utc = "2026-09-05T18:44:59Z",
    feature_cutoff_sha256 = lineage$feature_cutoff_sha256,
    source_bundle_id = phase15_test_source_bundle_id,
    source_bundle_sha256 = lineage$source_bundle_sha256,
    competition_form_status = "unavailable",
    all_international_form_status = "unavailable",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  forecast <- phase15_test_add_row_hashes(forecast)
  forecast_status <- forecast[, c(
    "edition_id", "fixture_id", "forecast_status", "suppression_reason",
    "primary_probability_view", "score_distribution_id", "model_release_id",
    "model_sha256", "feature_cutoff_utc", "source_bundle_id", "source_bundle_sha256",
    "row_sha256"
  ), drop = FALSE]
  list(
    probabilities = probabilities,
    forecast_status = forecast_status,
    forecasts = forecast,
    score_distributions = grid,
    expected_category_mass = probabilities,
    score_support = 0:3
  )
}

phase15_test_contract_sections <- list(
  `15-01` = c("topology", "stage_slots", "source_admission", "group_formation"),
  `15-02` = c("group_ranking", "interim_ranking", "final_ranking", "transitions"),
  `15-03` = c("sampling", "two_leg_resolution", "single_leg_resolution", "draw_policies", "simulation"),
  `15-04` = c("outcomes_schema", "stage_capture", "forecast_form_pass_through"),
  `15-05` = c("writer", "dry_run", "replay"),
  `15-06` = c("production_acceptance", "no_leakage", "registered_root")
)

test_that("Wave 0 harness resolves the repository root and fails precisely for missing APIs", {
  expect_true(dir.exists(phase15_test_project_root))
  expect_true(file.exists(file.path(phase15_test_project_root, "AGENTS.md")))
  expect_error(
    phase15_test_require_api("uefa_nl_wave0_missing_api"),
    "missing Phase 15 API: uefa_nl_wave0_missing_api"
  )
  api_environment <- new.env(parent = emptyenv())
  api_environment$synthetic_phase15_api <- function() invisible(TRUE)
  expect_identical(
    phase15_test_require_api("synthetic_phase15_api", api_environment),
    api_environment$synthetic_phase15_api
  )
  expect_setequal(names(phase15_test_contract_sections), sprintf("15-%02d", 1:6))
})

test_that("temporary outcomes roots are created only through the registered helper", {
  first <- phase15_test_output_root()
  second <- phase15_test_output_root()
  on.exit(unlink(c(first, second), recursive = TRUE, force = TRUE), add = TRUE)
  temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)

  expect_true(dir.exists(first))
  expect_true(dir.exists(second))
  expect_false(identical(first, second))
  expect_true(startsWith(as.character(first), paste0(temp_root, "/")))
  expect_true(isTRUE(attr(first, "phase15_registered")))
  expect_error(
    phase15_test_output_root(file.path(phase15_test_project_root, "outputs/competition")),
    "must be a child of tempdir"
  )
})

test_that("three-team and four-team fixtures preserve tied standings and rule inputs", {
  three <- phase15_test_three_team_group()
  four <- phase15_test_four_team_group()
  access <- phase15_test_access_list()
  required_access_fields <- c(
    "edition_id", "team_id", "access_list_position", "league_id", "group_id",
    "draw_pot", "group_formation_status", "source_artifact_id"
  )
  required_standing_fields <- c(
    "edition_id", "league_id", "league", "group_id", "team_id", "group_position",
    "played", "wins", "draws", "losses", "goals_for", "goals_against",
    "goal_difference", "points", "discipline_points", "access_list_position",
    "counted_match_ids", "excluded_match_ids", "ordering_status", "missing_rule_input",
    "suppression_reason", "source_artifact_id", "source_bundle_id", "ruleset_version"
  )

  expect_equal(nrow(three$standings), 3L)
  expect_equal(nrow(four$standings), 4L)
  expect_true(all(required_standing_fields %in% names(three$standings)))
  expect_true(all(required_standing_fields %in% names(four$standings)))
  expect_equal(length(unique(three$standings$points)), 1L)
  expect_equal(length(unique(four$standings$points[seq_len(3L)])), 1L)
  expect_true(all(three$standings$discipline_points == 1:3))
  expect_true(all(four$standings$discipline_points[seq_len(3L)] == 1:3))
  expect_true(all(four$standings$access_list_position[seq_len(3L)] == 1:3))
  expect_identical(three$league_id, "D")
  expect_identical(four$league_id, "A")
  expect_identical(anyDuplicated(three$matches$source_fixture_id), 0L)
  expect_identical(anyDuplicated(four$matches$source_fixture_id), 0L)
  expect_true(all(required_access_fields %in% names(access$admitted)))
  expect_true(all(required_access_fields %in% names(access$current_source)))
  expect_true(all(access$admitted$access_list_position == seq_len(nrow(access$admitted))))
  expect_true(all(is.na(access$current_source$access_list_position)))
  expect_true(all(is.na(access$current_source$draw_pot)))
  expect_true(all(access$current_source$status == "unresolved_access_list"))
  expect_true(all(access$current_source$group_formation_status == "unresolved_access_list"))
  expect_true(all(access$current_source$source_artifact_id == "artifact-groups-v2"))
})

test_that("Article 14 two-leg fixtures are reciprocal and reject duplicate-home variants", {
  pair <- phase15_test_two_leg_pair()
  expect_silent(phase15_test_two_leg_invariants(pair$valid, pair$lower_league_team_id))
  expect_identical(
    as.character(pair$valid$home_team_id[[1L]]),
    pair$expected_first_leg_home_team_id
  )
  expect_error(
    phase15_test_two_leg_invariants(pair$invalid_duplicate_home, pair$lower_league_team_id),
    "host exactly once|same unordered participants"
  )
  expect_identical(
    sort(unique(c(pair$valid$home_team_id, pair$valid$away_team_id))),
    sort(c(pair$higher_league_team_id, pair$lower_league_team_id))
  )
})

test_that("Article 17 host-association metadata fixes semi-final and final ordering", {
  host <- phase15_test_host_association()
  expect_identical(host$expected_host_semi_final_id, host$semi_final_1_id)
  expect_identical(host$semi_final_1_team_a_policy, "host_association_first")
  expect_identical(host$final_team_a_source, "semi_final_1_winner")
  expect_identical(host$third_place_team_a_source, "semi_final_1_loser")
  expect_false(anyNA(host[, c(
    "association_id", "host_team_id", "semi_final_1_id", "semi_final_2_id",
    "final_team_a_source", "third_place_team_a_source"
  )]))
})

test_that("completed stage captures preserve exact score axes and source lineage", {
  capture <- phase15_test_completed_stage_capture()
  completed_score_fields <- c(
    "regulation_home_goals", "regulation_away_goals", "extra_time_home_goals",
    "extra_time_away_goals", "penalty_shootout_home_goals",
    "penalty_shootout_away_goals", "final_home_goals", "final_away_goals",
    "completed_at_utc"
  )
  stage_ids <- c(
    "league_a_quarter_final", "league_a_semi_final", "league_a_final",
    "a_b_playoff", "b_c_playoff", "c_d_playoff"
  )
  expect_true(all(completed_score_fields %in% names(capture)))
  expect_setequal(unique(capture$stage_id), stage_ids)
  expect_true(all(capture$stage_status == "completed"))
  expect_true(all(nzchar(capture$source_fixture_id)))
  expect_true(all(nzchar(capture$source_artifact_id)))
  expect_true(all(grepl("^[0-9a-f]{64}$", capture$raw_sha256)))
  expect_true(all(nzchar(capture$completed_at_utc)))
  expect_true(any(capture$extra_time_home_goals > 0L | capture$extra_time_away_goals > 0L))
  expect_true(any(capture$penalty_shootout_home_goals > 0L | capture$penalty_shootout_away_goals > 0L, na.rm = TRUE))
  expect_true(all(
    capture$final_home_goals == capture$regulation_home_goals + capture$extra_time_home_goals
  ))
  expect_true(all(
    capture$final_away_goals == capture$regulation_away_goals + capture$extra_time_away_goals
  ))
  expect_true(all(vapply(seq_len(nrow(capture)), function(index) {
    identical(
      capture$row_sha256[[index]],
      phase15_test_row_sha256(capture[index, setdiff(names(capture), "row_sha256"), drop = FALSE])
    )
  }, logical(1))))
})

test_that("calibrated forecast fixtures preserve simplex mass and bounded score grids", {
  fixture <- phase15_test_calibrated_forecast()
  forecast <- fixture$forecasts
  grid <- fixture$score_distributions
  probabilities <- unname(as.numeric(forecast[1L, c("p_home", "p_draw", "p_away")]))

  expect_identical(forecast$forecast_status, "available")
  expect_identical(forecast$primary_probability_view, "calibrated_1x2")
  expect_equal(sum(probabilities), 1, tolerance = 1e-12)
  expect_true(all(is.finite(probabilities) & probabilities >= 0 & probabilities <= 1))
  expect_true(all(grid$home_goals %in% fixture$score_support))
  expect_true(all(grid$away_goals %in% fixture$score_support))
  expect_true(all(grid$probability >= 0 & is.finite(grid$probability)))
  expect_equal(sum(grid$probability), 1, tolerance = 1e-12)
  expect_true(all(grid$normalized))
  expect_equal(
    sum(grid$probability[grid$home_goals > grid$away_goals]),
    fixture$expected_category_mass[["home"]],
    tolerance = 1e-12
  )
  expect_equal(
    sum(grid$probability[grid$home_goals == grid$away_goals]),
    fixture$expected_category_mass[["draw"]],
    tolerance = 1e-12
  )
  expect_equal(
    sum(grid$probability[grid$home_goals < grid$away_goals]),
    fixture$expected_category_mass[["away"]],
    tolerance = 1e-12
  )
  expect_true(all(grepl("^[0-9a-f]{64}$", forecast$model_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", forecast$source_bundle_sha256)))
})

test_that("group formation and stage hashes are identical after input reordering", {
  formation <- phase15_test_group_formation()
  capture <- phase15_test_completed_stage_capture()
  expect_identical(
    formation$table_sha256,
    phase15_test_table_sha256(formation$reversed_rows)
  )
  expect_identical(
    phase15_test_table_sha256(capture),
    phase15_test_table_sha256(capture[nrow(capture):1L, , drop = FALSE])
  )
  expect_identical(
    phase15_test_table_sha256(phase15_test_four_team_group()$standings),
    phase15_test_table_sha256(phase15_test_four_team_group()$standings[4:1, , drop = FALSE])
  )
  expect_true(grepl("^[0-9a-f]{64}$", formation$table_sha256))
  expect_true(grepl("^[0-9a-f]{64}$", phase15_test_table_sha256(capture)))
})

# Plan 15-01 extension points: topology, stage-slot, source-admission, and group-formation APIs.
# Plan 15-02 extension points: Article 15 group ranking, Article 19 rankings, and transitions.
# Plan 15-03 extension points: calibrated sampling, stage resolution, draw policies, and simulation.
# Plan 15-04 extension points: outcomes schema, stage-capture loading, and forecast/form pass-through.
# Plan 15-05 extension points: the nine-file writer, dry-run, and replay entrypoint.
# Plan 15-06 extension points: production acceptance, no-leakage, and registered-root checks.
