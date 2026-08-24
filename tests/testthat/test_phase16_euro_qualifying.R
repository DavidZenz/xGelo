library(testthat)

phase16_test_find_project_root <- function(start = getwd()) {
  candidate <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(candidate, "AGENTS.md")) &&
        dir.exists(file.path(candidate, "tests", "testthat"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  stop("Phase 16 test harness could not resolve the repository root", call. = FALSE)
}

phase16_test_project_root <- phase16_test_find_project_root()
phase16_test_edition_id <- "uefa_euro_2028_qualifying"
phase16_test_source_bundle_id <- "euro-2028-qualifying-official-draw-v1"
phase16_test_ruleset_version <- "uefa-euro-2028-qualifying-v1"
phase16_test_draw_date <- "2026-12-06"

phase16_test_source <- function(relative_path, envir = .GlobalEnv) {
  path <- file.path(phase16_test_project_root, relative_path)
  if (!file.exists(path)) {
    stop(sprintf("missing Phase 16 source file: %s", relative_path), call. = FALSE)
  }
  sys.source(path, envir = envir)
  invisible(path)
}

phase16_test_expect_schema <- function(data, required_columns, label = "fixture") {
  expect_true(is.data.frame(data), info = sprintf("%s must be a data frame", label))
  expect_true(
    all(required_columns %in% names(data)),
    info = sprintf("%s is missing required columns", label)
  )
  invisible(data)
}

phase16_test_empty_table <- function(columns, types = NULL) {
  if (is.null(types)) types <- rep("character", length(columns))
  if (length(types) != length(columns)) {
    stop("Phase 16 empty fixture types must match columns", call. = FALSE)
  }
  values <- lapply(types, function(type) {
    switch(
      type,
      character = character(),
      integer = integer(),
      numeric = numeric(),
      logical = logical(),
      stop(sprintf("unsupported Phase 16 empty fixture type: %s", type), call. = FALSE)
    )
  })
  as.data.frame(setNames(values, columns), stringsAsFactors = FALSE, check.names = FALSE)
}

phase16_test_pre_draw_bundle <- function() {
  list(
    edition_id = phase16_test_edition_id,
    lifecycle_state = "pre_draw",
    forecast_status = "pre_draw",
    forecast_reason = "awaiting_official_draw_and_schedule",
    official_draw_date = phase16_test_draw_date,
    last_refresh_at_utc = "2026-08-23T12:00:00Z",
    source_bundle_id = phase16_test_source_bundle_id,
    ruleset_version = phase16_test_ruleset_version,
    source_confidence = "official_registry_pending",
    warning = "EURO qualifying is awaiting the official draw",
    message = paste(
      "Official groups and the schedule are not available yet.",
      "The draw is expected on 6 December 2026.",
      "Forecasts will appear after a complete official draw-and-schedule bundle is accepted."
    ),
    teams = phase16_test_empty_table(c(
      "team_id", "display_name", "association_id", "group_id", "source_bundle_id"
    )),
    groups = phase16_test_empty_table(c("group_id", "edition_id", "source_bundle_id")),
    fixtures = phase16_test_empty_table(c(
      "fixture_id", "edition_id", "group_id", "home_team_id", "away_team_id",
      "kickoff_confirmed", "confirmed_kickoff_at_utc", "source_bundle_id"
    )),
    standings = phase16_test_empty_table(c("edition_id", "group_id", "team_id", "rank")),
    results = phase16_test_empty_table(c("edition_id", "fixture_id", "home_goals", "away_goals")),
    qualification_ledger = phase16_test_empty_table(c(
      "edition_id", "team_id", "stage", "qualification_status", "probability"
    )),
    host_slots = phase16_test_empty_table(c(
      "host_slot_id", "slot_number", "association_id", "team_id", "slot_status",
      "consumes_capacity", "source_bundle_id", "ruleset_version"
    )),
    topology = phase16_test_empty_table(c(
      "reserved_slots_used", "entrant_count", "structure", "places", "status"
    )),
    probabilities = phase16_test_empty_table(c("edition_id", "team_id", "probability"))
  )
}

test_that("phase16_smoke", {
  bundle <- phase16_test_pre_draw_bundle()

  expect_true(
    identical(bundle$lifecycle_state, "pre_draw"),
    info = "D-14 keeps pre_draw explicit rather than fabricating structure"
  )
  expect_identical(bundle$edition_id, phase16_test_edition_id)
  expect_identical(bundle$forecast_status, "pre_draw")
  expect_identical(bundle$forecast_reason, "awaiting_official_draw_and_schedule")
  expect_identical(bundle$official_draw_date, "2026-12-06")
  expect_identical(bundle$warning, "EURO qualifying is awaiting the official draw")
  expect_true(grepl("Official groups and the schedule are not available yet", bundle$message, fixed = TRUE))
  expect_true(grepl("6 December 2026", bundle$message, fixed = TRUE))
  expect_true(grepl("complete official draw-and-schedule bundle", bundle$message, fixed = TRUE))
  expect_true(nzchar(bundle$last_refresh_at_utc))
  expect_true(nzchar(bundle$source_bundle_id))
  expect_identical(bundle$source_confidence, "official_registry_pending")
  expect_identical(bundle$ruleset_version, phase16_test_ruleset_version)

  empty_collections <- c(
    "groups", "fixtures", "standings", "results", "qualification_ledger",
    "topology", "probabilities"
  )
  expect_true(all(vapply(bundle[empty_collections], function(value) {
    is.data.frame(value) && nrow(value) == 0L
  }, logical(1))))
  expect_true(all(vapply(bundle[empty_collections], function(value) {
    ncol(value) > 0L
  }, logical(1))))
  phase16_test_expect_schema(bundle$fixtures, c(
    "fixture_id", "edition_id", "group_id", "home_team_id", "away_team_id",
    "kickoff_confirmed", "confirmed_kickoff_at_utc", "source_bundle_id"
  ), "D-14 fixtures")
})

phase16_test_active_teams <- function() {
  data.frame(
    team_id = c("team-euro-a01", "team-euro-a02", "team-euro-b01", "team-euro-b02"),
    display_name = c("Austria", "Belgium", "Croatia", "Denmark"),
    association_id = c("assoc-aut", "assoc-bel", "assoc-cro", "assoc-den"),
    group_id = c("euro-group-a", "euro-group-a", "euro-group-b", "euro-group-b"),
    slot = c("A1", "A2", "B1", "B2"),
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-teams-v1",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_test_active_groups <- function() {
  data.frame(
    edition_id = phase16_test_edition_id,
    group_id = c("euro-group-a", "euro-group-b"),
    group_label = c("Group A", "Group B"),
    group_number = c(1L, 2L),
    team_count = c(2L, 2L),
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-groups-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_test_active_fixtures <- function() {
  data.frame(
    edition_id = phase16_test_edition_id,
    group_id = c("euro-group-a", "euro-group-a", "euro-group-b", "euro-group-b"),
    fixture_id = c(
      "euro-2028-qualifying-fixture-0001", "euro-2028-qualifying-fixture-0002",
      "euro-2028-qualifying-fixture-0003", "euro-2028-qualifying-fixture-0004"
    ),
    slot = c("A1-v-A2", "A2-v-A1", "B1-v-B2", "B2-v-B1"),
    home_team_id = c("team-euro-a01", "team-euro-a02", "team-euro-b01", "team-euro-b02"),
    away_team_id = c("team-euro-a02", "team-euro-a01", "team-euro-b02", "team-euro-b01"),
    scheduled_at_utc = c(
      "2027-03-24T19:45:00Z", "2027-03-28T19:45:00Z",
      "2027-03-25T19:45:00Z", "2027-03-29T19:45:00Z"
    ),
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = c(
      "2027-03-24T19:45:00Z", "2027-03-28T19:45:00Z",
      "2027-03-25T19:45:00Z", "2027-03-29T19:45:00Z"
    ),
    fixture_status = "scheduled",
    source = "uefa-official-draw",
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-fixtures-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_test_empty_active_results <- function() {
  phase16_test_empty_table(
    c(
      "edition_id", "fixture_id", "home_team_id", "away_team_id", "source_status",
      "match_status", "completed_at_utc", "home_goals", "away_goals",
      "source_bundle_id", "source_artifact_id"
    ),
    c("character", "character", "character", "character", "character", "character",
      "character", "integer", "integer", "character", "character")
  )
}

phase16_test_empty_active_standings <- function() {
  phase16_test_empty_table(
    c(
      "edition_id", "group_id", "team_id", "rank", "played", "points",
      "goal_difference", "standing_status", "source_bundle_id", "source_artifact_id"
    ),
    c("character", "character", "character", "integer", "integer", "integer",
      "integer", "character", "character", "character")
  )
}

phase16_test_active_after_draw_bundle <- function() {
  list(
    edition_id = phase16_test_edition_id,
    lifecycle_state = "scheduled",
    competition_status = "active",
    forecast_status = "available",
    forecast_reason = "initial_active_bundle_zero_completed_results",
    official_draw_date = phase16_test_draw_date,
    last_refresh_at_utc = "2027-03-01T12:00:00Z",
    source_bundle_id = phase16_test_source_bundle_id,
    source_confidence = "official",
    ruleset_version = phase16_test_ruleset_version,
    teams = phase16_test_active_teams(),
    groups = phase16_test_active_groups(),
    fixtures = phase16_test_active_fixtures(),
    results = phase16_test_empty_active_results(),
    standings = phase16_test_empty_active_standings(),
    host_slots = phase16_test_empty_table(c(
      "host_slot_id", "slot_number", "association_id", "team_id", "slot_status",
      "consumes_capacity", "source_bundle_id", "ruleset_version"
    )),
    qualification_ledger = phase16_test_empty_table(c(
      "edition_id", "team_id", "stage", "qualification_status", "probability",
      "source_bundle_id", "ruleset_version"
    )),
    topology = phase16_test_empty_table(c(
      "reserved_slots_used", "entrant_count", "structure", "places", "status",
      "source_bundle_id", "ruleset_version"
    )),
    probabilities = phase16_test_empty_table(c(
      "edition_id", "team_id", "probability", "status", "reason", "source_bundle_id"
    ))
  )
}

phase16_test_active_zero_results_bundle <- phase16_test_active_after_draw_bundle

phase16_test_four_host_fixture <- function() {
  covered_hosts <- data.frame(
    association_id = c("assoc-host-a", "assoc-host-b", "assoc-host-c", "assoc-host-d"),
    team_id = c("team-host-a", "team-host-b", "team-host-c", "team-host-d"),
    display_name = c("Host Association A", "Host Association B", "Host Association C", "Host Association D"),
    covered = TRUE,
    rank_evidence = c(3L, 1L, 4L, 2L),
    rank_source = "accepted-euro-group-standings-v1",
    host_slot_id = sprintf("euro-host-slot-%02d", 1:4),
    slot_number = 1:4,
    slot_status = "conditional",
    consumes_capacity = NA,
    source = "uefa-official-host-rules",
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-hosts-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  selected <- covered_hosts[order(covered_hosts$rank_evidence, method = "radix")[seq_len(2L)], , drop = FALSE]
  list(
    covered_hosts = covered_hosts,
    host_slots = covered_hosts[, c(
      "host_slot_id", "slot_number", "association_id", "team_id", "slot_status",
      "consumes_capacity", "source_bundle_id", "ruleset_version"
    ), drop = FALSE],
    expected_selected_association_ids = selected$association_id,
    expected_selected_host_ids = selected$team_id,
    selection_rule = "highest_ranked_two_covered_hosts",
    reserved_capacity = 2L
  )
}

phase16_test_four_covered_hosts <- phase16_test_four_host_fixture

phase16_test_host_usage_cases <- function() {
  four_hosts <- phase16_test_four_host_fixture()
  specs <- list(
    zero = character(),
    one = "assoc-host-b",
    two = c("assoc-host-b", "assoc-host-d"),
    more_than_two = c("assoc-host-a", "assoc-host-b", "assoc-host-c")
  )
  cases <- lapply(names(specs), function(case_id) {
    observed <- specs[[case_id]]
    observed_ranked <- four_hosts$covered_hosts[
      four_hosts$covered_hosts$association_id %in% observed,
      , drop = FALSE
    ]
    selected <- if (nrow(observed_ranked)) {
      observed_ranked[
        order(observed_ranked$rank_evidence, method = "radix")[seq_len(min(2L, nrow(observed_ranked)))],
        , drop = FALSE
      ]
    } else {
      observed_ranked
    }
    data.frame(
      case_id = case_id,
      scenario_id = paste0("euro-host-usage-", case_id),
      scenario_status = "preserved",
      observed_host_association_ids = paste(sort(observed), collapse = "|"),
      consumed_host_association_ids = paste(sort(selected$association_id), collapse = "|"),
      reserved_slots_used = as.integer(nrow(selected)),
      reserved_capacity = four_hosts$reserved_capacity,
      remaining_capacity = as.integer(four_hosts$reserved_capacity - nrow(selected)),
      expected_topology_branch = c(
        zero = "reserved_slots_used_0",
        one = "reserved_slots_used_1",
        two = "reserved_slots_used_2",
        more_than_two = "reserved_slots_used_2_after_top_two_selection"
      )[[case_id]],
      source_bundle_id = phase16_test_source_bundle_id,
      ruleset_version = phase16_test_ruleset_version,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  result <- do.call(rbind, cases)
  row.names(result) <- NULL
  result
}

phase16_test_topology_inputs <- function() {
  data.frame(
    topology_id = c("euro-playoff-host-2", "euro-playoff-host-1", "euro-playoff-host-0"),
    reserved_slots_used = c(2L, 1L, 0L),
    entrant_count = c(8L, 12L, 8L),
    structure = c(
      "2 single-leg paths of 4",
      "3 single-leg paths of 4",
      "4 seeded-versus-unseeded home-and-away ties"
    ),
    places = c(2L, 3L, 4L),
    stage_format = c("single_leg_path", "single_leg_path", "home_and_away_tie"),
    source = "uefa-official-playoff-rules",
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-topology-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_test_phase15_interim_handoff <- function() {
  data.frame(
    edition_id = "uefa_nations_league_2026_27",
    team_id = c("team-nl-a01", "team-nl-b01", "team-nl-c01", "team-nl-d01"),
    league = c("A", "B", "C", "D"),
    group_id = c("A1", "B1", "C1", "D1"),
    interim_overall_rank = c(1L, 17L, 33L, 49L),
    final_overall_rank = NA_integer_,
    rank = c(1L, 17L, 33L, 49L),
    ranking_scope = "interim_overall",
    ranking_stage = "interim_overall",
    eligibility_status = "available",
    counted_match_ids = c("nl-match-a-01", "nl-match-b-01", "nl-match-c-01", "nl-match-d-01"),
    excluded_match_ids = "",
    source_bundle_id = "nl-2026-27-official-uefa-v2",
    source_artifact_id = "artifact-nl-projected-rankings-v1",
    ruleset_version = "uefa-nations-league-2026-27-v2",
    suppression_reason = "none",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase16_test_phase15_handoff_variants <- function() {
  valid <- phase16_test_phase15_interim_handoff()
  final_only <- valid
  final_only$ranking_scope <- "final_overall"
  final_only$ranking_stage <- "final_overall"
  final_only$final_overall_rank <- final_only$rank
  wrong_stage <- valid
  wrong_stage$ranking_stage <- "final_overall"
  duplicate <- rbind(valid, valid[1L, , drop = FALSE])
  missing <- valid[FALSE, , drop = FALSE]
  unresolved <- valid
  unresolved$eligibility_status <- "unresolved_external_eligibility"
  unresolved$suppression_reason <- "missing_accepted_phase15_eligibility"
  list(
    valid = valid,
    final_only = final_only,
    wrong_stage = wrong_stage,
    duplicate = duplicate,
    missing = missing,
    unresolved = unresolved
  )
}

phase16_test_fixture_signature <- function(data) {
  if (!is.data.frame(data)) stop("Phase 16 fixture signature requires a data frame", call. = FALSE)
  if (!nrow(data)) return(paste(names(data), collapse = "|"))
  columns <- data[, sort(names(data)), drop = FALSE]
  rows <- apply(columns, 1L, function(row) paste(as.character(row), collapse = "|"))
  paste(sort(rows, method = "radix"), collapse = "\n")
}

test_that("fixture", {
  pre_draw <- phase16_test_pre_draw_bundle()
  active <- phase16_test_active_after_draw_bundle()
  expect_identical(phase16_test_pre_draw_bundle(), pre_draw)
  expect_identical(phase16_test_active_after_draw_bundle(), active)
  expect_identical(pre_draw$lifecycle_state, "pre_draw")
  expect_identical(active$lifecycle_state, "scheduled")
  expect_identical(active$competition_status, "active")
  expect_true(active$lifecycle_state %in% c("active", "scheduled"))
  expect_true(nrow(active$groups) > 0L)
  expect_true(nrow(active$fixtures) > 0L)
  expect_equal(nrow(active$results), 0L)
  expect_equal(nrow(active$standings), 0L)
  expect_false(identical(pre_draw$lifecycle_state, active$lifecycle_state))
  expect_true(all(active$groups$edition_id == phase16_test_edition_id))
  expect_true(all(nzchar(active$groups$source_artifact_id)))
  expect_true(all(active$groups$ruleset_version == phase16_test_ruleset_version))
  expect_identical(anyDuplicated(active$groups$group_id), 0L)
  expect_true(all(active$fixtures$kickoff_confirmed))
  expect_true(all(nzchar(active$fixtures$confirmed_kickoff_at_utc)))
  expect_true(all(nzchar(active$fixtures$scheduled_at_utc)))
  expect_true(all(active$fixtures$home_team_id %in% active$teams$team_id))
  expect_true(all(active$fixtures$away_team_id %in% active$teams$team_id))
  expect_false(any(active$fixtures$home_team_id %in% active$teams$display_name))
  expect_false(any(active$fixtures$away_team_id %in% active$teams$display_name))
  expect_identical(anyDuplicated(active$fixtures$fixture_id), 0L)
  expect_identical(anyDuplicated(active$fixtures$slot), 0L)
  expect_true(all(nzchar(active$fixtures$source_bundle_id)))
  expect_true(all(nzchar(active$fixtures$source_artifact_id)))
  expect_true(all(nzchar(active$fixtures$ruleset_version)))

  hosts <- phase16_test_four_host_fixture()
  expect_equal(nrow(hosts$covered_hosts), 4L)
  expect_true(all(hosts$covered_hosts$covered))
  expect_identical(hosts$expected_selected_association_ids, c("assoc-host-b", "assoc-host-d"))
  expect_identical(hosts$expected_selected_host_ids, c("team-host-b", "team-host-d"))
  expect_true(all(c(
    "host_slot_id", "slot_number", "association_id", "slot_status",
    "consumes_capacity", "source_bundle_id", "ruleset_version"
  ) %in% names(hosts$host_slots)))

  usage <- phase16_test_host_usage_cases()
  expect_setequal(usage$case_id, c("zero", "one", "two", "more_than_two"))
  expect_identical(
    usage$reserved_slots_used[match(c("zero", "one", "two", "more_than_two"), usage$case_id)],
    c(0L, 1L, 2L, 2L)
  )
  expect_identical(
    usage$expected_topology_branch[match(c("zero", "one", "two", "more_than_two"), usage$case_id)],
    c(
      "reserved_slots_used_0", "reserved_slots_used_1", "reserved_slots_used_2",
      "reserved_slots_used_2_after_top_two_selection"
    )
  )
  expect_true(all(usage$remaining_capacity >= 0L))
  expect_identical(anyDuplicated(usage$scenario_id), 0L)
  expect_true(all(usage$scenario_status == "preserved"))
  expect_true(all(nzchar(usage$source_bundle_id)))
  expect_true(all(usage$ruleset_version == phase16_test_ruleset_version))
  expect_identical(phase16_test_fixture_signature(usage), phase16_test_fixture_signature(usage[nrow(usage):1L, , drop = FALSE]))

  topology <- phase16_test_topology_inputs()
  expect_setequal(topology$reserved_slots_used, c(0L, 1L, 2L))
  expect_identical(topology$entrant_count[order(topology$reserved_slots_used)], c(8L, 12L, 8L))
  expect_identical(topology$places[order(topology$reserved_slots_used)], c(4L, 3L, 2L))
  expect_true(all(nzchar(topology$source_bundle_id)))
  expect_true(all(nzchar(topology$source_artifact_id)))
  expect_true(all(nzchar(topology$ruleset_version)))
  expect_identical(anyDuplicated(topology$topology_id), 0L)
  expect_setequal(topology$stage_format, c("single_leg_path", "home_and_away_tie"))

  handoffs <- phase16_test_phase15_handoff_variants()
  expect_true(all(handoffs$valid$ranking_scope == "interim_overall"))
  expect_true(all(handoffs$valid$ranking_stage == "interim_overall"))
  expect_true(all(nzchar(handoffs$valid$team_id)))
  expect_true(all(handoffs$final_only$ranking_scope == "final_overall"))
  expect_true(all(handoffs$final_only$ranking_stage == "final_overall"))
  expect_true(all(handoffs$wrong_stage$ranking_scope == "interim_overall"))
  expect_true(all(handoffs$wrong_stage$ranking_stage != "interim_overall"))
  expect_equal(nrow(handoffs$missing), 0L)
  expect_true(anyDuplicated(handoffs$duplicate$team_id) > 0L)
  expect_true(all(handoffs$unresolved$eligibility_status == "unresolved_external_eligibility"))
  expect_true(all(nzchar(handoffs$valid$source_bundle_id)))
  expect_true(all(nzchar(handoffs$valid$source_artifact_id)))
})
