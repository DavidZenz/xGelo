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
  expect_match(update_body, "phase16_validate_euro_source_bundle")
  expect_match(update_body, "phase13_transition_competition_edition")
})
