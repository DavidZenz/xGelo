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

phase15_test_source("R/competition/source_contracts.R")
phase15_test_source("R/competition/publication_hashes.R")
phase15_test_source("R/competition/forecast_layer.R")
phase15_test_source("R/competition/form.R")
phase15_test_source("R/competition/state_bundle.R")
phase15_test_source("R/competition/uefa_nations_league_rules.R")
phase15_test_source("R/competition/uefa_nations_league_simulation.R")
phase15_test_source("R/competition/standings.R")
phase15_test_source("R/competition/uefa_nations_league_adapter.R")
phase15_test_source("R/competition/uefa_nations_league_outcomes.R")

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

phase15_test_run_outcomes_cli <- function(args) {
  phase15_test_run_entrypoint(
    args,
    script_relative_path = "scripts/build_uefa_nations_league_outcomes.R"
  )
}

phase15_test_run_entrypoint <- function(
    args,
    script_relative_path = "scripts/build_nations_league_outcomes.R") {
  script <- file.path(phase15_test_project_root, script_relative_path)
  output <- suppressWarnings(system2(
    "Rscript",
    c("--vanilla", script, args),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = paste(output, collapse = "\n"))
}

phase15_test_state_inventory_hashes <- function() {
  state_root <- file.path(
    phase15_test_project_root,
    "outputs/competition/uefa_nations_league_2026_27"
  )
  inventory <- phase14_state_bundle_expected_inventory()
  hashes <- vapply(inventory, function(relative_path) {
    path <- file.path(state_root, relative_path)
    if (!file.exists(path)) stop(sprintf("missing Phase 14 state artifact: %s", relative_path), call. = FALSE)
    phase15_test_sha256(readBin(path, what = "raw", n = file.info(path)$size))
  }, character(1L))
  names(hashes) <- inventory
  hashes
}

phase15_test_production_inputs <- function(project_root = phase15_test_project_root) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  edition_id <- phase15_test_edition_id
  source <- phase15_nl_read_source_bundle(project_root, edition_id)
  state_bundle <- phase15_nl_read_phase14_state_bundle(project_root, edition_id = edition_id)
  stage_capture <- phase15_uefa_nl_read_stage_capture(project_root = project_root)
  topology <- uefa_nl_build_topology(
    groups = source$groups,
    fixtures = source$fixtures,
    project_root = project_root
  )

  phase14_root <- file.path(project_root, "outputs/competition", edition_id)
  phase14_inventory <- phase14_state_bundle_expected_inventory()
  phase14_hashes <- vapply(phase14_inventory, function(relative_path) {
    path <- file.path(phase14_root, relative_path)
    phase15_test_sha256(readBin(path, what = "raw", n = file.info(path)$size))
  }, character(1L))
  names(phase14_hashes) <- phase14_inventory

  stage_paths <- phase15_uefa_nl_stage_capture_paths(project_root = project_root)
  stage_names <- c(
    raw = "raw_relative_path",
    accepted = "capture_relative_path",
    manifest = "manifest_relative_path",
    registry = "registry_relative_path"
  )
  stage_hashes <- vapply(stage_names, function(path_name) {
    relative_path <- unname(stage_paths[[path_name]])
    path <- file.path(project_root, relative_path)
    phase15_test_sha256(readBin(path, what = "raw", n = file.info(path)$size))
  }, character(1L))

  list(
    project_root = project_root,
    edition_id = edition_id,
    source = source,
    state_bundle = state_bundle,
    stage_capture = stage_capture,
    topology = topology,
    rules = uefa_nl_2026_27_rules(),
    phase13_resources = as.character(phase13_source_required_resource_types()),
    phase14_inventory = phase14_inventory,
    phase14_hashes = phase14_hashes,
    phase14_tree = phase15_test_tree_snapshot(phase14_root),
    stage_paths = stage_paths,
    stage_hashes = stage_hashes,
    accepted_tree = phase15_test_tree_snapshot(file.path(
      project_root, "data/competition/accepted", edition_id
    )),
    registry_tree = phase15_test_tree_snapshot(file.path(
      project_root, "data/competition/registries"
    ))
  )
}

