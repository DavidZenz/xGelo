library(testthat)

phase14_standings_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_standings_fixture_path <- file.path(
  phase14_standings_test_project_root,
  "tests/fixtures/phase14/standings_reconciliation_cases.csv"
)

phase14_standings_cases <- function() {
  utils::read.csv(
    phase14_standings_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

phase14_fixture_reduce_standings <- function(matches, team_ids) {
  matches <- matches[as.logical(matches$counts_for_standings), , drop = FALSE]
  rows <- lapply(team_ids, function(team_id) {
    home <- matches$home_team_id == team_id
    away <- matches$away_team_id == team_id
    goals_for <- c(matches$final_home_goals[home], matches$final_away_goals[away])
    goals_against <- c(matches$final_away_goals[home], matches$final_home_goals[away])
    data.frame(
      team_id = team_id,
      played = length(goals_for),
      wins = sum(goals_for > goals_against),
      draws = sum(goals_for == goals_against),
      losses = sum(goals_for < goals_against),
      goals_for = sum(goals_for),
      goals_against = sum(goals_against),
      goal_difference = sum(goals_for) - sum(goals_against),
      points = 3L * sum(goals_for > goals_against) + sum(goals_for == goals_against),
      stringsAsFactors = FALSE
    )
  })
  output <- do.call(rbind, rows)
  order_index <- order(
    -output$points,
    -output$goal_difference,
    -output$goals_for,
    -output$wins,
    output$team_id
  )
  output$computed_rank <- match(seq_len(nrow(output)), order_index)
  output
}

phase14_fixture_reconciliation_status <- function(row) {
  aggregate_fields <- c(
    "played", "wins", "draws", "losses", "goals_for", "goals_against",
    "goal_difference", "points"
  )
  official_fields <- paste0("official_", aggregate_fields)

  if (!is.na(row$official_source_bundle_id) &&
      row$official_source_bundle_id != row$source_bundle_id) {
    return("foreign_source_bundle_rejected")
  }
  if (is.na(row$official_rank) && all(is.na(row[, official_fields, drop = TRUE]))) {
    return("official_absent_provisional")
  }
  if (any(is.na(row[, official_fields, drop = TRUE]))) {
    return("partial_official_blocked")
  }
  computed <- as.numeric(row[, aggregate_fields, drop = TRUE])
  official <- as.numeric(row[, official_fields, drop = TRUE])
  if (any(computed != official)) return("aggregate_mismatch_blocked")
  if (is.na(row$official_rank)) return("partial_official_blocked")
  if (row$computed_rank != row$official_rank) return("rank_only_warning")
  "exact"
}

production_path <- file.path(
  phase14_standings_test_project_root,
  "R/competition/standings.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)
source(file.path(phase14_standings_test_project_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
source(file.path(phase14_standings_test_project_root, "R/competition/team_identity.R"), local = .GlobalEnv)
source(file.path(phase14_standings_test_project_root, "R/competition/publication_hashes.R"), local = .GlobalEnv)

test_that("standings fixture freezes D-06 universal arithmetic", {
  cases <- phase14_standings_cases()
  required <- c(
    "record_type", "case_id", "match_id", "edition_id", "group_id",
    "state_cutoff_utc", "source_bundle_id", "official_source_bundle_id",
    "ruleset_adapter_id", "team_id", "home_team_id", "away_team_id",
    "evidence_completed_at_utc", "final_home_goals", "final_away_goals",
    "counts_for_standings", "computed_rank", "played", "wins", "draws",
    "losses", "goals_for", "goals_against", "goal_difference", "points",
    "official_rank", "official_played", "official_wins", "official_draws",
    "official_losses", "official_goals_for", "official_goals_against",
    "official_goal_difference", "official_points",
    "expected_reconciliation_status", "expected_severity",
    "expected_publication_disposition", "expected_ordering_status"
  )

  expect_named(cases, required)
  expect_equal(anyDuplicated(cases$case_id), 0L)
  expect_lte(nrow(cases), 20L)

  matches <- cases[cases$record_type == "match", , drop = FALSE]
  expected <- cases[cases$record_type == "expected_team", , drop = FALSE]
  reduced <- phase14_fixture_reduce_standings(matches, expected$team_id)
  expected <- expected[match(reduced$team_id, expected$team_id), , drop = FALSE]
  rownames(reduced) <- NULL
  rownames(expected) <- NULL
  metric_fields <- c(
    "computed_rank", "played", "wins", "draws", "losses", "goals_for",
    "goals_against", "goal_difference", "points"
  )

  expect_equal(reduced[, metric_fields], expected[, metric_fields])
  expect_true(all(reduced$played == reduced$wins + reduced$draws + reduced$losses))
  expect_true(all(reduced$goal_difference == reduced$goals_for - reduced$goals_against))
  expect_true(all(expected$expected_ordering_status == "provisional"))
  expect_true(all(expected$ruleset_adapter_id == "none"))
})

test_that("standings snapshots require the exact four-part key", {
  cases <- phase14_standings_cases()
  key_fields <- c("edition_id", "group_id", "state_cutoff_utc", "source_bundle_id")

  expect_true(all(vapply(cases[key_fields], function(value) {
    all(!is.na(value) & nzchar(value))
  }, logical(1))))
  expect_equal(
    length(unique(do.call(paste, c(cases[key_fields], sep = "|")))),
    1L
  )
})

test_that("D-08 reconciliation distinguishes every fail-closed outcome", {
  cases <- phase14_standings_cases()
  reconciliation <- cases[cases$record_type == "reconciliation", , drop = FALSE]
  actual <- vapply(
    seq_len(nrow(reconciliation)),
    function(index) phase14_fixture_reconciliation_status(reconciliation[index, , drop = FALSE]),
    character(1)
  )

  expect_identical(actual, reconciliation$expected_reconciliation_status)
  expect_setequal(
    actual,
    c(
      "exact", "rank_only_warning", "aggregate_mismatch_blocked",
      "partial_official_blocked", "official_absent_provisional",
      "foreign_source_bundle_rejected"
    )
  )
  blocked <- grepl("blocked|rejected", reconciliation$expected_reconciliation_status)
  expect_true(all(reconciliation$expected_publication_disposition[blocked] == "retain_prior"))
  absent <- reconciliation$expected_reconciliation_status == "official_absent_provisional"
  expect_true(all(reconciliation$expected_ordering_status[absent] == "provisional"))
  expect_false(any(reconciliation$expected_ordering_status[absent] == "official"))
})

test_that("production standings reducer honors frozen keys and arithmetic", {
  skip_if_not(exists("phase14_compute_standings"))

  cases <- phase14_standings_cases()
  matches <- cases[cases$record_type == "match", , drop = FALSE]
  matches$match_status <- "completed"
  expected <- cases[cases$record_type == "expected_team", , drop = FALSE]
  standings <- phase14_compute_standings(
    matches = matches,
    edition_id = "wc2026",
    group_id = "A",
    state_cutoff_utc = "2026-06-20T00:00:00Z",
    source_bundle_id = "bundle-a",
    ruleset_adapter = NULL
  )

  required <- c(
    "edition_id", "group_id", "state_cutoff_utc", "source_bundle_id",
    "team_id", "played", "wins", "draws", "losses", "goals_for",
    "goals_against", "goal_difference", "points", "computed_rank",
    "ordering_status"
  )
  expect_true(all(required %in% names(standings)))
  standings <- standings[match(expected$team_id, standings$team_id), , drop = FALSE]
  expect_equal(standings$points, expected$points)
  expect_equal(standings$computed_rank, expected$computed_rank)
  expect_true(all(standings$ordering_status == "provisional"))
})

phase14_standings_test_identity_map <- function() {
  data.frame(
    team_id = c("team-a", "team-b"),
    fifa_code = c("AAA", "BBB"),
    canonical_name = c("Team A", "Team B"),
    aliases = c("", ""),
    uefa_source_team_id = c("source-a", "source-b"),
    uefa_display_name_current = c("Team A", "Team B"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("accepted standings expose an exact state-ready v2 schema and hash dispatch", {
  expected <- phase14_normalized_standings_schema()
  expect_identical(expected[[1L]], "schema_version")
  expect_true(all(c(
    "edition_id", "group_id", "source_group_id", "team_id", "source_team_id",
    "official_rank", "played", "wins", "draws", "losses", "goals_for",
    "goals_against", "goal_difference", "points", "official_played",
    "official_wins", "official_draws", "official_losses", "official_goals_for",
    "official_goals_against", "official_goal_difference", "official_points",
    "source_bundle_id", "source_artifact_id", "mapping_warning", "row_sha256"
  ) %in% expected))
  expect_identical(
    phase14_publication_table_schema("standings", "phase14-normalized-standings-v2"),
    expected
  )
  expect_identical(
    phase13_publication_table_schema("standings", "phase14-normalized-standings-v2"),
    expected
  )
  expect_identical(
    phase13_publication_table_schema("standings"),
    c("schema_version", phase13_source_compact_resource_schema()$standings, "edition_id", "source_artifact_id", "row_sha256")
  )
})

test_that("accepted standings preserve mapped identities and official aggregates independently", {
  identity_map <- phase14_standings_test_identity_map()
  source_rows <- data.frame(
    source_team_id = "source-a",
    source_group_id = "group-a",
    position = 1L,
    points = 7L,
    played = 3L,
    wins = 2L,
    draws = 1L,
    losses = 0L,
    goals_for = 5L,
    goals_against = 1L,
    goal_difference = 4L,
    source_bundle_id = "bundle-a",
    source_artifact_id = "artifact-standings-v2",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  normalized <- phase14_normalize_accepted_standings_rows(
    source_rows,
    identity_map = identity_map,
    edition_id = "edition-v2",
    source_bundle_id = "bundle-a",
    source_artifact_id = "artifact-standings-v2"
  )

  expect_named(normalized, phase14_normalized_standings_schema())
  expect_identical(normalized$schema_version, "phase14-normalized-standings-v2")
  expect_identical(normalized$team_id, "team-a")
  expect_identical(normalized$source_team_id, "source-a")
  expect_identical(normalized$group_id, "group-a")
  expect_identical(normalized$source_group_id, "group-a")
  expect_identical(normalized$official_rank, 1L)
  expect_identical(normalized$official_points, 7L)
  expect_identical(normalized$played, 3L)
  expect_identical(normalized$official_played, 3L)
  expect_identical(normalized$goal_difference, 4L)
  expect_identical(normalized$official_goal_difference, 4L)
  expect_identical(normalized$source_bundle_id, "bundle-a")
  expect_identical(normalized$source_artifact_id, "artifact-standings-v2")
  expect_true(grepl("^[0-9a-f]{64}$", normalized$row_sha256))

  reordered <- normalized[, rev(names(normalized)), drop = FALSE]
  reordered <- reordered[, phase14_normalized_standings_schema(), drop = FALSE]
  reordered$row_sha256 <- phase13_row_sha256(reordered)
  expect_identical(reordered$row_sha256, normalized$row_sha256)

  expect_error(
    phase14_normalize_accepted_standings_rows(
      source_rows,
      identity_map = identity_map,
      edition_id = "edition-v2",
      source_bundle_id = "foreign-bundle",
      source_artifact_id = "artifact-standings-v2"
    ),
    "source_bundle|forged|lineage"
  )
})

test_that("standings v2 keeps absent official aggregate evidence typed and unresolved", {
  identity_map <- phase14_standings_test_identity_map()
  source_rows <- data.frame(
    source_team_id = "source-a",
    source_group_id = "group-a",
    position = 1L,
    points = 0L,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  normalized <- phase14_normalize_accepted_standings_rows(
    source_rows,
    identity_map = identity_map,
    edition_id = "edition-v2",
    source_bundle_id = "bundle-a",
    source_artifact_id = "artifact-standings-v2"
  )

  expect_identical(normalized$official_rank, 1L)
  expect_identical(normalized$official_points, 0L)
  expect_true(all(is.na(normalized[, c(
    "played", "wins", "draws", "losses", "goals_for", "goals_against",
    "goal_difference", "official_played", "official_wins", "official_draws",
    "official_losses", "official_goals_for", "official_goals_against",
    "official_goal_difference"
  ), drop = FALSE])))
  expect_true(nzchar(normalized$mapping_warning))
})
