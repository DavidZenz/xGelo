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

phase16_test_activation_candidate <- function(
    active = TRUE,
    kickoff_confirmed = TRUE,
    complete_bundle = TRUE) {
  active_bundle <- list(
    teams = data.frame(
      team_id = c("team-euro-a01", "team-euro-a02"),
      display_name = c("Austria", "Belgium"),
      association_id = c("assoc-aut", "assoc-bel"),
      group_id = "euro-group-a",
      source_bundle_id = phase16_test_source_bundle_id,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    groups = data.frame(
      edition_id = phase16_test_edition_id,
      group_id = "euro-group-a",
      team_count = 2L,
      source_bundle_id = phase16_test_source_bundle_id,
      ruleset_version = phase16_test_ruleset_version,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    fixtures = data.frame(
      edition_id = phase16_test_edition_id,
      group_id = c("euro-group-a", "euro-group-a"),
      fixture_id = c("euro-2028-qualifying-fixture-0001", "euro-2028-qualifying-fixture-0002"),
      home_team_id = c("team-euro-a01", "team-euro-a02"),
      away_team_id = c("team-euro-a02", "team-euro-a01"),
      scheduled_at_utc = c("2027-03-24T19:45:00Z", "2027-03-28T19:45:00Z"),
      kickoff_confirmed = TRUE,
      confirmed_kickoff_at_utc = c("2027-03-24T19:45:00Z", "2027-03-28T19:45:00Z"),
      source_bundle_id = phase16_test_source_bundle_id,
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    standings = phase16_test_empty_table(c("edition_id", "group_id", "team_id", "rank")),
    results = phase16_test_empty_table(c("edition_id", "fixture_id", "home_goals", "away_goals"))
  )
  status <- data.frame(
    source_edition_id = phase16_test_edition_id,
    edition_id = phase16_test_edition_id,
    competition_status = if (isTRUE(active)) "active" else "pre_draw",
    lifecycle_state = if (isTRUE(active)) "scheduled" else "pre_draw",
    source_bundle_id = phase16_test_source_bundle_id,
    ruleset_version = phase16_test_ruleset_version,
    retrieved_at_utc = "2027-03-01T12:00:00Z",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  resources <- if (isTRUE(active)) {
    list(
      teams = active_bundle$teams,
      groups = active_bundle$groups,
      fixtures = active_bundle$fixtures,
      standings = active_bundle$standings,
      results = active_bundle$results,
      status = status
    )
  } else {
    pre_draw <- phase16_test_pre_draw_bundle()
    list(
      teams = pre_draw$teams,
      groups = pre_draw$groups,
      fixtures = pre_draw$fixtures,
      standings = pre_draw$standings,
      results = pre_draw$results,
      status = status
    )
  }
  if (!isTRUE(kickoff_confirmed) && nrow(resources$fixtures)) {
    resources$fixtures$kickoff_confirmed <- FALSE
    resources$fixtures$confirmed_kickoff_at_utc <- ""
  }
  if (!isTRUE(complete_bundle)) resources$results <- NULL
  artifact_types <- c("fixtures", "groups", "standings", "results", "status")
  artifacts <- data.frame(
    artifact_type = artifact_types,
    artifact_id = paste0("artifact-euro-", artifact_types, "-v1"),
    source_artifact_id = paste0("source-artifact-euro-", artifact_types, "-v1"),
    edition_id = phase16_test_edition_id,
    bundle_id = phase16_test_source_bundle_id,
    source_url = "https://registered.phase16.test/euro-qualifying",
    retrieved_at_utc = "2027-03-01T12:00:00Z",
    parser_version = "phase16-test-parser-v1",
    raw_sha256 = paste(rep("a", 64L), collapse = ""),
    canonical_content_sha256 = paste(rep("b", 64L), collapse = ""),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  source_bundle <- list(
    bundle_id = phase16_test_source_bundle_id,
    source_bundle_id = phase16_test_source_bundle_id,
    edition_id = phase16_test_edition_id,
    ruleset_version = phase16_test_ruleset_version,
    bundle_status = "accepted",
    source_confidence = "official",
    retrieved_at_utc = "2027-03-01T12:00:00Z",
    source_url = "https://registered.phase16.test/euro-qualifying",
    artifacts = artifacts
  )
  list(
    edition_id = phase16_test_edition_id,
    source_bundle_id = phase16_test_source_bundle_id,
    ruleset_version = phase16_test_ruleset_version,
    source_confidence = if (isTRUE(active)) "official" else "official_registry_pending",
    source_bundle = source_bundle,
    resources = resources,
    manifest = list(
      bundle_id = phase16_test_source_bundle_id,
      source_bundle_id = phase16_test_source_bundle_id,
      edition_id = phase16_test_edition_id,
      ruleset_version = phase16_test_ruleset_version,
      registered = TRUE,
      bundle_status = "accepted",
      raw_sha256 = paste(rep("a", 64L), collapse = ""),
      retrieved_at_utc = "2027-03-01T12:00:00Z"
    ),
    raw_snapshot = list(
      bundle_id = phase16_test_source_bundle_id,
      edition_id = phase16_test_edition_id,
      retrieved_at_utc = "2027-03-01T12:00:00Z",
      raw_sha256 = paste(rep("a", 64L), collapse = "")
    )
  )
}

test_that("activation active_after_draw accepts a complete bundle", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  candidate <- phase16_test_activation_candidate(active = TRUE)

  validation <- validate_euro_activation(candidate)
  expect_true(validation$valid, info = validation$failure_reason)
  expect_identical(validation$activation_status, "active")
  expect_identical(validation$fixture_gate, "confirmed_kickoff")

  envelope <- phase16_euro_activation_envelope(validation)
  expect_identical(envelope$lifecycle_state, "scheduled")
  expect_identical(envelope$forecast_status, "available")
  expect_identical(envelope$source_bundle_id, phase16_test_source_bundle_id)
  expect_equal(nrow(envelope$results), 0L)
  expect_equal(nrow(envelope$standings), 0L)
  expect_true(all(envelope$fixtures$forecast_eligible))
  expect_identical(
    envelope$fixtures$fixture_id,
    candidate$resources$fixtures$fixture_id
  )
  expect_identical(
    phase16_euro_fixture_eligibility(candidate$resources$fixtures)$fixture_id,
    candidate$resources$fixtures$fixture_id
  )
})

test_that("pre_draw activation exposes the exact D-16 payload and typed empties", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  candidate <- phase16_test_activation_candidate(active = FALSE)

  validation <- validate_euro_activation(candidate)
  expect_true(validation$valid)
  expect_identical(validation$activation_status, "pre_draw")
  envelope <- phase16_euro_activation_envelope(validation)

  expect_identical(envelope$lifecycle_state, "pre_draw")
  expect_identical(envelope$forecast_status, "pre_draw")
  expect_identical(envelope$message_heading, "EURO qualifying is awaiting the official draw")
  expect_identical(
    envelope$message_body,
    paste(
      "Official groups and the schedule are not available yet.",
      "The draw is expected on 6 December 2026.",
      "Forecasts will appear after a complete official draw-and-schedule bundle is accepted."
    )
  )
  expect_identical(envelope$official_draw_date, phase16_test_draw_date)
  expect_true(nzchar(envelope$last_refresh_at_utc))
  expect_identical(envelope$source_bundle_id, phase16_test_source_bundle_id)
  expect_identical(envelope$forecast_reason, "awaiting_official_draw_and_schedule")
  expect_true(nzchar(envelope$forecast_unavailability_reason))
  empty_collections <- c(
    "teams", "groups", "fixtures", "standings", "results",
    "qualification_ledger", "host_slots", "topology", "probabilities"
  )
  expect_true(all(vapply(envelope[empty_collections], function(value) {
    is.data.frame(value) && nrow(value) == 0L && ncol(value) > 0L
  }, logical(1))))
})

test_that("activation rejects incomplete source and missing confirmed kickoff", {
  phase16_test_source("R/competition/uefa_euro_rules.R")

  incomplete <- phase16_test_activation_candidate(active = TRUE, complete_bundle = FALSE)
  incomplete_validation <- validate_euro_activation(incomplete)
  expect_false(incomplete_validation$valid)
  expect_identical(incomplete_validation$activation_status, "unavailable")
  expect_match(incomplete_validation$reason, "resource|complete", ignore.case = TRUE)

  unconfirmed <- phase16_test_activation_candidate(active = TRUE, kickoff_confirmed = FALSE)
  unconfirmed_validation <- validate_euro_activation(unconfirmed)
  expect_false(unconfirmed_validation$valid)
  expect_identical(unconfirmed_validation$activation_status, "unavailable")
  expect_match(unconfirmed_validation$reason, "kickoff", ignore.case = TRUE)
  expect_false(any(phase16_euro_fixture_eligibility(unconfirmed$resources$fixtures)$forecast_eligible))
})

test_that("activation exposes the registered contract and rejects unknown lifecycle inputs", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  candidate <- phase16_test_activation_candidate(active = TRUE)
  expect_identical(uefa_euro_edition_id(), phase16_test_edition_id)
  expect_identical(uefa_euro_ruleset_version(), phase16_test_ruleset_version)
  expect_true(all(c("fixtures", "groups", "standings", "results", "status") %in% phase16_euro_required_resource_types()))
  expect_setequal(
    uefa_euro_activation_status_values(),
    c("pre_draw", "active", "unavailable", "revision_blocked")
  )

  unknown_edition <- candidate
  unknown_edition$edition_id <- "uefa_euro_unknown"
  expect_false(validate_euro_activation(unknown_edition)$valid)

  unknown_source <- candidate
  unknown_source$source_bundle_id <- "euro-unknown-source-v1"
  unknown_source$source_bundle$source_bundle_id <- "euro-unknown-source-v1"
  unknown_source$source_bundle$bundle_id <- "euro-unknown-source-v1"
  unknown_source$manifest$source_bundle_id <- "euro-unknown-source-v1"
  unknown_source$manifest$bundle_id <- "euro-unknown-source-v1"
  unknown_source$manifest$registered <- FALSE
  expect_false(validate_euro_activation(unknown_source)$valid)

  invalid_lifecycle <- candidate
  invalid_lifecycle$resources$status$competition_status <- "complete"
  invalid_lifecycle$resources$status$lifecycle_state <- "complete"
  expect_false(validate_euro_activation(invalid_lifecycle)$valid)

  incomplete_schedule <- candidate
  incomplete_schedule$resources$groups$team_count <- 3L
  expect_false(validate_euro_activation(incomplete_schedule)$valid)
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

phase16_test_draw_conditions <- function() {
  list(
    draw_conditions_version = "uefa-euro-2028-playoff-draw-conditions-v1",
    draw_conditions_sha256 = paste(rep("e", 64L), collapse = ""),
    source_artifact_id = "artifact-euro-draw-conditions-v1",
    source_bundle_id = phase16_test_source_bundle_id,
    accepted = TRUE,
    complete = TRUE,
    conditions = c("host_association_separation", "northern_ireland_separation")
  )
}

phase16_test_completed_group <- function() {
  standings <- data.frame(
    edition_id = phase16_test_edition_id,
    group_id = "euro-group-completed",
    team_id = c("team-euro-g01", "team-euro-g02", "team-euro-g03", "team-euro-g04"),
    association_id = c("assoc-host-a", "assoc-euro-b", "assoc-euro-c", "assoc-euro-d"),
    played = c(2L, 2L, 2L, 2L),
    wins = c(2L, 1L, 1L, 0L),
    draws = c(0L, 0L, 0L, 0L),
    losses = c(0L, 1L, 1L, 2L),
    goals_for = c(5L, 3L, 2L, 1L),
    goals_against = c(1L, 3L, 4L, 3L),
    goal_difference = c(4L, 0L, -2L, -2L),
    points = c(6L, 3L, 3L, 0L),
    away_goals = c(2L, 1L, 0L, 1L),
    away_wins = c(1L, 0L, 0L, 0L),
    discipline_points = c(1L, 2L, 3L, 4L),
    interim_overall_rank = c(12L, 24L, 36L, 48L),
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-standings-completed-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  fixtures <- data.frame(
    edition_id = phase16_test_edition_id,
    group_id = "euro-group-completed",
    fixture_id = c("euro-completed-001", "euro-completed-002", "euro-completed-003", "euro-completed-004"),
    home_team_id = c("team-euro-g01", "team-euro-g02", "team-euro-g03", "team-euro-g04"),
    away_team_id = c("team-euro-g02", "team-euro-g03", "team-euro-g04", "team-euro-g01"),
    home_goals = c(2L, 1L, 1L, 0L),
    away_goals = c(0L, 0L, 0L, 2L),
    match_status = "completed",
    counts_for_standings = TRUE,
    evidence_completed_at_utc = c(
      "2027-03-01T18:00:00Z", "2027-03-02T18:00:00Z",
      "2027-03-03T18:00:00Z", "2027-03-04T18:00:00Z"
    ),
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-fixtures-completed-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  hosts <- data.frame(
    host_slot_id = "euro-host-slot-01",
    slot_number = 1L,
    association_id = "assoc-host-a",
    team_id = "team-euro-g01",
    display_name = "Host Association A",
    covered = TRUE,
    rank_evidence = 1L,
    host_guarantee_status = "resolved",
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "artifact-euro-hosts-v1",
    ruleset_version = phase16_test_ruleset_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(standings = standings, fixtures = fixtures, hosts = hosts)
}

test_that("ranking|host|allocation|phase16_smoke", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  inputs <- phase16_test_completed_group()
  ranked <- rank_euro_group(inputs$standings, inputs$fixtures)

  expect_identical(ranked$team_id[[1L]], "team-euro-g01")
  expect_identical(as.integer(ranked$rank), 1:4)
  expect_identical(as.integer(ranked$points), inputs$standings$points)
  expect_identical(as.integer(ranked$goal_difference), inputs$standings$goal_difference)
  expect_true(all(nzchar(ranked$counted_match_ids)))
  expect_true(all(ranked$excluded_match_ids == ""))
  expect_true(all(ranked$ordering_status == "ready"))
  expect_true(all(c("source_artifact_id", "source_bundle_id", "ruleset_version", "ruleset_sha256") %in% names(ranked)))
  expect_true("evidence_id" %in% names(attr(ranked, "tiebreak_trace")))

  topologies <- uefa_euro_playoff_topologies()
  expect_setequal(topologies$reserved_slots_used, c(0L, 1L, 2L))
  expect_identical(topologies$entrant_count[order(topologies$reserved_slots_used)], c(8L, 12L, 8L))
  expect_identical(topologies$places[order(topologies$reserved_slots_used)], c(4L, 3L, 2L))
  expect_true(all(nzchar(topologies$source_artifact_id)))

  allocation <- allocate_euro_places(
    ranked,
    host_ids = inputs$hosts,
    draw_conditions = phase16_test_draw_conditions()
  )
  occupied <- allocation$host_slots[allocation$host_slots$slot_status == "occupied", , drop = FALSE]
  expect_equal(nrow(occupied), 1L)
  expect_identical(occupied$association_id[[1L]], "assoc-host-a")
  expect_true(isTRUE(occupied$consumes_capacity[[1L]]))
  expect_equal(sum(allocation$host_slots$consumes_capacity %in% TRUE), 1L)
  expect_identical(allocation$capacity$reserved_slots_used, 1L)
  expect_identical(allocation$capacity$remaining_playoff_places, 3L)
  expect_true(any(allocation$qualification_ledger$qualification_status == "direct"))
  expect_true(any(allocation$qualification_ledger$qualification_status == "host_reserved_occupied"))
  expect_true(all(c("source_bundle_id", "source_artifact_id", "ruleset_version", "ruleset_sha256") %in% names(allocation$qualification_ledger)))
  expect_true(any(allocation$topology$current_topology))
  expect_identical(allocation$topology$reserved_slots_used[allocation$topology$current_topology], 1L)
})

test_that("scenario|host|allocation", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  active <- phase16_test_active_zero_results_bundle()
  hosts <- phase16_test_four_host_fixture()$covered_hosts[1:2, , drop = FALSE]
  hosts$host_guarantee_status <- "unresolved"
  scenario <- allocate_euro_places(
    active$standings,
    host_ids = hosts,
    draw_conditions = phase16_test_draw_conditions()
  )

  expect_true(isTRUE(scenario$scenario_status == "preserved"))
  expect_true(all(scenario$topology$scenario_status == "preserved"))
  expect_false(any(scenario$topology$current_topology))
  expect_true(any(scenario$qualification_ledger$qualification_status == "host_place_unresolved"))
  expect_true(all(is.na(scenario$qualification_ledger$probability)))
  expect_true(all(nzchar(scenario$scenario_id)))
})

test_that("host_place_unresolved suppresses affected qualification eligibility", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  inputs <- phase16_test_completed_group()
  inputs$hosts$host_guarantee_status <- "unresolved"
  allocation <- allocate_euro_places(
    rank_euro_group(inputs$standings, inputs$fixtures),
    host_ids = inputs$hosts,
    draw_conditions = phase16_test_draw_conditions()
  )
  unresolved <- allocation$qualification_ledger[
    allocation$qualification_ledger$qualification_status == "host_place_unresolved",
    , drop = FALSE
  ]
  expect_equal(nrow(unresolved), 1L)
  expect_true(all(is.na(unresolved$probability)))
  expect_true(all(unresolved$qualification_eligibility_status == "suppressed"))
  expect_true(all(grepl("host", unresolved$reason, ignore.case = TRUE)))
})

phase16_test_article23_fixture <- function() {
  make_group <- function(group_id, prefix, size, source_artifact) {
    team_ids <- sprintf("team-euro-%s%02d", prefix, seq_len(size))
    data.frame(
      edition_id = phase16_test_edition_id,
      group_id = group_id,
      team_id = team_ids,
      group_position = seq_len(size),
      rank = seq_len(size),
      group_size = size,
      points = c(9L, 6L, 3L, 0L, if (size == 5L) -3L else integer())[seq_len(size)],
      goal_difference = c(7L, 3L, 0L, -4L, -6L)[seq_len(size)],
      goals_for = c(9L, 6L, 4L, 2L, 1L)[seq_len(size)],
      away_goals = c(4L, 3L, 2L, 1L, 0L)[seq_len(size)],
      wins = c(3L, 2L, 1L, 0L, 0L)[seq_len(size)],
      away_wins = c(2L, 1L, 1L, 0L, 0L)[seq_len(size)],
      discipline_points = seq_len(size),
      interim_overall_rank = seq_len(size) * 10L,
      ordering_status = "ready",
      source_bundle_id = phase16_test_source_bundle_id,
      source_artifact_id = source_artifact,
      ruleset_version = phase16_test_ruleset_version,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  group_four <- make_group("euro-group-four", "h", 4L, "artifact-euro-group-four-v1")
  group_five <- make_group("euro-group-five", "f", 5L, "artifact-euro-group-five-v1")
  fixtures <- rbind(
    data.frame(
      group_id = "euro-group-four",
      fixture_id = paste0("euro-four-00", 1:3),
      home_team_id = c("team-euro-h01", "team-euro-h02", "team-euro-h02"),
      away_team_id = c("team-euro-h02", "team-euro-h03", "team-euro-h04"),
      home_goals = c(1L, 1L, 0L), away_goals = c(0L, 0L, 0L),
      match_status = "completed", counts_for_standings = TRUE,
      evidence_completed_at_utc = paste0("2027-04-0", 1:3, "T18:00:00Z"),
      source_bundle_id = phase16_test_source_bundle_id,
      source_artifact_id = "artifact-euro-fixtures-four-v1",
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    data.frame(
      group_id = "euro-group-five",
      fixture_id = paste0("euro-five-00", 1:4),
      home_team_id = c("team-euro-f01", "team-euro-f02", "team-euro-f02", "team-euro-f02"),
      away_team_id = c("team-euro-f02", "team-euro-f03", "team-euro-f04", "team-euro-f05"),
      home_goals = c(0L, 1L, 0L, 5L), away_goals = c(0L, 0L, 0L, 0L),
      match_status = "completed", counts_for_standings = TRUE,
      evidence_completed_at_utc = paste0("2027-05-0", 1:4, "T18:00:00Z"),
      source_bundle_id = phase16_test_source_bundle_id,
      source_artifact_id = "artifact-euro-fixtures-five-v1",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  )
  list(standings = rbind(group_four, group_five), fixtures = fixtures)
}

phase16_test_complete_groups <- function(group_count = 12L) {
  rows <- lapply(seq_len(group_count), function(group_number) {
    group_id <- sprintf("euro-group-%02d", group_number)
    data.frame(
      edition_id = phase16_test_edition_id,
      group_id = group_id,
      team_id = sprintf("team-euro-%02d-%02d", group_number, 1:4),
      association_id = sprintf("assoc-euro-%02d-%02d", group_number, 1:4),
      rank = 1:4,
      group_position = 1:4,
      group_size = 4L,
      points = c(9L, 6L, 3L, 0L),
      goal_difference = c(6L, 2L, -1L, -7L),
      goals_for = c(8L, 5L, 3L, 1L),
      away_goals = c(3L, 2L, 1L, 0L),
      wins = c(3L, 2L, 1L, 0L),
      away_wins = c(2L, 1L, 0L, 0L),
      discipline_points = 1:4,
      interim_overall_rank = group_number * 4L + 1:4,
      ordering_status = "ready",
      counted_match_ids = sprintf("euro-group-%02d-counted", group_number),
      excluded_match_ids = "",
      source_bundle_id = phase16_test_source_bundle_id,
      source_artifact_id = sprintf("artifact-euro-standings-%02d-v1", group_number),
      ruleset_version = phase16_test_ruleset_version,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  groups <- do.call(rbind, rows)
  runners <- groups[groups$group_position == 2L, , drop = FALSE]
  runners$ranking_scope <- "overall"
  runners$ranking_stage <- "article23_best_runners_up"
  runners$article23_rank <- seq_len(nrow(runners))
  runners$overall_rank <- runners$article23_rank
  runners$rank <- runners$article23_rank
  runners$qualification_eligibility_status <- "available"
  list(groups = groups, runners = runners)
}

phase16_test_resolved_hosts <- function(count = 0L) {
  hosts <- phase16_test_four_host_fixture()$covered_hosts
  hosts <- hosts[seq_len(count), , drop = FALSE]
  if (nrow(hosts)) hosts$host_guarantee_status <- "resolved"
  hosts
}

test_that("article15|article23|four_host|topology|draw_conditions|conservation", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  inputs <- phase16_test_completed_group()
  ranked <- rank_euro_group(inputs$standings, inputs$fixtures)
  trace <- attr(ranked, "tiebreak_trace")
  expect_true(any(trace$criterion == "head_to_head_points"))
  expect_identical(ranked$team_id[2:3], c("team-euro-g02", "team-euro-g03"))
  expect_true(all(grepl("article15", trace$evidence_id, fixed = TRUE)))

  mixed <- phase16_test_article23_fixture()
  overall <- rank_euro_overall(mixed$standings, mixed$fixtures)
  expect_true(all(overall$ordering_status == "ready"))
  five_runner <- overall[overall$group_id == "euro-group-five", , drop = FALSE]
  expect_equal(nrow(five_runner), 1L)
  expect_true(grepl("euro-five-004", five_runner$excluded_match_ids, fixed = TRUE))
  expect_false(grepl("euro-five-004", five_runner$counted_match_ids, fixed = TRUE))
  expect_identical(attr(overall, "tiebreak_trace")$ranking_scope[[1L]], "overall")
  expect_true(all(grepl("article23", attr(overall, "tiebreak_trace")$evidence_id, fixed = TRUE)))

  complete <- phase16_test_complete_groups()
  allocation <- allocate_euro_places(
    complete$groups,
    host_ids = phase16_test_resolved_hosts(0L),
    runner_ups = complete$runners,
    draw_conditions = phase16_test_draw_conditions()
  )
  expect_equal(sum(allocation$qualification_ledger$qualification_status == "direct"), 20L)
  expect_equal(sum(allocation$qualification_ledger$qualification_status == "playoff_eligible"), 4L)
  expect_equal(allocation$capacity$best_runner_ups, 8L)
  expect_equal(allocation$capacity$remaining_runner_ups, 4L)
  expect_identical(allocation$capacity$conservation_status, "conserved")
  expect_true(exists("select_euro_best_runners_up", mode = "function"))
  selected <- select_euro_best_runners_up(
    complete$runners,
    direct_team_ids = allocation$direct_qualifiers$team_id,
    host_slots = allocation$host_slots,
    rules = uefa_euro_2026_28_rules()
  )
  expect_identical(selected$status, "ready")
  expect_equal(nrow(selected$selected), 8L)
  expect_equal(nrow(selected$remaining), 4L)
  expect_identical(allocation$capacity$double_counting_status, "none")

  branch_expectations <- data.frame(
    host_count = c(0L, 1L, 2L), reserved = c(0L, 1L, 2L), entrants = c(8L, 12L, 8L),
    places = c(4L, 3L, 2L), stringsAsFactors = FALSE
  )
  for (index in seq_len(nrow(branch_expectations))) {
    branch <- allocate_euro_places(
      complete$groups,
      host_ids = phase16_test_resolved_hosts(branch_expectations$host_count[[index]]),
      runner_ups = complete$runners,
      draw_conditions = phase16_test_draw_conditions()
    )
    current <- branch$topology[branch$topology$current_topology, , drop = FALSE]
    expect_equal(nrow(current), 1L)
    expect_identical(current$reserved_slots_used[[1L]], branch_expectations$reserved[[index]])
    expect_identical(current$entrant_count[[1L]], branch_expectations$entrants[[index]])
    expect_identical(current$places[[1L]], branch_expectations$places[[index]])
    expect_identical(branch$capacity$remaining_playoff_places, 4L - branch_expectations$reserved[[index]])
    expect_identical(branch$capacity$double_counting_status, "none")
    expect_equal(nrow(branch$host_slots), max(2L, branch_expectations$host_count[[index]]))
  }

  four_hosts <- phase16_test_resolved_hosts(4L)
  four_host_allocation <- allocate_euro_places(
    complete$groups,
    host_ids = four_hosts,
    runner_ups = complete$runners,
    draw_conditions = phase16_test_draw_conditions()
  )
  expect_setequal(
    four_host_allocation$host_slots$association_id[four_host_allocation$host_slots$consumes_capacity %in% TRUE],
    phase16_test_four_host_fixture()$expected_selected_association_ids
  )
  expect_equal(sum(four_host_allocation$host_slots$consumes_capacity %in% TRUE), 2L)
  expect_equal(sum(four_host_allocation$host_slots$slot_status == "host_reserved_unused"), 2L)
  expect_identical(four_host_allocation$capacity$remaining_playoff_places, 2L)

  invalid_conditions <- list(
    NULL,
    list(draw_conditions_version = "uefa-euro-2028-playoff-draw-conditions-v1", complete = FALSE),
    list(draw_conditions_version = "uefa-euro-2027-playoff-draw-conditions-v1", draw_conditions_sha256 = paste(rep("e", 64L), collapse = ""), source_artifact_id = "artifact-stale", accepted = TRUE, complete = TRUE, conditions = "old-rule"),
    list(draw_conditions_version = "uefa-euro-2028-playoff-draw-conditions-v1", draw_conditions_sha256 = "", source_artifact_id = "artifact-partial", accepted = TRUE, complete = TRUE, conditions = "missing-hash")
  )
  for (conditions in invalid_conditions) {
    rejected <- allocate_euro_places(
      complete$groups,
      host_ids = phase16_test_resolved_hosts(1L),
      runner_ups = complete$runners,
      draw_conditions = conditions
    )
    expect_false(any(rejected$topology$current_topology))
    expect_true(all(rejected$topology$status == "unsupported_topology"))
    expect_true(all(grepl("unresolved_draw_conditions", rejected$topology$reason, fixed = TRUE)))
    expect_true(all(grepl("unsupported_topology", rejected$topology$reason, fixed = TRUE)))
    expect_true(all(rejected$qualification_ledger$qualification_eligibility_status == "suppressed"))
  }
})

phase16_test_registered_revision_candidate <- function() {
  candidate <- phase16_test_activation_candidate(active = TRUE)
  candidate$source_bundle_id <- "euro-2028-qualifying-official-draw-v2"
  candidate$ruleset_version <- "uefa-euro-2028-qualifying-v2"
  candidate$source_bundle$bundle_id <- candidate$source_bundle_id
  candidate$source_bundle$source_bundle_id <- candidate$source_bundle_id
  candidate$source_bundle$ruleset_version <- candidate$ruleset_version
  candidate$source_bundle$artifacts$bundle_id <- candidate$source_bundle_id
  candidate$source_bundle$artifacts$raw_sha256 <- paste(rep("c", 64L), collapse = "")
  candidate$source_bundle$artifacts$canonical_content_sha256 <- paste(rep("d", 64L), collapse = "")
  candidate$manifest$bundle_id <- candidate$source_bundle_id
  candidate$manifest$source_bundle_id <- candidate$source_bundle_id
  candidate$manifest$ruleset_version <- candidate$ruleset_version
  candidate$manifest$raw_sha256 <- paste(rep("c", 64L), collapse = "")
  candidate$raw_snapshot$raw_sha256 <- paste(rep("c", 64L), collapse = "")
  candidate$raw_snapshot$bundle_id <- candidate$source_bundle_id
  candidate$activation_config <- list(
    registered_source_bundle_ids = candidate$source_bundle_id,
    registered_ruleset_versions = candidate$ruleset_version
  )
  candidate$canonical_hashes <- setNames(
    rep(paste(rep("d", 64L), collapse = ""), 5L),
    c("fixtures", "groups", "standings", "results", "status")
  )
  candidate
}

test_that("source_bundle revision validates independently with new identity hashes", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  incumbent_candidate <- phase16_test_activation_candidate(active = TRUE)
  incumbent_validation <- phase16_validate_euro_source_bundle(incumbent_candidate)
  candidate <- phase16_test_registered_revision_candidate()

  validation <- phase16_validate_euro_source_bundle(
    candidate,
    incumbent = incumbent_validation
  )
  expect_true(validation$valid, info = validation$failure_reason)
  expect_identical(validation$activation_status, "active")
  expect_identical(validation$source_bundle_id, candidate$source_bundle_id)
  expect_identical(validation$ruleset_version, candidate$ruleset_version)
  expect_identical(validation$revision_status, "candidate")

  reused_hashes <- candidate
  reused_hashes$raw_snapshot$raw_sha256 <- paste(rep("a", 64L), collapse = "")
  reused_hashes$source_bundle$artifacts$raw_sha256 <- paste(rep("a", 64L), collapse = "")
  reused_hashes$source_bundle$artifacts$canonical_content_sha256 <- paste(rep("b", 64L), collapse = "")
  reused_hashes$canonical_hashes <- setNames(
    rep(paste(rep("b", 64L), collapse = ""), 5L),
    c("fixtures", "groups", "standings", "results", "status")
  )
  reused <- phase16_validate_euro_source_bundle(
    reused_hashes,
    incumbent = incumbent_validation
  )
  expect_false(reused$valid)
  expect_match(reused$failure_reason, "hash|revision", ignore.case = TRUE)
})

test_that("revision continuity retains the incumbent and isolates an invalid candidate", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  incumbent_validation <- phase16_validate_euro_source_bundle(
    phase16_test_activation_candidate(active = TRUE)
  )
  incumbent <- phase16_euro_activation_envelope(incumbent_validation)
  candidate <- phase16_test_activation_candidate(active = TRUE, kickoff_confirmed = FALSE)
  candidate_validation <- phase16_validate_euro_source_bundle(candidate, incumbent = incumbent_validation)

  expect_false(candidate_validation$valid)
  unavailable <- phase16_euro_activation_envelope(candidate_validation)
  expect_identical(unavailable$activation_status, "unavailable")
  expect_equal(nrow(unavailable$fixtures), 0L)
  expect_true(isTRUE(unavailable$candidate_isolated))
  expect_null(unavailable$candidate_rows)

  overlay <- phase16_euro_revision_overlay(candidate_validation, incumbent)
  expect_identical(overlay$lifecycle_state, "scheduled")
  expect_identical(overlay$forecast_status, "available")
  expect_identical(overlay$fixtures$fixture_id, incumbent$fixtures$fixture_id)
  expect_identical(overlay$source_bundle_id, incumbent$source_bundle_id)
  expect_identical(overlay$revision_status, "revision_blocked")
  expect_true(isTRUE(overlay$candidate_isolated))
  expect_true(nzchar(overlay$revision_warning))
  expect_null(overlay$candidate_rows)
})

test_that("source_bundle validation rejects missing raw metadata and canonical hash mismatch", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  candidate <- phase16_test_activation_candidate(active = TRUE)
  missing_raw <- candidate
  missing_raw$raw_snapshot$raw_sha256 <- ""
  missing_validation <- phase16_validate_euro_source_bundle(missing_raw)
  expect_false(missing_validation$valid)
  expect_match(missing_validation$failure_reason, "raw|provenance", ignore.case = TRUE)

  mismatch <- candidate
  mismatch$canonical_hashes <- setNames(
    rep(paste(rep("c", 64L), collapse = ""), 5L),
    c("fixtures", "groups", "standings", "results", "status")
  )
  mismatch_validation <- phase16_validate_euro_source_bundle(mismatch)
  expect_false(mismatch_validation$valid)
  expect_match(mismatch_validation$failure_reason, "canonical|hash", ignore.case = TRUE)
})

phase16_test_copy_tree <- function(source, target) {
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  for (path in list.files(source, full.names = TRUE, all.files = FALSE)) {
    destination <- file.path(target, basename(path))
    if (dir.exists(path)) {
      phase16_test_copy_tree(path, destination)
    } else {
      stopifnot(file.copy(path, destination, overwrite = TRUE))
    }
  }
  invisible(target)
}

phase16_test_registry_sandbox <- function() {
  root <- tempfile("phase16-registry-lifecycle-", tmpdir = phase16_test_project_root)
  registry_root <- file.path(root, "registries")
  accepted_root <- file.path(root, "accepted")
  phase16_test_copy_tree(
    file.path(phase16_test_project_root, "data/competition/registries"),
    registry_root
  )
  phase16_test_copy_tree(
    file.path(phase16_test_project_root, "data/competition/accepted"),
    accepted_root
  )
  list(root = root, registry_root = registry_root, accepted_root = accepted_root)
}

test_that("registry_path accepts the real Phase 14 pre_draw snapshot and rejects forged scheduled state", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/edition_registry.R")
  registries <- load_competition_edition_registries(
    file.path(phase16_test_project_root, "data/competition/registries"),
    project_root = phase16_test_project_root
  )
  euro <- registries[registries$edition_id == phase16_test_edition_id, , drop = FALSE]
  snapshot <- registries$accepted_snapshots[[phase16_test_edition_id]]
  expect_identical(as.character(euro$lifecycle_state), "pre_draw")
  expect_identical(as.character(snapshot$status$competition_status), "pre_draw")
  expect_equal(nrow(snapshot$groups), 0L)
  expect_equal(nrow(snapshot$fixtures), 0L)
  expect_equal(nrow(snapshot$standings), 0L)
  expect_equal(nrow(snapshot$results), 0L)

  sandbox <- phase16_test_registry_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  edition_path <- file.path(sandbox$registry_root, "competition_editions.csv")
  editions <- utils::read.csv(edition_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  euro_index <- match(phase16_test_edition_id, as.character(editions$edition_id))
  editions$lifecycle_state[[euro_index]] <- "scheduled"
  editions$row_sha256 <- phase13_row_sha256(editions)
  utils::write.csv(editions, edition_path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(
    load_competition_edition_registries(
      sandbox$registry_root,
      project_root = phase16_test_project_root,
      accepted_root = sandbox$accepted_root
    ),
    "accepted status|activation|lifecycle state does not match|complete",
    ignore.case = TRUE
  )
})

test_that("date_only does not activate EURO and pre_draw_guard remains fail closed", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/edition_registry.R")
  registries <- load_competition_edition_registries(
    file.path(phase16_test_project_root, "data/competition/registries"),
    project_root = phase16_test_project_root
  )
  euro <- registries[registries$edition_id == phase16_test_edition_id, , drop = FALSE]
  expect_identical(as.character(euro$official_draw_date), phase16_test_draw_date)
  expect_identical(as.character(euro$lifecycle_state), "pre_draw")
  script <- paste(readLines(file.path(phase16_test_project_root, "scripts/acquire_uefa_snapshot.R")), collapse = "\n")
  expect_match(script, "lifecycle_state.*pre_draw")
  expect_match(script, "phase13_acquire_empty_resource")
})

test_that("normal_fallback and normal_normalized branches require accepted lifecycle handoff", {
  script <- paste(readLines(file.path(phase16_test_project_root, "scripts/acquire_uefa_snapshot.R")), collapse = "\n")
  expect_match(script, "publish_accepted_fn")
  expect_match(script, "phase13_acquire_update_edition_after_acceptance")
  expect_true(length(gregexpr("phase13_acquire_update_edition_after_acceptance", script, fixed = TRUE)[[1L]]) >= 3L)
  expect_match(script, "failure_injector")
})

test_that("failure_injection and no_scheduled_without_accepted are explicit API gates", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/edition_registry.R")
  acquire_environment <- new.env(parent = globalenv())
  previous_directory <- getwd()
  setwd(phase16_test_project_root)
  on.exit(setwd(previous_directory), add = TRUE)
  sys.source(file.path(phase16_test_project_root, "scripts/acquire_uefa_snapshot.R"), envir = acquire_environment)
  refresh_formals <- names(formals(acquire_environment$phase13_acquire_publish_refresh))
  expect_true("publish_accepted_fn" %in% refresh_formals)
  update_body <- paste(deparse(acquire_environment$phase13_acquire_update_edition_after_acceptance), collapse = "\n")
  expect_match(update_body, "phase13_acquire_validate_euro_candidate")
  activation_body <- paste(deparse(acquire_environment$phase13_acquire_validate_euro_candidate), collapse = "\n")
  expect_match(activation_body, "phase16_validate_euro_source_bundle")
  expect_match(update_body, "phase13_transition_competition_edition")
})

phase16_test_simulation_hash <- function(value) {
  if (exists("uefa_euro_sim_hash_data", mode = "function", inherits = TRUE)) {
    return(uefa_euro_sim_hash_data(value))
  }
  digest::digest(value, algo = "sha256", serialize = TRUE)
}

phase16_test_simulation_manifest <- function(rows, registered = TRUE) {
  content_hash <- if (exists("uefa_euro_nl_table_content_hash", mode = "function", inherits = TRUE)) {
    uefa_euro_nl_table_content_hash(rows)
  } else {
    paste(rep("a", 64L), collapse = "")
  }
  list(
    edition_id = "uefa_nations_league_2026_27",
    artifact_path = "outcomes/projected_rankings.csv",
    artifact_type = "projected_rankings",
    row_count = nrow(rows),
    content_sha256 = content_hash,
    source_bundle_id = "nl-2026-27-official-uefa-v2",
    source_bundle_sha256 = paste(rep("b", 64L), collapse = ""),
    source_artifact_ids = "nl-projected-rankings-v1",
    ruleset_version = "uefa-nations-league-2026-27-v2",
    ruleset_sha256 = paste(rep("c", 64L), collapse = ""),
    manifest_sha256 = paste(rep("d", 64L), collapse = ""),
    validation_status = if (isTRUE(registered)) "valid" else "blocked",
    registered = isTRUE(registered)
  )
}

phase16_test_simulation_forecast <- function(home = "team-nl-a01", away = "team-nl-b01", fixture_id = "euro-playoff-fixture-001") {
  score_id <- paste0(fixture_id, "-score")
  grid <- expand.grid(home_goals = 0:2, away_goals = 0:2)
  grid$probability <- c(0.20, 0.10, 0.05, 0.12, 0.16, 0.07, 0.08, 0.10, 0.12)
  grid$score_distribution_id <- score_id
  grid$fixture_id <- fixture_id
  grid$normalized <- TRUE
  forecast <- data.frame(
    edition_id = phase16_test_edition_id,
    fixture_id = fixture_id,
    match_id = fixture_id,
    home_team_id = home,
    away_team_id = away,
    forecast_status = "available",
    suppression_reason = "none",
    primary_probability_view = "calibrated_1x2",
    raw_probability_view = "raw_1x2",
    p_home = 0.52,
    p_draw = 0.28,
    p_away = 0.20,
    score_distribution_id = score_id,
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    model_id = "open_nb_incumbent",
    model_sha256 = paste(rep("e", 64L), collapse = ""),
    release_manifest_sha256 = paste(rep("f", 64L), collapse = ""),
    release_selector_sha256 = paste(rep("1", 64L), collapse = ""),
    calibrator_id = "vector_w400_p0p010",
    calibrator_sha256 = paste(rep("2", 64L), collapse = ""),
    model_data_cutoff = "2026-06-10",
    feature_cutoff_utc = "2027-03-01T00:00:00Z",
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = paste(rep("3", 64L), collapse = ""),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(forecast = forecast, score_distribution = grid)
}

test_that("simulation|handoff|interim_adapter|registered_phase15|ranking_stage|rng|suppression", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/uefa_euro_simulation.R")

  registered <- uefa_euro_read_registered_nl_handoff(project_root = phase16_test_project_root)
  expect_true(isTRUE(registered$registered))
  expect_true(file.exists(registered$projected_rankings_path))
  expect_true(file.exists(registered$manifest_path))
  rejected <- uefa_euro_normalize_nl_interim_projection(registered)
  expect_identical(rejected$status, "unresolved_external_eligibility")
  expect_equal(nrow(rejected$projection), 0L)

  variants <- phase16_test_phase15_handoff_variants()
  valid_manifest <- phase16_test_simulation_manifest(variants$valid)
  normalized <- uefa_euro_normalize_nl_interim_projection(
    projected_rankings = variants$valid,
    manifest = valid_manifest
  )
  expect_true(is.data.frame(normalized))
  expect_true(all(normalized$ranking_scope == "interim_overall"))
  expect_true(all(normalized$ranking_stage == "interim_overall"))
  expect_true(all(nzchar(normalized$team_id)))
  expect_true(all(nzchar(normalized$source_bundle_id)))
  expect_true(all(nzchar(normalized$source_manifest_sha256)))
  expect_silent(uefa_euro_validate_nl_eligibility_handoff(normalized))

  for (variant_name in c("final_only", "wrong_stage", "duplicate", "missing", "unresolved")) {
    invalid <- uefa_euro_normalize_nl_interim_projection(
      projected_rankings = variants[[variant_name]],
      manifest = valid_manifest
    )
    expect_identical(invalid$status, "unresolved_external_eligibility", info = variant_name)
    expect_equal(nrow(invalid$projection), 0L, info = variant_name)
  }

  fixture <- phase16_test_simulation_forecast()
  single <- uefa_euro_resolve_single_leg(
    match = data.frame(
      fixture_id = "euro-playoff-fixture-001",
      home_team_id = "team-nl-a01",
      away_team_id = "team-nl-b01",
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    forecast = fixture$forecast,
    score_distribution = fixture$score_distribution,
    seed = 16017L
  )
  expect_identical(single$status, "completed")
  expect_true(single$winner_team_id %in% c("team-nl-a01", "team-nl-b01"))
  expect_identical(single$primary_probability_view, "calibrated_1x2")
  expect_identical(single$model_release_id, "phase14-open-nb-incumbent-calibrated-v1")

  active <- phase16_test_active_after_draw_bundle()
  completed <- phase16_test_complete_groups()
  simulation_args <- list(
    activation = active,
    fixtures = active$fixtures,
    standings = completed$groups,
    hosts = phase16_test_resolved_hosts(0L),
    nl_eligibility = normalized,
    forecast_status = fixture$forecast,
    forecasts = fixture$forecast,
    score_distributions = fixture$score_distribution,
    draw_conditions = phase16_test_draw_conditions(),
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = paste(rep("4", 64L), collapse = ""),
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    model_lineage = list(model_id = "open_nb_incumbent"),
    state_manifest_sha256 = paste(rep("5", 64L), collapse = ""),
    simulation_count = 2L,
    seed = 16017L
  )
  set.seed(16099L)
  rng_before <- .Random.seed
  first <- do.call(uefa_euro_simulate_qualification, simulation_args)
  rng_after <- .Random.seed
  expect_identical(rng_before, rng_after)
  second <- do.call(uefa_euro_simulate_qualification, simulation_args)
  expect_identical(first$output_hashes, second$output_hashes)
  expect_true(is.data.frame(first$probabilities))
  expect_true(nrow(first$probabilities) > 0L)
  expect_true(all(first$probabilities$probability >= 0))

  zero_results <- phase16_test_active_zero_results_bundle()
  scenario <- do.call(uefa_euro_simulate_qualification, modifyList(simulation_args, list(
    activation = zero_results,
    fixtures = zero_results$fixtures,
    standings = NULL
  )))
  expect_true(scenario$status %in% c("scenario_preserved", "suppressed", "unavailable"))
  expect_true(nrow(scenario$probabilities) == 0L)

  unconfirmed <- active$fixtures
  unconfirmed$kickoff_confirmed <- FALSE
  unconfirmed$confirmed_kickoff_at_utc <- ""
  blocked <- do.call(uefa_euro_simulate_qualification, modifyList(simulation_args, list(fixtures = unconfirmed)))
  expect_true(blocked$status %in% c("suppressed", "unavailable"))
  expect_equal(nrow(blocked$probabilities), 0L)
})

test_that("topology|four_host|fallback|draw_conditions|fresh_process|replay", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/uefa_euro_simulation.R")

  complete <- phase16_test_complete_groups()
  branch_expectations <- data.frame(
    host_count = c(0L, 1L, 2L), reserved_slots_used = c(0L, 1L, 2L),
    entrant_count = c(8L, 12L, 8L), places = c(4L, 3L, 2L),
    stringsAsFactors = FALSE
  )
  branch_results <- lapply(seq_len(nrow(branch_expectations)), function(index) {
    uefa_euro_allocate_playoff_pool(
      group_rankings = complete$groups,
      hosts = phase16_test_resolved_hosts(branch_expectations$host_count[[index]]),
      draw_conditions = phase16_test_draw_conditions()
    )
  })
  for (index in seq_along(branch_results)) {
    branch <- branch_results[[index]]
    current <- branch$topology
    expect_true(isTRUE(branch$valid))
    expect_identical(as.integer(current$reserved_slots_used[[1L]]), branch_expectations$reserved_slots_used[[index]])
    expect_identical(as.integer(current$entrant_count[[1L]]), branch_expectations$entrant_count[[index]])
    expect_identical(as.integer(current$places[[1L]]), branch_expectations$places[[index]])
  }

  four_hosts <- uefa_euro_allocate_playoff_pool(
    group_rankings = complete$groups,
    hosts = phase16_test_resolved_hosts(4L),
    draw_conditions = phase16_test_draw_conditions()
  )
  expect_setequal(
    four_hosts$allocation$host_slots$association_id[four_hosts$allocation$host_slots$consumes_capacity %in% TRUE],
    phase16_test_four_host_fixture()$expected_selected_association_ids
  )
  expect_equal(sum(four_hosts$allocation$host_slots$consumes_capacity %in% TRUE), 2L)
  expect_equal(four_hosts$allocation$capacity$remaining_playoff_places, 2L)

  variants <- phase16_test_phase15_handoff_variants()
  valid_with_position <- variants$valid
  valid_with_position$group_position <- 1L
  extra <- valid_with_position[rep(seq_len(nrow(valid_with_position)), 1L), , drop = FALSE]
  extra$team_id <- paste0("team-nl-extra-", seq_len(nrow(extra)))
  extra$group_id <- paste0("extra-", seq_len(nrow(extra)))
  extra$interim_overall_rank <- 100L + seq_len(nrow(extra))
  extra$rank <- extra$interim_overall_rank
  extra$league <- c("A", "B", "B", "B")
  extra$group_position <- c(1L, 2L, 2L, 2L)
  expanded <- rbind(valid_with_position, extra)
  expanded_manifest <- phase16_test_simulation_manifest(expanded)
  normalized <- uefa_euro_normalize_nl_interim_projection(
    projected_rankings = expanded,
    manifest = expanded_manifest
  )
  pots <- uefa_euro_build_playoff_pots(
    pool = branch_results[[1L]],
    nl_eligibility = normalized,
    qualified_team_ids = c("team-nl-a01"),
    host_team_ids = c("team-nl-b01"),
    draw_conditions = phase16_test_draw_conditions()
  )
  expect_true(isTRUE(pots$valid))
  expect_setequal(
    unique(pots$pool$eligibility_source),
    c("runner_up", "nations_league_a_c_group_winner", "nations_league_d_group_winner", "nations_league_overall_fallback")
  )
  expect_false(any(pots$pool$team_id %in% c("team-nl-a01", "team-nl-b01")))
  expect_equal(sum(pots$pool$eligibility_source == "runner_up"), 4L)

  invalid_draw <- uefa_euro_simulate_qualification(
    activation = phase16_test_active_after_draw_bundle(),
    fixtures = phase16_test_active_after_draw_bundle()$fixtures,
    standings = complete$groups,
    hosts = phase16_test_resolved_hosts(0L),
    nl_eligibility = normalized,
    forecasts = phase16_test_simulation_forecast()$forecast,
    score_distributions = phase16_test_simulation_forecast()$score_distribution,
    draw_conditions = NULL,
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = paste(rep("4", 64L), collapse = ""),
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    state_manifest_sha256 = paste(rep("5", 64L), collapse = ""),
    simulation_count = 2L,
    seed = 16017L
  )
  expect_identical(invalid_draw$status, "suppressed")
  expect_equal(nrow(invalid_draw$probabilities), 0L)
  expect_true(grepl("unresolved_draw_conditions", invalid_draw$reason, fixed = TRUE))
  expect_true(grepl("unsupported_topology", invalid_draw$reason, fixed = TRUE))

  two_leg <- data.frame(
    leg_number = c(1L, 2L),
    fixture_id = c("replay-leg-1", "replay-leg-2"),
    home_team_id = c("team-replay-a", "team-replay-b"),
    away_team_id = c("team-replay-b", "team-replay-a"),
    regulation_home_goals = c(1L, 0L),
    regulation_away_goals = c(0L, 0L),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  resolved <- uefa_euro_resolve_two_leg_tie(two_leg, seed = 16017L)
  reversed <- uefa_euro_resolve_two_leg_tie(two_leg[2:1, , drop = FALSE], seed = 16017L)
  repeated <- uefa_euro_resolve_two_leg_tie(two_leg, seed = 16017L)
  expect_identical(resolved$status, "completed")
  expect_identical(resolved$winner_team_id, "team-replay-a")
  expect_identical(phase16_test_simulation_hash(resolved), phase16_test_simulation_hash(reversed))
  expect_identical(phase16_test_simulation_hash(resolved), phase16_test_simulation_hash(repeated))

  child_code <- paste0(
    "setwd(\"", phase16_test_project_root, "\");",
    "source(\"", file.path(phase16_test_project_root, "R/competition/uefa_euro_simulation.R"), "\");",
    "pair <- data.frame(leg_number=c(1L,2L), fixture_id=c(\"replay-leg-1\",\"replay-leg-2\"), home_team_id=c(\"team-replay-a\",\"team-replay-b\"), away_team_id=c(\"team-replay-b\",\"team-replay-a\"), regulation_home_goals=c(1L,0L), regulation_away_goals=c(0L,0L), stringsAsFactors=FALSE);",
    "result <- uefa_euro_resolve_two_leg_tie(pair, seed=16017L);",
    "cat(uefa_euro_sim_hash_data(result));"
  )
  child_output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(child_code)), stdout = TRUE, stderr = TRUE)
  expect_true(length(child_output) > 0L)
  expect_identical(tail(child_output, 1L), phase16_test_simulation_hash(resolved))

  active <- phase16_test_active_after_draw_bundle()
  fixture <- phase16_test_simulation_forecast()
  base_args <- list(
    activation = active,
    fixtures = active$fixtures,
    standings = complete$groups,
    hosts = phase16_test_resolved_hosts(0L),
    nl_eligibility = normalized,
    forecasts = fixture$forecast,
    score_distributions = fixture$score_distribution,
    draw_conditions = phase16_test_draw_conditions(),
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = paste(rep("4", 64L), collapse = ""),
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    state_manifest_sha256 = paste(rep("5", 64L), collapse = ""),
    simulation_count = 2L,
    seed = 16017L
  )
  normal <- do.call(uefa_euro_simulate_qualification, base_args)
  reversed_args <- base_args
  reversed_args$standings <- complete$groups[nrow(complete$groups):1L, , drop = FALSE]
  reversed_args$nl_eligibility <- normalized[nrow(normalized):1L, , drop = FALSE]
  replayed <- do.call(uefa_euro_simulate_qualification, reversed_args)
  expect_identical(normal$output_hashes, replayed$output_hashes)
})

phase16_test_outcomes_sha <- function(letter) {
  paste(rep(letter, 64L), collapse = "")
}

phase16_test_outcomes_lineage <- function() {
  list(
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = phase16_test_outcomes_sha("a"),
    source_artifact_ids = paste(
      paste0("source-artifact-euro-", c("fixtures", "groups", "results", "standings", "status"), "-v1"),
      collapse = "|"
    ),
    source_artifact_paths = paste(
      paste0("accepted/", c("fixtures", "groups", "results", "standings", "status"), ".csv"),
      collapse = "|"
    ),
    artifact_manifest_sha256 = phase16_test_outcomes_sha("b"),
    ruleset_version = phase16_test_ruleset_version,
    ruleset_sha256 = phase16_test_outcomes_sha("c"),
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    model_id = "open_nb_incumbent",
    model_sha256 = phase16_test_outcomes_sha("d"),
    release_manifest_sha256 = phase16_test_outcomes_sha("e"),
    release_selector_sha256 = phase16_test_outcomes_sha("f"),
    calibrator_id = "vector_w400_p0p010",
    calibrator_sha256 = phase16_test_outcomes_sha("1"),
    model_data_cutoff = "2026-06-10",
    state_manifest_sha256 = phase16_test_outcomes_sha("2"),
    forecast_status_sha256 = phase16_test_outcomes_sha("3"),
    forecasts_sha256 = phase16_test_outcomes_sha("4"),
    score_distributions_sha256 = phase16_test_outcomes_sha("5"),
    feature_cutoff_sha256 = phase16_test_outcomes_sha("6")
  )
}

phase16_test_outcomes_simulation <- function(status = "available", reason = "none") {
  active <- phase16_test_active_after_draw_bundle()
  teams <- active$teams$team_id
  probabilities <- data.frame(
    edition_id = phase16_test_edition_id,
    team_id = teams,
    probability = c(0.62, 0.38, 0.57, 0.43),
    qualification_status = "projected",
    status = status,
    reason = reason,
    scenario_id = "scenario-euro-2028-base",
    path_id = paste0("path-", seq_along(teams)),
    source_bundle_id = phase16_test_source_bundle_id,
    source_bundle_sha256 = phase16_test_outcomes_sha("a"),
    ruleset_version = phase16_test_ruleset_version,
    ruleset_sha256 = phase16_test_outcomes_sha("c"),
    model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
    model_data_cutoff = "2026-06-10",
    state_manifest_sha256 = phase16_test_outcomes_sha("2"),
    simulation_seed = 16017L,
    simulation_count = 100L,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  ledger <- data.frame(
    allocation_id = paste0("allocation-", seq_along(teams)),
    scenario_id = "scenario-euro-2028-base",
    edition_id = phase16_test_edition_id,
    team_id = teams,
    group_id = c("euro-group-a", "euro-group-a", "euro-group-b", "euro-group-b"),
    association_id = active$teams$association_id,
    host_slot_id = "",
    stage = "group",
    place_type = "direct",
    qualification_status = "projected",
    consumes_capacity = FALSE,
    qualification_eligibility_status = "eligible",
    probability = probabilities$probability,
    reason = reason,
    counted_match_ids = "",
    excluded_match_ids = "",
    tiebreak_evidence_ids = "",
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_id = "source-artifact-euro-groups-v1",
    ruleset_version = phase16_test_ruleset_version,
    ruleset_sha256 = phase16_test_outcomes_sha("c"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  topology <- data.frame(
    edition_id = phase16_test_edition_id,
    record_type = "group_stage",
    league = "",
    group_id = c("euro-group-a", "euro-group-b"),
    display_name = c("Group A", "Group B"),
    team_count = 2L,
    fixture_count = 2L,
    stage_id = "group-stage",
    stage_type = "group",
    legs = 2L,
    seed_policy = "official_draw",
    different_group = "",
    first_leg_home_policy = "official_schedule",
    tie_break_policy = "uefa_rules",
    cancellation_condition = "none",
    topology_status = status,
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_ids = "source-artifact-euro-groups-v1",
    ruleset_version = phase16_test_ruleset_version,
    ruleset_sha256 = phase16_test_outcomes_sha("c"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  stage_slots <- data.frame(
    edition_id = phase16_test_edition_id,
    slot_id = paste0("group-slot-", seq_along(teams)),
    stage_id = "group-stage",
    stage_type = "group",
    group_id = active$teams$group_id,
    slot_order = c(1L, 2L, 1L, 2L),
    entrant_type = "official_group_team",
    entrant_team_id = teams,
    entrant_source = "official_draw",
    slot_status = status,
    resolution_status = "resolved",
    resolution_reason = reason,
    source_bundle_id = phase16_test_source_bundle_id,
    source_artifact_ids = "source-artifact-euro-groups-v1",
    ruleset_version = phase16_test_ruleset_version,
    ruleset_sha256 = phase16_test_outcomes_sha("c"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    status = status,
    valid = identical(status, "available"),
    reason = reason,
    suppression_reason = reason,
    scenario_id = "scenario-euro-2028-base",
    scenario_status = if (identical(status, "available")) "resolved" else status,
    probabilities = probabilities,
    qualification_probabilities = probabilities,
    qualification_ledger = ledger,
    topology = topology,
    stage_slots = stage_slots,
    simulation_metadata = data.frame(
      edition_id = phase16_test_edition_id,
      status = status,
      reason = reason,
      simulation_seed = 16017L,
      simulation_count = 100L,
      source_bundle_id = phase16_test_source_bundle_id,
      source_bundle_sha256 = phase16_test_outcomes_sha("a"),
      ruleset_version = phase16_test_ruleset_version,
      ruleset_sha256 = phase16_test_outcomes_sha("c"),
      model_release_id = "phase14-open-nb-incumbent-calibrated-v1",
      model_data_cutoff = "2026-06-10",
      state_manifest_sha256 = phase16_test_outcomes_sha("2"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    output_hashes = list(
      probabilities = phase16_test_outcomes_sha("7"),
      qualification_ledger = phase16_test_outcomes_sha("8"),
      topology = phase16_test_outcomes_sha("9")
    )
  )
}

phase16_test_outcomes_model_lineage <- function() {
  phase16_test_outcomes_lineage()[c(
    "model_release_id", "model_id", "model_sha256", "release_manifest_sha256",
    "release_selector_sha256", "calibrator_id", "calibrator_sha256",
    "model_data_cutoff", "state_manifest_sha256", "forecast_status_sha256",
    "forecasts_sha256", "score_distributions_sha256", "feature_cutoff_sha256"
  )]
}

test_that("exact EURO outcomes contract supports active, active-after-draw, and pre_draw", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/uefa_euro_outcomes.R")

  expected <- file.path("outcomes", c(
    "competition_topology.csv", "stage_slots.csv", "projected_standings.csv",
    "projected_rankings.csv", "qualification_ledger.csv", "team_path_probabilities.csv",
    "fixture_forecast_form.csv", "simulation_metadata.csv", "outcomes_manifest.csv"
  ))
  expect_identical(phase16_euro_outcomes_expected_inventory(), expected)
  expect_identical(names(phase16_euro_outcomes_schema()), sub("^outcomes/", "", expected))

  active <- phase16_test_active_after_draw_bundle()
  active_candidate <- phase16_build_euro_outcomes_candidate(
    activation = active,
    simulation = phase16_test_outcomes_simulation(),
    source_lineage = phase16_test_outcomes_lineage(),
    model_lineage = phase16_test_outcomes_model_lineage(),
    generated_at_utc = "2027-03-01T12:30:00Z"
  )
  active_validation <- phase16_validate_euro_outcomes_bundle(active_candidate)
  expect_true(active_validation$valid, info = active_validation$failure_reason)
  expect_identical(active_candidate$candidate_status, "active")
  expect_true(nrow(active_candidate$competition_topology) > 0L)
  expect_true(nrow(active_candidate$stage_slots) > 0L)
  expect_true(nrow(active_candidate$qualification_ledger) > 0L)
  expect_true(nrow(active_candidate$team_path_probabilities) > 0L)
  expect_true(all(active_candidate$team_path_probabilities$probability >= 0))

  pre_draw <- phase16_test_pre_draw_bundle()
  pre_draw_candidate <- phase16_build_euro_outcomes_candidate(
    activation = pre_draw,
    source_lineage = phase16_test_outcomes_lineage(),
    model_lineage = phase16_test_outcomes_model_lineage(),
    generated_at_utc = "2026-08-23T12:30:00Z"
  )
  pre_draw_validation <- phase16_validate_euro_outcomes_bundle(pre_draw_candidate)
  expect_true(pre_draw_validation$valid, info = pre_draw_validation$failure_reason)
  expect_identical(pre_draw_candidate$candidate_status, "pre_draw")
  expect_true(all(vapply(pre_draw_candidate[setdiff(names(pre_draw_candidate), c(
    "candidate_status", "activation_status", "reason", "lineage", "manifest",
    "generated_at_utc", "edition_id"
  ))], function(value) is.data.frame(value) && nrow(value) == 0L, logical(1))))
  expect_identical(pre_draw_candidate$forecast_status, "pre_draw")
})

test_that("EURO outcomes writer and reader enforce the registered-root boundary and replay lineage", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/uefa_euro_outcomes.R")
  candidate <- phase16_build_euro_outcomes_candidate(
    activation = phase16_test_active_after_draw_bundle(),
    simulation = phase16_test_outcomes_simulation(),
    source_lineage = phase16_test_outcomes_lineage(),
    model_lineage = phase16_test_outcomes_model_lineage(),
    generated_at_utc = "2027-03-01T12:30:00Z"
  )
  output_root <- file.path(tempdir(), paste0("phase16-euro-outcomes-", as.integer(Sys.time())))
  written <- phase16_write_euro_outcomes_bundle(candidate, output_root = output_root)
  expect_true(isTRUE(written$registered))
  expect_true(all(file.exists(file.path(output_root, phase16_euro_outcomes_expected_inventory()))))
  readback <- phase16_read_euro_outcomes_bundle(output_root = output_root)
  expect_true(phase16_compare_euro_outcomes_replays(candidate, readback)$identical)

  invalid <- candidate
  invalid$team_path_probabilities$probability[1L] <- 2
  expect_false(phase16_validate_euro_outcomes_bundle(invalid)$valid)
  expect_error(
    phase16_write_euro_outcomes_bundle(invalid, output_root = file.path(tempdir(), "phase16-invalid")),
    "validated|invalid|probability"
  )
})

test_that("EURO outcomes retain typed blocked states and never emit blocked probabilities", {
  phase16_test_source("R/competition/uefa_euro_rules.R")
  phase16_test_source("R/competition/uefa_euro_outcomes.R")
  lineage <- phase16_test_outcomes_lineage()
  model_lineage <- phase16_test_outcomes_model_lineage()

  blocked_cases <- list(
    unavailable = {
      activation <- phase16_test_active_after_draw_bundle()
      activation$activation_status <- "unavailable"
      activation$reason <- "source_bundle_missing"
      activation
    },
    unresolved = {
      activation <- phase16_test_active_after_draw_bundle()
      activation$activation_status <- "active"
      activation
    },
    unsupported_topology = {
      activation <- phase16_test_active_after_draw_bundle()
      activation$activation_status <- "active"
      activation
    },
    revision_blocked = {
      activation <- phase16_test_active_after_draw_bundle()
      activation$activation_status <- "revision_blocked"
      activation$reason <- "incumbent_revision_blocked"
      activation
    }
  )
  simulations <- list(
    unavailable = NULL,
    unresolved = phase16_test_outcomes_simulation("unresolved", "external_eligibility_unresolved"),
    unsupported_topology = phase16_test_outcomes_simulation("unsupported_topology", "unsupported_topology"),
    revision_blocked = NULL
  )
  expected_status <- c(
    unavailable = "unavailable", unresolved = "unresolved",
    unsupported_topology = "unsupported_topology", revision_blocked = "revision_blocked"
  )
  for (case_name in names(blocked_cases)) {
    candidate <- phase16_build_euro_outcomes_candidate(
      activation = blocked_cases[[case_name]],
      simulation = simulations[[case_name]],
      source_lineage = lineage,
      model_lineage = model_lineage,
      generated_at_utc = "2027-03-01T12:30:00Z"
    )
    expect_identical(candidate$candidate_status, unname(expected_status[[case_name]]), info = case_name)
    expect_true(phase16_validate_euro_outcomes_bundle(candidate)$valid, info = case_name)
    expect_equal(nrow(candidate$team_path_probabilities), 0L, info = case_name)
    expect_equal(nrow(candidate$qualification_ledger), 0L, info = case_name)
  }
})