phase15_test_assert_phase14_immutable <- function(
    before,
    after = phase15_test_production_inputs(before$project_root)) {
  if (!identical(before$phase14_inventory, after$phase14_inventory)) {
    stop("Phase 14 state inventory changed during Phase 15 acceptance", call. = FALSE)
  }
  if (!identical(before$phase14_hashes, after$phase14_hashes)) {
    stop("Phase 14 state artifact bytes changed during Phase 15 acceptance", call. = FALSE)
  }
  if (!identical(before$phase14_tree, after$phase14_tree)) {
    stop("Phase 14 state tree changed during Phase 15 acceptance", call. = FALSE)
  }
  if (!identical(before$stage_hashes, after$stage_hashes)) {
    stop("Separate stage-capture bytes changed during Phase 15 acceptance", call. = FALSE)
  }
  if (!identical(before$phase13_resources, after$phase13_resources)) {
    stop("Phase 13 resource contract changed during Phase 15 acceptance", call. = FALSE)
  }
  for (relative_path in before$phase14_inventory) {
    before_value <- before$state_bundle$state_artifacts[[relative_path]]
    after_value <- after$state_bundle$state_artifacts[[relative_path]]
    if (!identical(before_value, after_value)) {
      stop(
        sprintf("Phase 14 artifact values changed during Phase 15 acceptance: %s", relative_path),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

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

phase15_test_admitted_topology_inputs <- function() {
  access <- phase15_test_access_list()$admitted
  groups <- unique(access[, c("edition_id", "group_id", "league_id", "source_artifact_id"), drop = FALSE])
  groups$source_group_id <- groups$group_id
  groups$league <- groups$league_id
  groups$display_name <- paste("Group", groups$group_id)
  groups$source_bundle_id <- phase15_test_source_bundle_id
  groups <- groups[, c(
    "edition_id", "source_group_id", "league", "display_name", "source_bundle_id", "source_artifact_id"
  ), drop = FALSE]
  fixture_rows <- lapply(seq_len(nrow(groups)), function(index) {
    group_id <- as.character(groups$source_group_id[[index]])
    league_id <- as.character(groups$league[[index]])
    team_ids <- access$team_id[access$group_id == group_id]
    rows <- phase15_test_group_matches(team_ids, league_id, group_id, start_day = index)
    rows$source_bundle_id <- phase15_test_source_bundle_id
    rows
  })
  fixtures <- do.call(rbind, fixture_rows)
  row.names(fixtures) <- NULL
  list(
    access = access,
    groups = groups,
    group_rows = access[, c("team_id", "league_id", "group_id", "source_artifact_id"), drop = FALSE],
    fixtures = fixtures
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

phase15_test_adapter_stage_capture <- function() {
  capture <- phase15_test_completed_stage_capture()
  schema <- phase15_uefa_nl_stage_capture_schema()
  capture <- capture[, schema, drop = FALSE]
  capture$row_sha256 <- phase13_row_sha256(capture)
  capture
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

phase15_test_simulation_inputs <- function(simulation_count = 2L, seed = 15017L) {
  topology <- phase15_test_admitted_topology_inputs()
  access <- topology$access
  access$discipline_points <- seq_len(nrow(access))
  forecast <- phase15_test_calibrated_forecast()
  open <- topology$fixtures[1L, , drop = FALSE]
  forecast$forecasts$fixture_id <- open$fixture_id
  forecast$forecasts$match_id <- open$fixture_id
  forecast$forecasts$home_team_id <- open$home_team_id
  forecast$forecasts$away_team_id <- open$away_team_id
  forecast$forecast_status$fixture_id <- open$fixture_id
  forecast$score_distributions$fixture_id <- open$fixture_id

  matches <- topology$fixtures
  matches$match_status[[1L]] <- "scheduled"
  matches$source_status[[1L]] <- "scheduled"
  matches$counts_for_standings[[1L]] <- FALSE
  matches$final_home_goals[[1L]] <- NA_integer_
  matches$final_away_goals[[1L]] <- NA_integer_
  matches$regulation_home_goals[[1L]] <- NA_integer_
  matches$regulation_away_goals[[1L]] <- NA_integer_
  matches$evidence_completed_at_utc[[1L]] <- NA_character_

  list(
    canonical_matches = matches,
    completed_results = NULL,
    forecast_status = forecast$forecast_status,
    forecasts = forecast$forecasts,
    score_distributions = forecast$score_distributions,
    groups = list(groups = topology$groups, group_rows = access),
    rules = uefa_nl_2026_27_rules(),
    simulation_count = as.integer(simulation_count),
    seed = as.integer(seed),
    source_bundle_id = phase15_test_source_bundle_id,
    source_bundle_sha256 = phase15_test_hash_token("simulation-source-bundle"),
    model_release_id = "phase15-synthetic-model",
    model_lineage = list(model_id = "phase15-synthetic-model", model_sha256 = phase15_test_hash_token("simulation-model")),
    state_manifest_sha256 = phase15_test_hash_token("simulation-state-manifest"),
    euro_playoff_eligibility = NULL,
    official_stage_slots = NULL
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

test_that("canonical Nations League topology freezes the scheduled 2026/27 source", {
  topology <- uefa_nl_build_topology(project_root = phase15_test_project_root)
  groups <- utils::read.csv(
    file.path(phase15_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/groups.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  fixtures <- utils::read.csv(
    file.path(phase15_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  reversed <- uefa_nl_build_topology(
    groups = groups[nrow(groups):1L, , drop = FALSE],
    fixtures = fixtures[nrow(fixtures):1L, , drop = FALSE],
    project_root = phase15_test_project_root
  )
  expect_identical(topology$official_counts, c(groups = 14L, fixtures = 156L, teams = 54L))
  expect_identical(topology$group_formation_status, "unresolved_access_list")
  expect_identical(topology$missing_rule_input, "access_list")
  expect_true(all(is.na(topology$teams$access_list_position)))
  expect_true(all(is.na(topology$teams$draw_pot)))
  expect_true(all(nzchar(topology$teams$source_artifact_id)))
  expect_identical(as.integer(table(topology$groups$league_id)), c(4L, 4L, 4L, 2L))
  expect_identical(as.integer(table(topology$teams$league_id)), c(16L, 16L, 16L, 6L))
  expect_setequal(
    topology$stage_topology$stage_id,
    c("league_phase", "league_a_quarter_final", "league_a_semi_final", "league_a_third_place", "league_a_final", "a_b_playoff", "b_c_playoff", "c_d_playoff")
  )
  expect_length(uefa_nl_stage_status_values(), 5L)
  expect_identical(
    uefa_nl_2026_27_rules()$group_tiebreak,
    c("head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals", "recursive_tied_subset", "overall_goal_difference", "overall_goals", "overall_away_goals", "wins", "away_wins", "discipline_points", "access_list_position")
  )
  expect_true(uefa_nl_2026_27_rules()$cross_group$exclude_fourth_position_aware)
  expect_identical(uefa_nl_2026_27_rules()$match_resolution$article_17$team_a_ordering, "host_association_first_in_semi_final_1")
  expect_true(uefa_nl_2026_27_rules()$match_resolution$article_17$runner_up_first_leg_home %||% FALSE)
  pair_keys <- paste(
    topology$fixtures$group_id,
    pmin(topology$fixtures$home_team_id, topology$fixtures$away_team_id),
    pmax(topology$fixtures$home_team_id, topology$fixtures$away_team_id),
    sep = "::"
  )
  expect_true(all(table(pair_keys) == 2L))
  expect_true(all(vapply(split(topology$fixtures, pair_keys), function(rows) {
    length(unique(rows$home_team_id)) == 2L && length(unique(rows$away_team_id)) == 2L
  }, logical(1))))
  expect_identical(topology$ruleset_sha256, reversed$ruleset_sha256)
  expect_identical(topology$stage_topology_sha256, reversed$stage_topology_sha256)
  expect_identical(topology$topology_sha256, reversed$topology_sha256)
  expect_identical(uefa_nl_ruleset_sha256(), uefa_nl_ruleset_sha256(uefa_nl_2026_27_rules()))
})

test_that("Article 13 keeps the current source explicitly unresolved", {
  topology <- uefa_nl_build_topology(project_root = phase15_test_project_root)
  access <- uefa_nl_validate_access_list(NULL, topology$teams, phase15_test_edition_id)
  formation <- uefa_nl_validate_group_formation(
    access,
    topology$teams,
    group_formation_seed = 15013L,
    edition_id = phase15_test_edition_id
  )
  expect_identical(access$status, "unresolved_access_list")
  expect_identical(access$missing_rule_input, "access_list")
  expect_identical(formation$group_formation_status, "unresolved_access_list")
  expect_identical(formation$missing_rule_input, "access_list")
  expect_true(all(is.na(access$rows$access_list_position)))
  expect_true(all(is.na(access$rows$draw_pot)))
  expect_true(all(access$rows$group_formation_status == "unresolved_access_list"))
  expect_true(all(access$rows$source_artifact_id == topology$teams$source_artifact_id[match(access$rows$team_id, topology$teams$team_id)]))
})

test_that("admitted Article 13 group formation is seeded, complete, and order-independent", {
  inputs <- phase15_test_admitted_topology_inputs()
  admitted <- inputs$access
  access <- uefa_nl_validate_access_list(admitted)
  formation <- uefa_nl_validate_group_formation(
    access,
    inputs$group_rows,
    group_formation_seed = 15013L
  )
  reversed_access <- uefa_nl_validate_access_list(admitted[nrow(admitted):1L, , drop = FALSE])
  reversed_formation <- uefa_nl_validate_group_formation(
    reversed_access,
    inputs$group_rows[nrow(inputs$group_rows):1L, , drop = FALSE],
    group_formation_seed = 15013L
  )
  topology <- uefa_nl_build_topology(
    groups = inputs$groups,
    fixtures = inputs$fixtures,
    access_list = admitted,
    group_formation_seed = 15013L,
    project_root = phase15_test_project_root
  )
  reversed_topology <- uefa_nl_build_topology(
    groups = inputs$groups[nrow(inputs$groups):1L, , drop = FALSE],
    fixtures = inputs$fixtures[nrow(inputs$fixtures):1L, , drop = FALSE],
    access_list = admitted[nrow(admitted):1L, , drop = FALSE],
    group_formation_seed = 15013L,
    project_root = phase15_test_project_root
  )
  expect_identical(access$status, "validated")
  expect_identical(formation$group_formation_status, "validated")
  expect_identical(formation$group_formation_seed, 15013L)
  expect_equal(nrow(formation$rows), 54L)
  expect_true(all(!is.na(formation$rows$access_list_position)))
  expect_true(all(!is.na(formation$rows$draw_pot)))
  expect_identical(access$table_sha256, reversed_access$table_sha256)
  expect_identical(formation$table_sha256, reversed_formation$table_sha256)
  expect_identical(topology$access_list_status, "validated")
  expect_identical(topology$group_formation_status, "validated")
  expect_true(all(topology$teams$group_formation_seed == 15013L))
  expect_true(all(!is.na(topology$teams$access_list_position)))
  expect_identical(topology$topology_sha256, reversed_topology$topology_sha256)
  expect_identical(topology$stage_topology_sha256, reversed_topology$stage_topology_sha256)

  duplicate_position <- admitted
  duplicate_position$access_list_position[[2L]] <- duplicate_position$access_list_position[[1L]]
  expect_error(uefa_nl_validate_access_list(duplicate_position), "unique positive integers")

  missing_lineage <- admitted
  missing_lineage$source_artifact_id[[1L]] <- ""
  expect_error(uefa_nl_validate_access_list(missing_lineage), "missing source_artifact_id")

  wrong_band <- admitted
  wrong_band$league_id[[1L]] <- "B"
  expect_error(uefa_nl_validate_access_list(wrong_band), "outside its Article 13 league band")

  wrong_group <- admitted
  wrong_group$group_id[[1L]] <- "A2"
  expect_error(
    uefa_nl_validate_group_formation(wrong_group, inputs$group_rows),
    "group assignment disagrees"
  )

  wrong_draw_pot <- admitted
  wrong_draw_pot$draw_pot[[1L]] <- wrong_draw_pot$draw_pot[[2L]]
  expect_error(
    uefa_nl_validate_group_formation(wrong_draw_pot, inputs$group_rows),
    "draw pot more than once"
  )

  published_group_mismatch <- inputs$group_rows
  published_group_mismatch$group_id[[1L]] <- "A9"
  expect_error(
    uefa_nl_validate_group_formation(admitted, published_group_mismatch),
    "group assignment disagrees"
  )
})

test_that("stage-slot status contracts fail closed for fabricated official rows", {
  schema <- uefa_nl_stage_slot_schema()
  empty <- uefa_nl_stage_slot_empty()
  expect_identical(names(empty), schema)
  base <- data.frame(
    edition_id = phase15_test_edition_id,
    stage_id = "league_a_quarter_final",
    stage_type = "quarter_final",
    stage_status = "official",
    leg_number = 1L,
    participant_slot_home = "A-winner-A1",
    participant_slot_away = "A-runner-up-A2",
    home_team_id = "team-a-1-1",
    away_team_id = "team-a-1-2",
    source_fixture_id = "source-qf-1",
    source_artifact_id = "artifact-stage-capture-v1",
    projection_run_id = "",
    draw_policy_id = "",
    scheduled_at_utc = "2027-03-10T19:45:00Z",
    unresolved_reason = "",
    suppression_reason = "",
    ruleset_version = uefa_nl_ruleset_version(),
    ruleset_sha256 = uefa_nl_ruleset_sha256(),
    row_sha256 = "",
    regulation_home_goals = NA_integer_,
    regulation_away_goals = NA_integer_,
    extra_time_home_goals = NA_integer_,
    extra_time_away_goals = NA_integer_,
    penalty_shootout_home_goals = NA_integer_,
    penalty_shootout_away_goals = NA_integer_,
    final_home_goals = NA_integer_,
    final_away_goals = NA_integer_,
    completed_at_utc = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  base$row_sha256 <- phase13_row_sha256(base)
  expect_silent(uefa_nl_validate_stage_slots(base))

  projected <- base
  projected$stage_id <- "league_a_semi_final"
  projected$stage_type <- "semi_final"
  projected$stage_status <- "projected"
  projected$source_fixture_id <- ""
  projected$source_artifact_id <- ""
  projected$projection_run_id <- "projection-15013"
  projected$draw_policy_id <- "nl-qf-draw-v1"
  projected$row_sha256 <- phase13_row_sha256(projected)
  expect_silent(uefa_nl_validate_stage_slots(projected))

  unresolved <- projected
  unresolved$stage_status <- "unresolved"
  unresolved$projection_run_id <- ""
  unresolved$draw_policy_id <- ""
  unresolved$unresolved_reason <- "awaiting_official_pairing"
  unresolved$row_sha256 <- phase13_row_sha256(unresolved)
  expect_silent(uefa_nl_validate_stage_slots(unresolved))

  fabricated <- base
  fabricated$source_fixture_id <- ""
  fabricated$row_sha256 <- phase13_row_sha256(fabricated)
  expect_error(uefa_nl_validate_stage_slots(fabricated), "source fixture and artifact lineage")

  completed <- base
  completed$stage_status <- "completed"
  completed$regulation_home_goals <- 1L
  completed$regulation_away_goals <- 1L
  completed$extra_time_home_goals <- 1L
  completed$extra_time_away_goals <- 0L
  completed$final_home_goals <- 2L
  completed$final_away_goals <- 1L
  completed$completed_at_utc <- "2027-03-10T22:30:00Z"
  completed$row_sha256 <- phase13_row_sha256(completed)
  expect_silent(uefa_nl_validate_stage_slots(completed))
  bad_final <- completed
  bad_final$final_home_goals <- 1L
  bad_final$row_sha256 <- phase13_row_sha256(bad_final)
  expect_error(uefa_nl_validate_stage_slots(bad_final), "regulation plus extra-time")
})

test_that("downstream stage capture is separately admitted and the empty registry replays", {
  schema <- phase15_uefa_nl_stage_capture_schema()
  paths <- phase15_uefa_nl_stage_capture_paths(project_root = phase15_test_project_root)
  expected_paths <- c(
    raw_relative_path = "data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-stage-capture-v1/stage_capture.json",
    capture_relative_path = "data/competition/accepted/uefa_nations_league_2026_27/stage_capture.csv",
    manifest_relative_path = "data/competition/accepted/uefa_nations_league_2026_27/stage_capture_manifest.csv",
    registry_relative_path = "data/competition/registries/stage_captures.csv"
  )
  expect_identical(unname(unlist(paths[names(expected_paths)])), unname(expected_paths))
  expect_identical(
    schema,
    c(
      "edition_id", "stage_id", "round_id", "leg_number", "source_fixture_id",
      "home_team_id", "away_team_id", "participant_slot_home", "participant_slot_away",
      "scheduled_at_utc", "source_status", "stage_status", "source_artifact_id",
      "source_url", "retrieved_at_utc", "raw_sha256", "regulation_home_goals",
      "regulation_away_goals", "extra_time_home_goals", "extra_time_away_goals",
      "penalty_shootout_home_goals", "penalty_shootout_away_goals", "final_home_goals",
      "final_away_goals", "completed_at_utc", "row_sha256"
    )
  )
  expect_false("stage_capture" %in% phase13_source_required_resource_types())
  empty <- phase15_uefa_nl_read_stage_capture(project_root = phase15_test_project_root)
  expect_identical(empty$capture_status, "empty")
  expect_identical(names(empty$stage_capture), schema)
  expect_equal(nrow(empty$stage_capture), 0L)
  expect_identical(empty$manifest$capture_status, "empty")
  expect_identical(empty$registry$manifest_sha256, empty$manifest$manifest_sha256)
})

test_that("official stage capture validation rejects fabricated or incomplete rows", {
  capture <- phase15_test_adapter_stage_capture()
  expect_silent(phase15_uefa_nl_validate_stage_capture(capture))
  adapted <- phase15_uefa_nl_adapt_stage_capture(capture)
  expect_identical(adapted$capture_status, "accepted")
  expect_equal(nrow(adapted$stage_capture), nrow(capture))
  expect_identical(names(adapted$stage_capture), names(capture))

  mixed <- capture
  mixed$stage_status[[1L]] <- "official"
  mixed[c(
    "regulation_home_goals", "regulation_away_goals", "extra_time_home_goals",
    "extra_time_away_goals", "final_home_goals", "final_away_goals"
  )][1L, ] <- NA_integer_
  mixed$completed_at_utc[[1L]] <- ""
  mixed$row_sha256 <- phase13_row_sha256(mixed)
  expect_silent(phase15_uefa_nl_validate_stage_capture(mixed))

  foreign <- capture
  foreign$edition_id[[1L]] <- "foreign_edition"
  foreign$row_sha256 <- phase13_row_sha256(foreign)
  expect_error(phase15_uefa_nl_validate_stage_capture(foreign), "foreign edition")

  missing_lineage <- capture
  missing_lineage$source_artifact_id[[1L]] <- ""
  missing_lineage$row_sha256 <- phase13_row_sha256(missing_lineage)
  expect_error(phase15_uefa_nl_validate_stage_capture(missing_lineage), "source_artifact_id")

  duplicate_id <- capture
  duplicate_id$source_fixture_id[[2L]] <- duplicate_id$source_fixture_id[[1L]]
  duplicate_id$row_sha256 <- phase13_row_sha256(duplicate_id)
  expect_error(phase15_uefa_nl_validate_stage_capture(duplicate_id), "unique source fixture IDs")

  incomplete <- capture
  incomplete$final_home_goals[[1L]] <- NA_integer_
  incomplete$row_sha256 <- phase13_row_sha256(incomplete)
  expect_error(phase15_uefa_nl_validate_stage_capture(incomplete), "final_home_goals")

  fabricated <- capture[1L, , drop = FALSE]
  fabricated$stage_status <- "official"
  fabricated$source_fixture_id <- ""
  fabricated$regulation_home_goals <- NA_integer_
  fabricated$regulation_away_goals <- NA_integer_
  fabricated$extra_time_home_goals <- NA_integer_
  fabricated$extra_time_away_goals <- NA_integer_
  fabricated$final_home_goals <- NA_integer_
  fabricated$final_away_goals <- NA_integer_
  fabricated$completed_at_utc <- ""
  fabricated$row_sha256 <- phase13_row_sha256(fabricated)
  expect_error(phase15_uefa_nl_validate_stage_capture(fabricated), "unique source fixture IDs")

  expect_error(
    phase13_validate_structured_resource_names(c(phase13_source_required_resource_types(), "stage_capture")),
    "unknown resource"
  )
})

test_that("the existing scheduled adapter remains a five-resource, 156-fixture boundary", {
  raw_path <- file.path(
    phase15_test_project_root,
    "data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-official-uefa-v2/fixtures.json"
  )
  payload <- jsonlite::fromJSON(
    rawToChar(readBin(raw_path, what = "raw", n = file.info(raw_path)$size)),
    simplifyVector = FALSE
  )
  expect_silent(phase14_uefa_nl_validate_response(payload))
  adapted <- phase14_uefa_nl_adapt_response(payload)
  expect_identical(names(adapted$resources), phase13_source_required_resource_types())
  expect_identical(adapted$official_counts, c(fixtures = 156L, groups = 14L, teams = 54L))
  expect_true(all(is.na(adapted$resources$results$home_goals)))
  expect_true(all(is.na(adapted$resources$results$away_goals)))
  expect_identical(adapted$resources$status$competition_status, "scheduled")
})

test_that("Article 15 ordering is recursive, auditable, and uses the Phase 14 adapter seam", {
  fixture <- phase15_test_four_team_group()
  matches <- fixture$matches
  matches$state_cutoff_utc <- "2026-12-31T00:00:00Z"
  matches$final_home_goals[matches$home_team_id == fixture$team_ids[[1L]] & matches$away_team_id == fixture$team_ids[[2L]]] <- 2L
  matches$final_away_goals[matches$home_team_id == fixture$team_ids[[1L]] & matches$away_team_id == fixture$team_ids[[2L]]] <- 0L
  matches$final_home_goals[matches$home_team_id == fixture$team_ids[[2L]] & matches$away_team_id == fixture$team_ids[[1L]]] <- 0L
  matches$final_away_goals[matches$home_team_id == fixture$team_ids[[2L]] & matches$away_team_id == fixture$team_ids[[1L]]] <- 1L
  discipline <- fixture$discipline_points
  discipline$discipline_points <- 1L
  standings <- fixture$standings
  standings$points <- 7L
  standings$goal_difference <- 0L
  standings$goals_for <- 5L
  standings$wins <- 0L
  ranked <- uefa_nl_rank_group(
    standings = standings,
    match_rows = matches,
    discipline_points = discipline,
    access_list = fixture$access_list
  )
  expect_identical(ranked$computed_rank, 1:4)
  expect_setequal(ranked$team_id, fixture$team_ids)
  expect_true(all(ranked$ordering_status == "ready"))
  expect_true(all(ranked$group_position == ranked$computed_rank))
  trace <- attr(ranked, "tiebreak_trace", exact = TRUE)
  expect_true(is.data.frame(trace))
  expect_true(all(c("criterion", "tied_subset", "counted_match_ids", "decision", "ruleset_sha256") %in% names(trace)))
  expect_true(all(c(
    "head_to_head_points", "head_to_head_goal_difference", "head_to_head_goals",
    "overall_goal_difference", "overall_goals", "overall_away_goals", "wins",
    "away_wins", "discipline_points", "access_list_position"
  ) %in% trace$criterion))
  expect_true(any(trace$criterion == "recursive_tied_subset" | trace$recursion_depth > 0L))
  expect_true(all(grepl("^[0-9a-f]{64}$", ranked$row_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", ranked$table_sha256)))

  adapter <- uefa_nl_make_standings_adapter(
    matches,
    discipline,
    fixture$access_list,
    fixture$group_id
  )
  expect_identical(attr(adapter, "adapter_id", exact = TRUE), "uefa_nl_article15_v2")
  phase14_input <- standings[, c("team_id", "points", "goal_difference", "goals_for", "wins"), drop = FALSE]
  phase14_input$edition_id <- phase15_test_edition_id
  phase14_input$group_id <- fixture$group_id
  phase14_input$state_cutoff_utc <- "2026-12-31T00:00:00Z"
  phase14_input$source_bundle_id <- phase15_test_source_bundle_id
  phase14_input <- phase14_input[, c("edition_id", "group_id", "state_cutoff_utc", "source_bundle_id", "team_id", "points", "goal_difference", "goals_for", "wins"), drop = FALSE]
  expect_identical(adapter(phase14_input)$computed_rank, 1:4)
})

test_that("Article 15 missing rule inputs block before Phase 14 receives ranks", {
  fixture <- phase15_test_four_team_group()
  matches <- fixture$matches
  matches$state_cutoff_utc <- "2026-12-31T00:00:00Z"
  missing_discipline <- uefa_nl_rank_group(
    fixture$standings,
    matches,
    discipline_points = NULL,
    access_list = fixture$access_list
  )
  expect_true(all(is.na(missing_discipline$computed_rank)))
  expect_true(all(missing_discipline$ordering_status == "blocked"))
  expect_true(all(missing_discipline$block_status == "blocked"))
  expect_true(all(grepl("discipline_points", missing_discipline$missing_rule_input)))
  expect_true(all(missing_discipline$suppression_reason == "missing_rule_input"))

  missing_access <- fixture$access_list
  missing_access$access_list_position[[1L]] <- NA_integer_
  missing_access_result <- uefa_nl_rank_group(
    fixture$standings,
    matches,
    discipline_points = fixture$discipline_points,
    access_list = missing_access
  )
  expect_true(all(is.na(missing_access_result$computed_rank)))
  expect_true(all(grepl("access_list_position", missing_access_result$missing_rule_input)))

  adapter <- uefa_nl_make_standings_adapter(matches, NULL, fixture$access_list, fixture$group_id)
  condition <- tryCatch(adapter(fixture$standings), error = identity)
  expect_s3_class(condition, "phase15_nl_missing_rule_input")
  expect_setequal(condition$missing_rule_input, "discipline_points")

  state <- uefa_nl_build_group_standings_state(
    match_rows = matches,
    discipline_points = NULL,
    access_list = fixture$access_list,
    group_id = fixture$group_id,
    edition_id = phase15_test_edition_id,
    state_cutoff_utc = "2026-12-31T00:00:00Z",
    source_bundle_id = phase15_test_source_bundle_id
  )
  expect_identical(state$ordering_status, "blocked")
  expect_true(all(is.na(state$standings$computed_rank)))
  expect_true(all(state$standings$ordering_status == "blocked"))
  expect_true(all(state$universal_standings$ordering_status == "provisional"))
})

test_that("the Article 15 adapter handles a three-team League D group without a fourth-place row", {
  fixture <- phase15_test_three_team_group()
  ranked <- uefa_nl_rank_group(
    fixture$standings,
    fixture$matches,
    fixture$discipline_points,
    fixture$access_list
  )
  expect_equal(nrow(ranked), 3L)
  expect_identical(ranked$group_position, 1:3)
  expect_false(any(is.na(ranked$computed_rank)))
  expect_true(all(ranked$excluded_match_ids == ""))
})

test_that("Article 19 individual rankings preserve cardinality-aware match lineage", {
  four_team <- phase15_test_four_team_group()
  three_team <- phase15_test_three_team_group()
  four_standings <- four_team$standings
  four_standings$league <- "A"
  four_standings$league_id <- "A"
  three_standings <- three_team$standings
  three_standings$league <- "D"
  three_standings$league_id <- "D"
  individual <- uefa_nl_rank_individual_league(
    group_standings = list(A1 = four_standings, D1 = three_standings),
    match_rows = rbind(four_team$matches, three_team$matches)
  )

  expect_identical(individual$individual_rank[individual$league == "A"], 1:4)
  expect_identical(individual$individual_rank[individual$league == "D"], 1:3)
  a_top <- individual[individual$league == "A" & individual$group_position == 1L, , drop = FALSE]
  a_fourth <- individual[individual$league == "A" & individual$group_position == 4L, , drop = FALSE]
  d_rows <- individual[individual$league == "D", , drop = FALSE]
  expect_length(strsplit(a_top$excluded_match_ids[[1L]], ";", fixed = TRUE)[[1L]], 2L)
  expect_length(strsplit(a_top$counted_match_ids[[1L]], ";", fixed = TRUE)[[1L]], 4L)
  expect_identical(a_fourth$excluded_match_ids[[1L]], "")
  expect_true(all(d_rows$excluded_match_ids == ""))
  expect_true(all(d_rows$comparison_status == "ready"))
  expect_true(all(grepl("^[0-9a-f]{64}$", individual$row_sha256)))

  missing_discipline <- four_standings
  missing_discipline$discipline_points[[1L]] <- NA_integer_
  blocked <- uefa_nl_rank_individual_league(
    group_standings = list(A1 = missing_discipline),
    match_rows = four_team$matches
  )
  expect_true(all(is.na(blocked$individual_rank)))
  expect_true(all(blocked$ordering_status == "blocked"))
  expect_true(all(grepl("discipline_points", blocked$missing_rule_input)))
})

test_that("Article 19 interim rankings and transition selectors use exact dynamic rank bands", {
  groups <- list()
  index <- 1L
  for (league in c("A", "B", "C")) {
    for (group_number in 1:4) {
      for (group_position in 1:4) {
        groups[[index]] <- data.frame(
          edition_id = phase15_test_edition_id,
          team_id = phase15_test_team_id(league, group_number, group_position),
          league = league,
          league_id = league,
          group_id = paste0(league, group_number),
          group_position = group_position,
          individual_rank = (group_position - 1L) * 4L + group_number,
          discipline_points = group_number,
          access_list_position = index,
          ordering_status = "ready",
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
        index <- index + 1L
      }
    }
  }
  for (group_number in 1:2) {
    for (group_position in 1:3) {
      groups[[index]] <- data.frame(
        edition_id = phase15_test_edition_id,
        team_id = phase15_test_team_id("D", group_number, group_position),
        league = "D",
        league_id = "D",
        group_id = paste0("D", group_number),
        group_position = group_position,
        individual_rank = (group_position - 1L) * 2L + group_number,
        discipline_points = group_number,
        access_list_position = index,
        ordering_status = "ready",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      index <- index + 1L
    }
  }
  individual <- do.call(rbind, groups)
  interim <- uefa_nl_rank_interim_overall(individual)
  expect_identical(interim$interim_rank[interim$league == "A"], 1:16)
  expect_identical(interim$interim_rank[interim$league == "B"], 17:32)
  expect_identical(interim$interim_rank[interim$league == "C"], 33:48)
  expect_identical(interim$interim_rank[interim$league == "D"], 49:54)
  expect_false(any(interim$interim_rank == 55L))

  selectors <- uefa_nl_select_transition_slots(interim)
  expect_equal(nrow(selectors), 30L)
  expect_equal(sum(selectors$transition_type == "direct_promotion"), 10L)
  expect_equal(sum(selectors$transition_type == "direct_relegation"), 10L)
  expect_equal(sum(selectors$stage_id == "a_b_playoff"), 4L)
  expect_equal(sum(selectors$stage_id == "b_c_playoff"), 4L)
  expect_equal(sum(selectors$stage_id == "c_d_playoff"), 2L)
  expect_equal(anyDuplicated(selectors$transition_key), 0L)

  ab <- selectors[selectors$stage_id == "a_b_playoff", , drop = FALSE]
  bc <- selectors[selectors$stage_id == "b_c_playoff", , drop = FALSE]
  cd <- selectors[selectors$stage_id == "c_d_playoff", , drop = FALSE]
  expect_identical(ab$higher_league_rank, 9:12)
  expect_identical(ab$lower_league_rank, 21:24)
  expect_identical(bc$higher_league_rank, 25:28)
  expect_identical(bc$lower_league_rank, 37:40)
  expect_identical(cd$higher_league_rank, 45:46)
  expect_identical(cd$lower_league_rank, 51:52)
  expect_true(all(ab$first_leg_home_team_id == ab$lower_league_team_id))
  expect_true(all(bc$first_leg_home_team_id == bc$lower_league_team_id))
  expect_true(all(cd$first_leg_home_team_id == cd$lower_league_team_id))
  expect_true(all(cd$selection_status == "unresolved"))
  expect_true(all(cd$eligibility_status == "unresolved_external_eligibility"))
  expect_true(all(cd$unresolved_reason == "euro_playoff_eligibility_missing"))

  blocked <- interim
  blocked$ordering_status[blocked$league == "B"] <- "blocked"
  blocked$computed_rank[blocked$league == "B"] <- NA_integer_
  blocked_selectors <- uefa_nl_select_transition_slots(blocked)
  blocked_b <- blocked_selectors[blocked_selectors$stage_id == "b_c_playoff", , drop = FALSE]
  expect_true(all(blocked_b$selection_status == "unresolved"))
  expect_true(all(blocked_b$unresolved_reason == "missing_rule_input"))
  expect_true(all(is.na(blocked_b$higher_league_team_id)))
})

phase15_test_final_interim_rankings <- function(team_count = 54L) {
  ranks <- seq_len(as.integer(team_count))
  league <- ifelse(ranks <= 16L, "A", ifelse(ranks <= 32L, "B", ifelse(ranks <= 48L, "C", "D")))
  league_start <- c(A = 1L, B = 17L, C = 33L, D = 49L)
  position <- vapply(seq_along(ranks), function(index) {
    rank <- ranks[[index]]
    current_league <- league[[index]]
    offset <- rank - league_start[[current_league]]
    if (current_league == "D" && team_count < 55L) return((offset %% 3L) + 1L)
    (offset %% 4L) + 1L
  }, integer(1))
  group_number <- vapply(seq_along(ranks), function(index) {
    current_league <- league[[index]]
    offset <- ranks[[index]] - league_start[[current_league]]
    if (current_league == "D") return((offset %/% 3L) + 1L)
    (offset %/% 4L) + 1L
  }, integer(1))
  data.frame(
    edition_id = phase15_test_edition_id,
    team_id = sprintf("team-final-%02d", ranks),
    league = league,
    league_id = league,
    group_id = paste0(league, group_number),
    group_position = as.integer(position),
    individual_rank = as.integer(ranks - league_start[league] + 1L),
    interim_rank = as.integer(ranks),
    computed_rank = as.integer(ranks),
    discipline_points = as.integer(ranks %% 4L),
    access_list_position = as.integer(ranks),
    ordering_status = "ready",
    missing_rule_input = "",
    block_status = "not_blocked",
    blocked = FALSE,
    suppression_reason = "none",
    source_bundle_id = phase15_test_source_bundle_id,
    source_artifact_id = "artifact-final-ranking-synthetic",
    ruleset_version = phase15_test_ruleset_version,
    ranking_stage = "interim_overall",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase15_test_final_stage_outcomes <- function(include_finals = TRUE) {
  interim <- phase15_test_final_interim_rankings()
  team <- function(rank) interim$team_id[interim$interim_rank == rank]
  rows <- list(
    data.frame(stage_id = "league_a_quarter_final", tie_id = "qf-1", stage_status = "completed", winner_team_id = team(1L), loser_team_id = team(5L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "league_a_quarter_final", tie_id = "qf-2", stage_status = "completed", winner_team_id = team(2L), loser_team_id = team(6L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "league_a_quarter_final", tie_id = "qf-3", stage_status = "completed", winner_team_id = team(3L), loser_team_id = team(7L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "league_a_quarter_final", tie_id = "qf-4", stage_status = "completed", winner_team_id = team(4L), loser_team_id = team(8L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "a_b_playoff", tie_id = "ab-1", stage_status = "completed", winner_team_id = team(9L), loser_team_id = team(21L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "a_b_playoff", tie_id = "ab-2", stage_status = "completed", winner_team_id = team(10L), loser_team_id = team(22L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "a_b_playoff", tie_id = "ab-3", stage_status = "completed", winner_team_id = team(11L), loser_team_id = team(23L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "a_b_playoff", tie_id = "ab-4", stage_status = "completed", winner_team_id = team(12L), loser_team_id = team(24L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "b_c_playoff", tie_id = "bc-1", stage_status = "completed", winner_team_id = team(25L), loser_team_id = team(37L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "b_c_playoff", tie_id = "bc-2", stage_status = "completed", winner_team_id = team(26L), loser_team_id = team(38L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "b_c_playoff", tie_id = "bc-3", stage_status = "completed", winner_team_id = team(27L), loser_team_id = team(39L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "b_c_playoff", tie_id = "bc-4", stage_status = "completed", winner_team_id = team(28L), loser_team_id = team(40L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "c_d_playoff", tie_id = "cd-1", stage_status = "completed", winner_team_id = team(45L), loser_team_id = team(51L), stringsAsFactors = FALSE, check.names = FALSE),
    data.frame(stage_id = "c_d_playoff", tie_id = "cd-2", stage_status = "completed", winner_team_id = team(46L), loser_team_id = team(52L), stringsAsFactors = FALSE, check.names = FALSE)
  )
  if (isTRUE(include_finals)) {
    rows <- c(rows, list(
      data.frame(stage_id = "league_a_final", tie_id = "final", stage_status = "completed", winner_team_id = team(4L), loser_team_id = team(1L), stringsAsFactors = FALSE, check.names = FALSE),
      data.frame(stage_id = "league_a_third_place", tie_id = "third", stage_status = "completed", winner_team_id = team(3L), loser_team_id = team(2L), stringsAsFactors = FALSE, check.names = FALSE)
    ))
  }
  output <- do.call(rbind, rows)
  row.names(output) <- NULL
  output
}

test_that("Article 19.04 final overall ranking covers all ten bands and Article 19.05 overwrite", {
  interim <- phase15_test_final_interim_rankings()
  complete <- phase15_test_final_stage_outcomes()
  ranked <- uefa_nl_rank_final_overall(interim, complete)
  expected_sources <- c(
    4L, 1L, 3L, 2L, 5L, 6L, 7L, 8L,
    9L:12L, 17L:20L, 13L:16L, 21L:24L,
    25L:28L, 33L:36L, 29L:32L, 37L:40L,
    41L:44L, 45L:46L, 49L:50L, 47L:48L, 51L:52L, 53L:54L
  )
  expect_equal(ranked$final_overall_rank, seq_len(54L))
  expect_identical(ranked$interim_rank, expected_sources)
  expect_identical(ranked$ranking_stage, rep("final_overall", 54L))
  expect_identical(ranked$final_stage_status, rep("completed", 54L))
  expect_true(all(c("final_overall_rank", "ranking_stage", "interim_rank") %in% names(ranked)))
  expect_true(all(grepl("^[0-9a-f]{64}$", ranked$row_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", ranked$table_sha256)))
  expect_equal(ranked$team_id[ranked$final_overall_rank == 1L], "team-final-04")
  expect_equal(ranked$team_id[ranked$final_overall_rank == 2L], "team-final-01")
  expect_equal(ranked$team_id[ranked$final_overall_rank == 3L], "team-final-03")
  expect_equal(ranked$team_id[ranked$final_overall_rank == 4L], "team-final-02")

  pre_finals <- uefa_nl_rank_final_overall(interim, phase15_test_final_stage_outcomes(include_finals = FALSE))
  expected_pre_sources <- c(
    1L:8L, 9L:12L, 17L:20L, 13L:16L, 21L:24L,
    25L:28L, 33L:36L, 29L:32L, 37L:40L,
    41L:44L, 45L:46L, 49L:50L, 47L:48L, 51L:52L, 53L:54L
  )
  expect_identical(pre_finals$ranking_stage, rep("final_overall_pre_finals", 54L))
  expect_identical(pre_finals$final_overall_rank, seq_len(54L))
  expect_identical(pre_finals$interim_rank, expected_pre_sources)
})

test_that("Article 19 final ranking is dynamic for 54 teams and hashes are reverse-order stable", {
  interim <- phase15_test_final_interim_rankings(team_count = 54L)
  ranked <- uefa_nl_rank_final_overall(interim)
  reversed <- uefa_nl_rank_final_overall(interim[nrow(interim):1L, , drop = FALSE])
  expect_equal(nrow(ranked), 54L)
  expect_false(any(ranked$final_overall_rank == 55L))
  expect_equal(max(ranked$final_overall_rank), 54L)
  expect_identical(
    ranked$row_sha256[match(sort(ranked$team_id), ranked$team_id)],
    reversed$row_sha256[match(sort(reversed$team_id), reversed$team_id)]
  )
  expect_identical(unique(ranked$table_sha256), unique(reversed$table_sha256))
})

test_that("blocked Article 19 final inputs never fabricate final ranks", {
  interim <- phase15_test_final_interim_rankings()
  blocked_ranking <- interim
  blocked_ranking$ordering_status[[1L]] <- "blocked"
  blocked_ranking$computed_rank[[1L]] <- NA_integer_
  ranked <- uefa_nl_rank_final_overall(blocked_ranking)
  expect_true(all(is.na(ranked$final_overall_rank)))
  expect_true(all(is.na(ranked$computed_rank)))
  expect_identical(ranked$interim_rank, interim$interim_rank)
  expect_true(all(ranked$ordering_status == "blocked"))
  expect_true(all(ranked$missing_rule_input == "group_ordering"))
  expect_true(all(ranked$ranking_stage == "blocked"))

  blocked_stage <- data.frame(
    stage_id = "league_a_final",
    stage_status = "blocked",
    winner_team_id = "team-final-01",
    loser_team_id = "team-final-02",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  blocked_stage_result <- uefa_nl_rank_final_overall(interim, blocked_stage)
  expect_true(all(is.na(blocked_stage_result$final_overall_rank)))
  expect_true(all(blocked_stage_result$ordering_status == "blocked"))
  expect_true(all(grepl("stage", blocked_stage_result$missing_rule_input)))
})

test_that("C/D cancellation retains exactly C46/C47 and D50/D51 without probabilities", {
  interim <- phase15_test_final_interim_rankings()
  candidate_ids <- interim$team_id[interim$interim_rank %in% c(45L, 46L, 51L, 52L)]
  eligibility <- data.frame(
    team_id = candidate_ids,
    qualifies_for_euro_playoff = c(TRUE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  retained <- uefa_nl_resolve_cd_playoff_cancellation(interim, eligibility)
  expect_equal(nrow(retained), 4L)
  expect_identical(retained$cd_playoff_status, rep("cancelled", 4L))
  expect_identical(retained$selection_status, rep("retained", 4L))
  expect_identical(retained$stage_status, rep("suppressed", 4L))
  expect_identical(
    retained[, c("retained_next_edition_league", "retained_next_edition_rank")],
    data.frame(
      retained_next_edition_league = c("C", "C", "D", "D"),
      retained_next_edition_rank = c(46L, 47L, 50L, 51L),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  expect_true(all(nzchar(retained$cancellation_reason)))
  expect_true(all(is.na(retained$playoff_eligibility_probability)))
  expect_true(all(is.na(retained$playoff_win_probability)))
  expect_true(all(is.na(retained$playoff_loss_probability)))
  expect_true(all(grepl("^[0-9a-f]{64}$", retained$row_sha256)))

  selected <- uefa_nl_select_transition_slots(interim, eligibility)
  cancelled <- selected[selected$cd_playoff_status == "cancelled", , drop = FALSE]
  expect_equal(nrow(cancelled), 4L)
  expect_setequal(cancelled$retained_next_edition_rank, c(46L, 47L, 50L, 51L))
})

test_that("absent and incomplete C/D eligibility remain unresolved with no retention claims", {
  interim <- phase15_test_final_interim_rankings()
  absent <- uefa_nl_resolve_cd_playoff_cancellation(interim, NULL)
  incomplete <- uefa_nl_resolve_cd_playoff_cancellation(
    interim,
    data.frame(team_id = "team-final-45", qualifies_for_euro_playoff = FALSE, stringsAsFactors = FALSE, check.names = FALSE)
  )
  for (result in list(absent, incomplete)) {
    expect_true(all(result$eligibility_status == "unresolved_external_eligibility"))
    expect_true(all(result$cd_playoff_status == "unresolved"))
    expect_true(all(is.na(result$retained_next_edition_league)))
    expect_true(all(is.na(result$retained_next_edition_rank)))
    expect_true(all(result$cancellation_reason == ""))
    expect_true(all(is.na(result$playoff_eligibility_probability)))
    expect_true(all(is.na(result$playoff_win_probability)))
    expect_true(all(is.na(result$playoff_loss_probability)))
  }
})

test_that("calibrated outcome sampling conditions scorelines without changing W/D/L mass", {
  fixture <- phase15_test_calibrated_forecast()
  conditioned <- uefa_nl_condition_score_distribution(
    fixture$score_distributions,
    outcome_class = "home",
    calibrated_probabilities = fixture$probabilities
  )
  expect_equal(sum(conditioned$probability), fixture$probabilities[["home"]], tolerance = 1e-12)
  expect_equal(sum(conditioned$probability[conditioned$outcome_class != "home"]), 0, tolerance = 1e-12)
  all_conditioned <- uefa_nl_condition_score_distribution(
    fixture$score_distributions,
    calibrated_probabilities = fixture$probabilities
  )
  expect_equal(sum(all_conditioned$probability), 1, tolerance = 1e-12)
  expect_equal(
    unname(vapply(c("home", "draw", "away"), function(value) sum(all_conditioned$probability[all_conditioned$outcome_class == value]), numeric(1))),
    unname(fixture$probabilities),
    tolerance = 1e-12
  )

  samples <- uefa_nl_sample_calibrated_outcome(fixture$probabilities, n = 100000L, seed = 15017L)
  empirical <- prop.table(table(factor(samples, levels = c("home", "draw", "away"))))
  expect_lte(max(abs(as.numeric(empirical) - unname(fixture$probabilities))), 0.01)
  expect_error(
    uefa_nl_sample_calibrated_outcome(c(home = 0.5, draw = 0.3, away = 0.3)),
    "sum to one"
  )
  invalid_grid <- fixture$score_distributions
  invalid_grid$probability[[1L]] <- invalid_grid$probability[[1L]] + 0.1
  expect_error(
    uefa_nl_condition_score_distribution(invalid_grid, "home", fixture$probabilities),
    "normalized"
  )
  missing_category <- fixture$score_distributions[fixture$score_distributions$home_goals <= fixture$score_distributions$away_goals, , drop = FALSE]
  missing_category$probability <- missing_category$probability / sum(missing_category$probability)
  expect_error(
    uefa_nl_condition_score_distribution(missing_category, "home", fixture$probabilities),
    "category is empty"
  )
  sampled <- uefa_nl_sample_stage_match(fixture$forecasts, fixture$score_distributions, seed = 15017L)
  expect_identical(sampled$stage_status, "projected")
  expect_true(sampled$home_goals[[1L]] >= 0L)
  expect_true(sampled$away_goals[[1L]] >= 0L)
  expect_identical(sampled$probability_sampling_policy, "calibrated_1x2_conditional_score_grid")
})

test_that("Article 14-18 resolution preserves reciprocal legs, aggregate ties, extra time, and penalties", {
  pair <- phase15_test_two_leg_pair()
  expect_silent(uefa_nl_validate_two_leg_pair(pair$valid, lower_league_team_id = pair$lower_league_team_id))
  invalid <- pair$valid
  invalid$home_team_id <- c(pair$lower_league_team_id, pair$lower_league_team_id)
  expect_error(uefa_nl_validate_two_leg_pair(invalid), "invalid same-side row|host each participant exactly once|same unordered participants")

  aggregate_pair <- pair$valid
  aggregate_pair$stage_id <- "a_b_playoff"
  aggregate_pair$regulation_home_goals <- c(0L, 2L)
  aggregate_pair$regulation_away_goals <- c(1L, 0L)
  aggregate_pair$final_home_goals <- aggregate_pair$regulation_home_goals
  aggregate_pair$final_away_goals <- aggregate_pair$regulation_away_goals
  aggregate <- uefa_nl_resolve_two_leg_tie(aggregate_pair, lower_league_team_id = pair$lower_league_team_id, seed = 15017L)
  expect_identical(aggregate$winner_team_id, pair$higher_league_team_id)
  expect_identical(aggregate$resolution, "aggregate")

  extra_time_pair <- pair$valid
  extra_time_pair$stage_id <- "a_b_playoff"
  extra_time_pair$regulation_home_goals <- c(1L, 1L)
  extra_time_pair$regulation_away_goals <- c(0L, 0L)
  extra_time_pair$extra_time_home_goals <- c(0L, 1L)
  extra_time_pair$extra_time_away_goals <- c(0L, 0L)
  extra_time_pair$final_home_goals <- extra_time_pair$regulation_home_goals + extra_time_pair$extra_time_home_goals
  extra_time_pair$final_away_goals <- extra_time_pair$regulation_away_goals + extra_time_pair$extra_time_away_goals
  extra_time <- uefa_nl_resolve_two_leg_tie(extra_time_pair, lower_league_team_id = pair$lower_league_team_id, seed = 15017L)
  expect_identical(extra_time$winner_team_id, pair$higher_league_team_id)
  expect_identical(extra_time$resolution, "extra_time")
  expect_true(extra_time$extra_time_used)

  penalty_pair <- pair$valid
  penalty_pair$stage_id <- "a_b_playoff"
  penalty_pair$regulation_home_goals <- c(1L, 1L)
  penalty_pair$regulation_away_goals <- c(0L, 0L)
  penalty_pair$extra_time_home_goals <- c(0L, 0L)
  penalty_pair$extra_time_away_goals <- c(0L, 0L)
  penalty_pair$final_home_goals <- penalty_pair$regulation_home_goals
  penalty_pair$final_away_goals <- penalty_pair$regulation_away_goals
  penalty_pair$penalty_shootout_home_goals <- c(NA_integer_, 5L)
  penalty_pair$penalty_shootout_away_goals <- c(NA_integer_, 4L)
  penalty <- uefa_nl_resolve_two_leg_tie(penalty_pair, lower_league_team_id = pair$lower_league_team_id, seed = 15017L)
  expect_identical(penalty$winner_team_id, pair$higher_league_team_id)
  expect_identical(penalty$resolution, "penalties")
  expect_true(penalty$penalty_used)

  final <- data.frame(home_team_id = "final-home", away_team_id = "final-away", regulation_home_goals = 1L, regulation_away_goals = 1L, extra_time_home_goals = 1L, extra_time_away_goals = 0L, final_home_goals = 2L, final_away_goals = 1L, stringsAsFactors = FALSE)
  final_result <- uefa_nl_resolve_single_leg(final, mode = "final", seed = 15017L)
  expect_identical(final_result$winner_team_id, "final-home")
  expect_identical(final_result$resolution, "extra_time")
  third <- final
  third$extra_time_home_goals <- 0L
  third$extra_time_away_goals <- 0L
  third$final_home_goals <- 1L
  third$final_away_goals <- 1L
  third$penalty_shootout_home_goals <- 4L
  third$penalty_shootout_away_goals <- 3L
  third_result <- uefa_nl_resolve_single_leg(third, mode = "direct_penalty", seed = 15017L)
  expect_identical(third_result$winner_team_id, "final-home")
  expect_identical(third_result$resolution, "penalties")
})

test_that("Article 17 draw policies enforce different groups and host-driven Team A ordering", {
  winners <- data.frame(team_id = paste0("team-a-w", 1:4), group_id = paste0("A", 1:4), league = "A", group_position = 1L, stringsAsFactors = FALSE)
  runners <- data.frame(team_id = paste0("team-a-r", 1:4), group_id = paste0("A", 1:4), league = "A", group_position = 2L, stringsAsFactors = FALSE)
  qf <- uefa_nl_draw_quarter_finals(winners, runners, seed = 15017L, projection_run_id = "projection-test")
  expect_equal(nrow(qf$stage_slots), 8L)
  expect_true(all(qf$stage_slots$stage_status == "projected"))
  expect_true(all(qf$stage_slots$source_fixture_id == ""))
  expect_true(all(nzchar(qf$stage_slots$projection_run_id)))
  expect_true(all(nzchar(qf$stage_slots$draw_policy_id)))
  expect_equal(sum(qf$pairings$group_a == qf$pairings$group_b), 0L)
  expect_equal(length(unique(c(qf$pairings$team_a, qf$pairings$team_b))), 8L)
  illegal_winners <- winners
  illegal_runners <- runners
  illegal_runners$group_id <- rep("A1", 4L)
  expect_error(uefa_nl_draw_quarter_finals(illegal_winners, illegal_runners), "no legal different-group pairing")
  duplicate_winners <- winners
  duplicate_winners$team_id[[2L]] <- duplicate_winners$team_id[[1L]]
  expect_error(uefa_nl_draw_quarter_finals(duplicate_winners, runners), "duplicate teams")

  semi_input <- data.frame(
    team_id = c("team-a-host", "team-a-s2", "team-a-s3", "team-a-s4"),
    association_id = c("association-host", "association-2", "association-3", "association-4"),
    stringsAsFactors = FALSE
  )
  semis <- uefa_nl_draw_semi_finals(semi_input, host_association_id = "association-host", seed = 15017L, projection_run_id = "projection-test")
  expect_identical(semis$semi_finals$team_a[[1L]], "team-a-host")
  expect_identical(semis$final_team_a_source, "semi-final-1-winner")
  expect_identical(semis$third_place_team_a_source, "semi-final-1-loser")
  expect_identical(semis$final_slot$participant_slot_home[[1L]], "semi-final-1-winner")
  expect_identical(semis$third_place_slot$participant_slot_home[[1L]], "semi-final-1-loser")
  expect_equal(sum(semis$stage_slots$stage_id == "league_a_semi_final"), 2L)
  expect_equal(sum(semis$stage_slots$stage_id == "league_a_final"), 1L)
  expect_equal(sum(semis$stage_slots$stage_id == "league_a_third_place"), 1L)
})

test_that("simulation replay preserves RNG, hashes, and probability mass", {
  inputs <- phase15_test_simulation_inputs(simulation_count = 2L)
  before_inputs <- list(
    canonical_matches = phase15_test_table_sha256(inputs$canonical_matches),
    forecast_status = phase15_test_table_sha256(inputs$forecast_status),
    forecasts = phase15_test_table_sha256(inputs$forecasts),
    score_distributions = phase15_test_table_sha256(inputs$score_distributions)
  )

  set.seed(90210L)
  rng_before <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  first <- do.call(uefa_nl_run_simulation, inputs)
  rng_after <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  second <- do.call(uefa_nl_run_simulation, inputs)

  expect_identical(rng_after, rng_before)
  expect_identical(first$output_hashes, second$output_hashes)
  expect_identical(first$projected_standings, second$projected_standings)
  expect_identical(first$projected_rankings, second$projected_rankings)
  expect_identical(first$transition_outcomes, second$transition_outcomes)
  expect_identical(first$canonical_input_hashes, second$canonical_input_hashes)
  expect_identical(before_inputs$canonical_matches, phase15_test_table_sha256(inputs$canonical_matches))
  expect_identical(before_inputs$forecast_status, phase15_test_table_sha256(inputs$forecast_status))
  expect_identical(before_inputs$forecasts, phase15_test_table_sha256(inputs$forecasts))
  expect_identical(before_inputs$score_distributions, phase15_test_table_sha256(inputs$score_distributions))
  expect_true(all(c("final_overall_rank", "ranking_stage") %in% names(first$projected_rankings)))
  expect_true(grepl("(^|;)final_overall_pre_finals(;|$)", first$simulation_metadata$ranking_stages[[1L]]))
  expect_true(nzchar(first$simulation_metadata$ranking_stages_sha256[[1L]]))
  expect_identical(first$simulation_metadata$final_ranking_stages[[1L]], "final_overall_pre_finals")
  expect_true(nzchar(first$simulation_metadata$final_ranking_stages_sha256[[1L]]))

  reversed <- inputs
  reversed$canonical_matches <- reversed$canonical_matches[nrow(reversed$canonical_matches):1L, , drop = FALSE]
  reversed$forecast_status <- reversed$forecast_status[nrow(reversed$forecast_status):1L, , drop = FALSE]
  reversed$forecasts <- reversed$forecasts[nrow(reversed$forecasts):1L, , drop = FALSE]
  reversed$score_distributions <- reversed$score_distributions[nrow(reversed$score_distributions):1L, , drop = FALSE]
  reversed$groups$groups <- reversed$groups$groups[nrow(reversed$groups$groups):1L, , drop = FALSE]
  reversed$groups$group_rows <- reversed$groups$group_rows[nrow(reversed$groups$group_rows):1L, , drop = FALSE]
  reversed_result <- do.call(uefa_nl_run_simulation, reversed)
  expect_identical(first$output_hashes, reversed_result$output_hashes)

  open_id <- inputs$canonical_matches$fixture_id[[1L]]
  open_outcome <- first$outcome_probabilities[first$outcome_probabilities$fixture_id == open_id, , drop = FALSE]
  expect_equal(nrow(open_outcome), 1L)
  expect_equal(sum(as.numeric(open_outcome[1L, c("p_home", "p_draw", "p_away")])), 1, tolerance = 1e-12)
  mass <- aggregate(probability ~ league + group_id + rank, first$projected_standings, sum, na.action = na.omit)
  expect_true(all(abs(mass$probability - 1) <= 1e-12))
})

test_that("replay verification compares every registered artifact key exactly", {
  replay_environment <- new.env(parent = .GlobalEnv)
  sys.source(
    file.path(phase15_test_project_root, "scripts/build_nations_league_outcomes.R"),
    envir = replay_environment
  )
  compare_replays <- replay_environment$phase15_nl_compare_replays
  expected <- replay_environment$phase15_nl_outcomes_expected_inventory()
  artifacts <- setNames(
    lapply(expected, function(path) {
      data.frame(non_explicit_artifact_column = "before", stringsAsFactors = FALSE)
    }),
    expected
  )
  first <- list(artifacts = artifacts, parent_graph = list())
  second <- first
  second$artifacts[[expected[[1L]]]]$non_explicit_artifact_column <- "after"

  expect_silent(compare_replays(first, first))
  expect_error(compare_replays(first, second), "artifact bytes")
})

test_that("official stage capture replay is stable and C/D branches stay explicit", {
  inputs <- phase15_test_simulation_inputs(simulation_count = 1L)
  base <- do.call(uefa_nl_run_simulation, inputs)
  interim <- base$projected_rankings[base$projected_rankings$ranking_scope == "interim_overall", , drop = FALSE]
  candidate <- function(rank) as.character(interim$team_id[interim$interim_overall_rank == rank][[1L]])
  all_teams <- unique(inputs$groups$group_rows$team_id)

  unresolved <- base$transition_outcomes[base$transition_outcomes$stage_id == "c_d_playoff", , drop = FALSE]
  expect_equal(nrow(unresolved), 4L)
  expect_setequal(unresolved$lower_league_rank[unresolved$league == "D"], c(50L, 51L))
  expect_true(all(unresolved$eligibility_status == "unresolved_external_eligibility"))
  expect_true(all(unresolved$stage_status == "unresolved"))
  expect_true(all(is.na(unresolved$retained_next_edition_league)))

  cancellation <- inputs
  cancellation$euro_playoff_eligibility <- data.frame(
    team_id = all_teams,
    qualifies_for_euro_playoff = FALSE,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  cancellation$euro_playoff_eligibility$qualifies_for_euro_playoff[
    match(vapply(c(45L, 46L, 51L, 52L), candidate, character(1)), cancellation$euro_playoff_eligibility$team_id)
  ] <- TRUE
  cancelled <- do.call(uefa_nl_run_simulation, cancellation)
  retained <- cancelled$transition_outcomes[
    cancelled$transition_outcomes$stage_id == "c_d_playoff" & cancelled$transition_outcomes$cd_playoff_status == "cancelled",
    , drop = FALSE
  ]
  expect_equal(nrow(retained), 4L)
  expect_setequal(retained$interim_rank, c(46L, 47L, 50L, 51L))
  expect_identical(retained$stage_status, rep("suppressed", 4L))
  expect_identical(retained$retained_next_edition_league, c("C", "C", "D", "D"))
  expect_setequal(retained$retained_next_edition_rank, c(46L, 47L, 50L, 51L))
  expect_true(all(nzchar(retained$cancellation_reason)))
  expect_true(all(is.na(retained$playoff_eligibility_probability)))
  expect_true(all(is.na(retained$playoff_win_probability)))
  expect_true(all(is.na(retained$playoff_loss_probability)))
  expect_identical(cancelled$output_hashes, do.call(uefa_nl_run_simulation, cancellation)$output_hashes)

  contest <- inputs
  contest$euro_playoff_eligibility <- data.frame(
    team_id = all_teams,
    qualifies_for_euro_playoff = FALSE,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  contested <- do.call(uefa_nl_run_simulation, contest)$transition_outcomes
  contested <- contested[contested$stage_id == "c_d_playoff" & contested$cd_playoff_status == "contested", , drop = FALSE]
  expect_equal(nrow(contested), 4L)
  expect_true(all(contested$eligibility_status == "eligible"))
  expect_true(all(contested$stage_status == "unresolved"))
  expect_true(all(is.na(contested$playoff_win_probability)))
  expect_true(all(is.na(contested$playoff_loss_probability)))

  captured <- inputs
  captured$official_stage_slots <- phase15_test_completed_stage_capture()
  captured_reversed <- captured
  captured_reversed$official_stage_slots <- captured_reversed$official_stage_slots[nrow(captured_reversed$official_stage_slots):1L, , drop = FALSE]
  capture_a <- do.call(uefa_nl_run_simulation, captured)
  capture_b <- do.call(uefa_nl_run_simulation, captured_reversed)
  expect_identical(capture_a$output_hashes, capture_b$output_hashes)
  expect_true(any(capture_a$stage_slots$source_fixture_id == "source-qf-1"))
})

# Plan 15-01 extension points: topology, stage-slot, source-admission, and group-formation APIs.
# Plan 15-02 extension points: Article 15 group ranking, Article 19 rankings, and transitions.
# Plan 15-03 extension points: calibrated sampling, stage resolution, draw policies, and simulation.
# Plan 15-04 extension points: outcomes schema, stage-capture loading, and forecast/form pass-through.
# Plan 15-05 extension points: the nine-file writer, dry-run, and replay entrypoint.
# Plan 15-06 extension points: production acceptance, no-leakage, and registered-root checks.

test_that("Phase 15 outcome inventory and fixture pass-through stay outside Phase 14 state", {
  expected <- phase15_nl_outcomes_expected_inventory()
  expect_length(expected, 9L)
  expect_identical(expected[[7L]], "outcomes/fixture_forecast_form.csv")
  expect_false(any(expected %in% phase14_state_bundle_expected_inventory()))
  expect_identical(names(phase15_nl_outcomes_schema()), c(
    "competition_topology", "stage_slots", "projected_standings", "projected_rankings",
    "transition_outcomes", "team_path_probabilities", "fixture_forecast_form",
    "simulation_metadata", "outcomes_manifest"
  ))

  state <- phase15_nl_read_phase14_state_bundle(phase15_test_project_root)
  pass_through <- phase15_nl_build_fixture_forecast_form(
    state$canonical_matches,
    state$forecast_status,
    state$forecasts,
    state$competition_form,
    state$all_international_form,
    state$state_manifest,
    state$score_distributions,
    state$source
  )
  expect_equal(nrow(pass_through), nrow(state$canonical_matches))
  expect_true(any(pass_through$forecast_status == "available"))
  expect_true(all(pass_through$competition_form_status == "unavailable"))
  expect_true(all(pass_through$competition_form_window_type == "no_eligible_form_history"))
  expect_true(all(pass_through$all_international_form_status == "unavailable"))
})

test_that("Phase 15 candidate writer and loader preserve the hashed sibling contract", {
  state <- phase15_nl_read_phase14_state_bundle(phase15_test_project_root)
  source <- state$source
  topology <- uefa_nl_build_topology(groups = source$groups, fixtures = source$fixtures)
  empty <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  metadata <- data.frame(
    edition_id = phase15_test_edition_id,
    projection_run_id = "phase15-test-projection",
    simulation_seed = 15017L,
    simulation_count = 1L,
    draw_policy_id = "phase15-test-draw-policy",
    draw_policy_sha256 = phase15_test_hash_token("draw-policy"),
    ruleset_version = uefa_nl_ruleset_version(),
    ruleset_sha256 = uefa_nl_ruleset_sha256(uefa_nl_2026_27_rules()),
    source_bundle_id = source$source_bundle_id,
    source_bundle_sha256 = source$source_bundle_sha256,
    model_release_id = state$model_release_id,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  simulation <- list(
    projected_standings = empty,
    projected_rankings = empty,
    transition_outcomes = empty,
    team_path_probabilities = empty,
    stage_slots = empty,
    simulation_metadata = metadata,
    metadata = as.list(metadata[1L, , drop = FALSE]),
    output_hashes = list()
  )
  candidate <- phase15_build_nl_outcomes_candidate(
    simulation,
    topology = topology,
    source = source,
    state_bundle = state,
    project_root = phase15_test_project_root
  )
  expect_silent(phase15_validate_nl_outcomes_bundle(candidate))
  output_root <- phase15_test_output_root()
  written <- phase15_write_nl_outcomes_bundle(candidate, output_root = output_root)
  expect_length(written$artifacts, 9L)
  expect_identical(names(written$artifacts), phase15_nl_outcomes_expected_inventory())
  expect_identical(names(written$fixture_forecast_form), names(candidate$artifacts[["outcomes/fixture_forecast_form.csv"]]))
  loaded <- phase15_nl_read_outcomes_bundle(output_root)
  expect_identical(loaded$fixture_forecast_form, written$fixture_forecast_form)
})

test_that("registered Nations League compatibility entrypoint rejects foreign and conflicting modes", {
  help <- phase15_test_run_outcomes_cli("--help")
  expect_identical(help$status, 0L)
  expect_true(grepl("Usage:", help$output, fixed = TRUE))
  expect_true(grepl("--replay-check", help$output, fixed = TRUE))

  foreign <- phase15_test_run_outcomes_cli(c(
    "--edition-id", "uefa_euro_2028", "--dry-run"
  ))
  expect_false(identical(foreign$status, 0L))
  expect_true(grepl("Unsupported edition-id", foreign$output, fixed = TRUE))

  conflicting <- phase15_test_run_outcomes_cli(c(
    "--edition-id", phase15_test_edition_id, "--write", "--dry-run"
  ))
  expect_false(identical(conflicting$status, 0L))
  expect_true(grepl("cannot be combined", conflicting$output, fixed = TRUE))
})

test_that("Phase 15 production acceptance proves current truth, replay identity, and no leakage", {
  expected_resources <- c("fixtures", "groups", "standings", "results", "status")
  expected_inventory <- phase15_nl_outcomes_expected_inventory()
  durable_root <- file.path(
    phase15_test_project_root,
    "outputs/competition/uefa_nations_league_2026_27/outcomes"
  )
  before <- phase15_test_production_inputs()
  outcomes_before <- phase15_test_tree_snapshot(durable_root)

  source <- before$source
  fixtures <- source$fixtures
  groups <- source$groups
  results <- source$results
  expect_identical(before$phase13_resources, expected_resources)
  expect_equal(nrow(fixtures), 156L)
  expect_equal(nrow(groups), 14L)
  expect_equal(nrow(source$standings), 0L)
  expect_equal(
    length(unique(c(as.character(fixtures$home_team_id), as.character(fixtures$away_team_id)))),
    54L
  )
  expect_identical(as.character(source$status$competition_status), "scheduled")
  expect_true(all(toupper(as.character(fixtures$source_status)) == "UPCOMING"))
  expect_true(all(as.logical(fixtures$kickoff_confirmed)))
  expect_identical(
    as.character(results$uefa_source_fixture_id),
    as.character(fixtures$uefa_source_fixture_id)
  )
  expect_true(all(as.character(results$match_status) == "scheduled"))
  expect_true(all(is.na(results$home_goals) & is.na(results$away_goals)))
  expect_true(all(!as.logical(results$counts_for_standings) & !as.logical(results$counts_for_form)))

  topology <- before$topology
  expect_identical(topology$official_counts, c(groups = 14L, fixtures = 156L, teams = 54L))
  expect_identical(topology$group_formation_status, "unresolved_access_list")
  expect_identical(topology$missing_rule_input, "access_list")
  expect_true(all(is.na(topology$teams$access_list_position)))
  expect_true(all(is.na(topology$teams$draw_pot)))
  expect_true(all(nzchar(as.character(topology$teams$source_artifact_id))))
  expect_setequal(
    as.character(topology$stage_topology$stage_id),
    c(
      "league_phase", "league_a_quarter_final", "league_a_semi_final",
      "league_a_third_place", "league_a_final", "a_b_playoff",
      "b_c_playoff", "c_d_playoff"
    )
  )

  capture <- before$stage_capture
  expect_identical(capture$capture_status, "empty")
  expect_equal(nrow(capture$stage_capture), 0L)
  expect_identical(names(capture$stage_capture), phase15_uefa_nl_stage_capture_schema())
  expect_identical(as.character(capture$manifest$capture_status[[1L]]), "empty")
  expect_identical(
    as.character(capture$registry$manifest_sha256[[1L]]),
    as.character(capture$manifest$manifest_sha256[[1L]])
  )

  admitted_inputs <- phase15_test_admitted_topology_inputs()
  admitted_access <- uefa_nl_validate_access_list(admitted_inputs$access)
  admitted_formation <- uefa_nl_validate_group_formation(
    admitted_access,
    admitted_inputs$group_rows,
    group_formation_seed = 15013L
  )
  expect_identical(admitted_access$status, "validated")
  expect_identical(admitted_formation$group_formation_status, "validated")
  expect_equal(nrow(admitted_formation$rows), 54L)
  expect_true(all(!is.na(admitted_formation$rows$access_list_position)))
  expect_true(all(nzchar(admitted_formation$rows$draw_pot)))
  current_access <- uefa_nl_validate_access_list(NULL, topology$teams, phase15_test_edition_id)
  current_formation <- uefa_nl_validate_group_formation(
    current_access,
    topology$teams,
    group_formation_seed = 15013L,
    edition_id = phase15_test_edition_id
  )
  expect_identical(current_access$status, "unresolved_access_list")
  expect_identical(current_formation$group_formation_status, "unresolved_access_list")
  expect_true(all(is.na(current_access$rows$access_list_position)))
  expect_true(all(is.na(current_access$rows$draw_pot)))
  expect_true(all(current_access$rows$status == "unresolved_access_list"))

  interim <- phase15_test_final_interim_rankings()
  post_final <- uefa_nl_rank_final_overall(interim, phase15_test_final_stage_outcomes())
  pre_final <- uefa_nl_rank_final_overall(
    interim,
    phase15_test_final_stage_outcomes(include_finals = FALSE)
  )
  expect_identical(post_final$final_overall_rank, seq_len(54L))
  expect_identical(post_final$ranking_stage, rep("final_overall", 54L))
  expect_identical(pre_final$final_overall_rank, seq_len(54L))
  expect_identical(pre_final$ranking_stage, rep("final_overall_pre_finals", 54L))
  expect_identical(
    post_final$team_id[match(1:4, post_final$final_overall_rank)],
    c("team-final-04", "team-final-01", "team-final-03", "team-final-02")
  )

  blocked_group <- phase15_test_four_team_group()
  blocked_group$matches$state_cutoff_utc <- "2026-12-31T00:00:00Z"
  blocked <- uefa_nl_rank_group(
    blocked_group$standings,
    blocked_group$matches,
    discipline_points = NULL,
    access_list = blocked_group$access_list
  )
  expect_true(all(is.na(blocked$computed_rank)))
  expect_true(all(blocked$ordering_status == "blocked"))
  expect_true(all(grepl("discipline_points", blocked$missing_rule_input)))
  expect_true(all(blocked$suppression_reason == "missing_rule_input"))

  cancellation_eligibility <- data.frame(
    team_id = interim$team_id,
    qualifies_for_euro_playoff = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  cancellation_eligibility$qualifies_for_euro_playoff[
    match(interim$team_id[interim$interim_rank %in% c(45L, 46L, 51L, 52L)], cancellation_eligibility$team_id)
  ] <- TRUE
  cancelled <- uefa_nl_resolve_cd_playoff_cancellation(interim, cancellation_eligibility)
  expect_identical(cancelled$cd_playoff_status, rep("cancelled", 4L))
  expect_identical(cancelled$stage_status, rep("suppressed", 4L))
  expect_identical(
    cancelled[, c("retained_next_edition_league", "retained_next_edition_rank")],
    data.frame(
      retained_next_edition_league = c("C", "C", "D", "D"),
      retained_next_edition_rank = c(46L, 47L, 50L, 51L),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  expect_true(all(nzchar(cancelled$cancellation_reason)))
  expect_true(all(is.na(cancelled$playoff_eligibility_probability)))
  unresolved_cd <- uefa_nl_resolve_cd_playoff_cancellation(interim, NULL)
  expect_true(all(unresolved_cd$eligibility_status == "unresolved_external_eligibility"))
  expect_true(all(unresolved_cd$cd_playoff_status == "unresolved"))
  expect_true(all(is.na(unresolved_cd$retained_next_edition_rank)))
  expect_true(all(is.na(unresolved_cd$playoff_win_probability)))

  host <- phase15_test_host_association()
  host_draw <- uefa_nl_draw_semi_finals(
    data.frame(
      team_id = c("team-a-host", "team-a-s2", "team-a-s3", "team-a-s4"),
      association_id = c("association-host", "association-2", "association-3", "association-4"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    host_association_id = host$association_id,
    seed = 15017L,
    projection_run_id = "phase15-production-acceptance"
  )
  expect_identical(host_draw$semi_finals$team_a[[1L]], host$host_team_id)
  expect_identical(host_draw$final_team_a_source, "semi-final-1-winner")
  expect_identical(host_draw$third_place_team_a_source, "semi-final-1-loser")

  completed_capture <- phase15_test_completed_stage_capture()
  completed_score_fields <- c(
    "regulation_home_goals", "regulation_away_goals", "extra_time_home_goals",
    "extra_time_away_goals", "penalty_shootout_home_goals",
    "penalty_shootout_away_goals", "final_home_goals", "final_away_goals",
    "completed_at_utc"
  )
  expect_true(all(completed_score_fields %in% names(completed_capture)))
  expect_setequal(
    unique(completed_capture$stage_id),
    c(
      "league_a_quarter_final", "league_a_semi_final", "league_a_final",
      "a_b_playoff", "b_c_playoff", "c_d_playoff"
    )
  )
  expect_true(all(nzchar(completed_capture$source_fixture_id)))
  expect_true(all(nzchar(completed_capture$source_artifact_id)))
  expect_true(all(nzchar(completed_capture$completed_at_utc)))
  expect_silent(phase15_uefa_nl_validate_stage_capture(phase15_test_adapter_stage_capture()))

  dry_run <- phase15_test_run_entrypoint(c(
    "--edition-id", phase15_test_edition_id,
    "--simulations", "1", "--seed", "15017", "--dry-run"
  ))
  expect_identical(dry_run$status, 0L)
  expect_true(grepl("artifact_count=9", dry_run$output, fixed = TRUE))
  expect_true(grepl("validation=TRUE", dry_run$output, fixed = TRUE))
  expect_true(grepl("durable_mutation=FALSE", dry_run$output, fixed = TRUE))
  expect_true(grepl("stage_capture_id=nl-2026-27-stage-capture-v1", dry_run$output, fixed = TRUE))
  for (value in c(
    capture$manifest$raw_sha256[[1L]],
    capture$manifest$capture_content_sha256[[1L]],
    capture$manifest$manifest_sha256[[1L]],
    capture$registry$row_sha256[[1L]]
  )) {
    expect_true(grepl(as.character(value), dry_run$output, fixed = TRUE))
  }
  expect_identical(phase15_test_tree_snapshot(durable_root), outcomes_before)

  replay <- phase15_test_run_entrypoint(c(
    "--edition-id", phase15_test_edition_id,
    "--simulations", "1", "--seed", "15017", "--replay-check"
  ))
  expect_identical(replay$status, 0L)
  expect_true(grepl("replay_verified=TRUE", replay$output, fixed = TRUE))
  expect_true(grepl("durable_mutation=FALSE", replay$output, fixed = TRUE))
  expect_true(grepl("stage_capture_registry_row_sha256=", replay$output, fixed = TRUE))
  expect_identical(phase15_test_tree_snapshot(durable_root), outcomes_before)

  after <- phase15_test_production_inputs()
  expect_silent(phase15_test_assert_phase14_immutable(before, after))
  expect_identical(before$accepted_tree, after$accepted_tree)
  expect_identical(before$registry_tree, after$registry_tree)

  bundle <- phase15_nl_read_outcomes_bundle(durable_root)
  expect_identical(names(bundle$artifacts), expected_inventory)
  manifest <- bundle$manifest
  expect_identical(as.character(manifest$artifact_path), expected_inventory)
  for (path in expected_inventory) {
    row <- manifest[manifest$artifact_path == path, , drop = FALSE]
    expect_equal(nrow(row), 1L)
    artifact <- bundle$artifacts[[path]]
    expect_identical(as.integer(row$row_count[[1L]]), as.integer(nrow(artifact)))
    if (!identical(path, "outcomes/outcomes_manifest.csv")) {
      expect_identical(
        tolower(as.character(row$content_sha256[[1L]])),
        tolower(phase15_nl_table_content_hash(artifact))
      )
    }
  }
  expect_true(all(as.integer(manifest$simulation_seed) == 15017L))
  expect_true(all(as.integer(manifest$simulation_count) == 1L))
  expect_true(all(as.character(manifest$validation_status) == "valid"))

  stage_slots <- bundle$artifacts[["outcomes/stage_slots.csv"]]
  blank <- function(value) is.na(value) | !nzchar(trimws(as.character(value)))
  expect_true(all(stage_slots$stage_id %in% topology$stage_topology$stage_id))
  projected <- stage_slots[stage_slots$stage_status %in% c("projected", "unresolved", "suppressed"), , drop = FALSE]
  expect_true(nrow(projected) > 0L)
  expect_true(all(blank(projected$source_fixture_id)))
  expect_true(all(blank(projected$source_artifact_id)))
  expect_true(all(stage_slots$stage_status %in% c("projected", "unresolved", "suppressed", "official", "completed")))

  metadata <- bundle$simulation_metadata
  expect_identical(as.integer(metadata$simulation_seed[[1L]]), 15017L)
  expect_identical(as.integer(metadata$simulation_count[[1L]]), 1L)
  expect_identical(as.character(metadata$source_bundle_id[[1L]]), source$source_bundle_id)
  expect_identical(as.character(metadata$source_bundle_sha256[[1L]]), source$source_bundle_sha256)
  expect_identical(as.character(metadata$state_manifest_sha256[[1L]]), before$state_bundle$state_manifest_sha256)
  expect_identical(as.character(metadata$ruleset_version[[1L]]), before$rules$ruleset_version)
  expect_identical(as.character(metadata$ruleset_sha256[[1L]]), uefa_nl_ruleset_sha256(before$rules))
  expect_true(nzchar(as.character(metadata$draw_policy_id[[1L]])))
  expect_true(grepl("calibrated_1x2", as.character(metadata$probability_sampling_policy[[1L]]), fixed = TRUE))

  fixture_form <- bundle$fixture_forecast_form
  expect_equal(nrow(fixture_form), 156L)
  expect_setequal(as.character(fixture_form$fixture_id), as.character(before$state_bundle$canonical_matches$fixture_id))
  expect_true(all(as.character(fixture_form$forecast_status) == "available"))
  expect_identical(unique(as.character(fixture_form$primary_probability_view)), "calibrated_1x2")
  expect_true(all(is.finite(as.numeric(fixture_form$p_home))))
  expect_true(all(abs(rowSums(fixture_form[, c("p_home", "p_draw", "p_away")]) - 1) < 1e-12))
  expect_true(all(is.finite(as.numeric(fixture_form$expected_home_goals))))
  expect_true(all(is.finite(as.numeric(fixture_form$expected_away_goals))))
  expect_identical(unique(as.character(fixture_form$competition_form_status)), "unavailable")
  expect_identical(unique(as.character(fixture_form$competition_form_window_type)), "no_eligible_form_history")
  expect_identical(unique(as.character(fixture_form$all_international_form_status)), "unavailable")
  expect_identical(unique(as.character(fixture_form$all_international_form_window_type)), "no_eligible_form_history")
  expect_identical(unique(as.character(fixture_form$source_bundle_id)), source$source_bundle_id)
  expect_identical(unique(as.character(fixture_form$source_bundle_sha256)), source$source_bundle_sha256)
  expect_identical(unique(as.character(fixture_form$parent_state_manifest_sha256)), before$state_bundle$state_manifest_sha256)
  parent_hash <- setNames(
    as.character(before$state_bundle$state_manifest$content_sha256),
    as.character(before$state_bundle$state_manifest$artifact_path)
  )
  expect_identical(unique(as.character(fixture_form$parent_canonical_matches_sha256)), parent_hash[["state/canonical_matches.csv"]])
  expect_identical(unique(as.character(fixture_form$parent_forecast_status_sha256)), parent_hash[["state/forecast_status.csv"]])
  expect_identical(unique(as.character(fixture_form$parent_forecasts_sha256)), parent_hash[["state/forecasts.csv"]])
  expect_identical(unique(as.character(fixture_form$parent_score_distributions_sha256)), parent_hash[["local/score_distributions.rds"]])
  expect_true(all(nzchar(as.character(fixture_form$model_release_id))))
  expect_true(all(nzchar(as.character(fixture_form$model_sha256))))
  expect_true(all(nzchar(as.character(fixture_form$release_manifest_sha256))))
  expect_true(all(nzchar(as.character(fixture_form$release_selector_sha256))))
  expect_true(all(nzchar(as.character(fixture_form$model_data_cutoff))))
  expect_true(all(nzchar(as.character(fixture_form$feature_cutoff_utc))))
  expect_true(all(grepl("^[0-9a-f]{64}$", as.character(fixture_form$feature_cutoff_sha256))))

  stage_manifest_row <- manifest[manifest$artifact_path == "outcomes/stage_slots.csv", , drop = FALSE]
  expect_true(grepl("stage_capture_manifest.csv", stage_manifest_row$parent_paths[[1L]], fixed = TRUE))
  expect_true(grepl("stage_capture.json", stage_manifest_row$parent_paths[[1L]], fixed = TRUE))
  expect_true(grepl("stage_capture.csv", stage_manifest_row$parent_paths[[1L]], fixed = TRUE))
  for (value in c(
    capture$manifest$raw_sha256[[1L]],
    capture$manifest$capture_content_sha256[[1L]],
    capture$manifest$manifest_sha256[[1L]]
  )) {
    expect_true(grepl(as.character(value), stage_manifest_row$parent_sha256[[1L]], fixed = TRUE))
  }

  cd_output <- bundle$artifacts[["outcomes/transition_outcomes.csv"]]
  cd_output <- cd_output[cd_output$stage_id == "c_d_playoff", , drop = FALSE]
  expect_equal(nrow(cd_output), 4L)
  expect_true(all(cd_output$eligibility_status == "unresolved_external_eligibility"))
  expect_true(all(cd_output$stage_status == "unresolved"))
  expect_true(all(cd_output$cd_playoff_status == "unresolved"))
  expect_true(all(is.na(cd_output$playoff_win_probability)))
  expect_true(all(is.na(cd_output$playoff_loss_probability)))

  synthetic <- do.call(
    uefa_nl_run_simulation,
    phase15_test_simulation_inputs(simulation_count = 1L, seed = 15017L)
  )
  path_fields <- intersect(
    c("p_quarter_final", "p_semi_final", "p_third_place", "p_final", "p_champion"),
    names(synthetic$team_path_probabilities)
  )
  expect_true(length(path_fields) > 0L)
  expect_true(any(as.matrix(synthetic$team_path_probabilities[, path_fields, drop = FALSE]) > 0, na.rm = TRUE))
  expect_true(any(synthetic$fixture_forecast_form$primary_probability_view == "calibrated_1x2"))

  expect_identical(
    phase15_nl_validate_output_root(
      phase15_nl_registered_outcomes_root(phase15_test_project_root),
      phase15_test_project_root
    ),
    normalizePath(durable_root, winslash = "/", mustWork = TRUE)
  )
  expect_error(
    phase15_nl_validate_output_root(file.path(tempdir(), "phase15-unregistered"), phase15_test_project_root),
    "registered Nations League outcomes root"
  )
  test_output_root <- phase15_test_output_root()
  on.exit(unlink(test_output_root, recursive = TRUE, force = TRUE), add = TRUE)
  written <- phase15_write_nl_outcomes_bundle(bundle, output_root = test_output_root)
  expect_silent(phase15_validate_nl_outcomes_bundle(written))
  read_back <- phase15_nl_read_outcomes_bundle(test_output_root)
  expect_identical(read_back$manifest$content_sha256, bundle$manifest$content_sha256)
  expect_identical(read_back$manifest$manifest_sha256, bundle$manifest$manifest_sha256)
  for (path in expected_inventory) {
    expect_identical(
      phase15_nl_table_content_hash(read_back$artifacts[[path]]),
      phase15_nl_table_content_hash(bundle$artifacts[[path]])
    )
  }

  expect_identical(phase15_test_tree_snapshot(durable_root), outcomes_before)
})
