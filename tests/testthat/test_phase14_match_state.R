library(testthat)

phase14_match_state_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_match_state_fixture_path <- file.path(
  phase14_match_state_test_project_root,
  "tests/fixtures/phase14/match_lifecycle_cases.csv"
)

phase14_match_state_cases <- function() {
  utils::read.csv(
    phase14_match_state_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
}

phase14_score_pair_is_complete <- function(home, away) {
  xor(is.na(home), is.na(away)) == FALSE
}

phase14_match_state_builder_input <- function(cases) {
  output <- cases[, c(
    "source_fixture_id", "source_status", "regulation_home_goals",
    "regulation_away_goals", "final_home_goals", "final_away_goals",
    "shootout_home_goals", "shootout_away_goals", "winner_team_id",
    "counts_for_standings", "counts_for_form"
  ), drop = FALSE]
  output$match_id <- cases$expected_match_id
  output$match_status <- cases$expected_match_status
  output$completion_method <- cases$expected_completion_method
  output$edition_id <- "phase14-test-edition"
  output$home_team_id <- "team_home"
  output$away_team_id <- "team_away"
  output$scheduled_at_utc <- "2026-01-01T12:00:00Z"
  output$evidence_completed_at_utc <- ifelse(
    cases$expected_match_status == "completed",
    "2026-01-01T13:00:00Z",
    NA_character_
  )
  output
}

production_path <- file.path(
  phase14_match_state_test_project_root,
  "R/competition/match_state.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)
source(file.path(phase14_match_state_test_project_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
source(file.path(phase14_match_state_test_project_root, "R/competition/team_identity.R"), local = .GlobalEnv)

test_that("lifecycle fixture freezes the complete D-02 state matrix", {
  cases <- phase14_match_state_cases()
  required <- c(
    "case_id", "identity_case_id", "source_fixture_id", "source_status",
    "expected_match_status", "expected_completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "winner_team_id", "counts_for_standings", "counts_for_form",
    "expected_match_id", "expected_valid", "expected_reason"
  )

  expect_named(cases, required)
  expect_equal(anyDuplicated(cases$case_id), 0L)
  expect_lte(nrow(cases), 20L)
  expect_setequal(
    unique(stats::na.omit(cases$expected_match_status)),
    c("scheduled", "in_progress", "completed", "postponed", "abandoned")
  )
  expect_setequal(
    unique(cases$expected_completion_method),
    c("not_applicable", "regulation", "extra_time", "penalties", "awarded")
  )

  valid <- cases[cases$expected_valid, , drop = FALSE]
  completed <- valid$expected_match_status == "completed"
  expect_true(all(valid$expected_completion_method[!completed] == "not_applicable"))
  expect_true(all(valid$expected_completion_method[completed] != "not_applicable"))

  unknown <- cases[cases$case_id == "unknown-source", , drop = FALSE]
  expect_equal(nrow(unknown), 1L)
  expect_false(unknown$expected_valid)
  expect_true(is.na(unknown$expected_match_status))
  expect_identical(unknown$expected_reason, "unmapped_source_status")
})

test_that("score axes and count flags encode D-03 and D-04 independently", {
  cases <- phase14_match_state_cases()
  valid <- cases[cases$expected_valid, , drop = FALSE]
  for (prefix in c("regulation", "final", "shootout")) {
    home <- valid[[paste0(prefix, "_home_goals")]]
    away <- valid[[paste0(prefix, "_away_goals")]]
    expect_true(all(phase14_score_pair_is_complete(home, away)), info = prefix)
  }

  penalties <- valid[valid$expected_completion_method == "penalties", , drop = FALSE]
  expect_equal(nrow(penalties), 1L)
  expect_identical(penalties$final_home_goals, penalties$final_away_goals)
  expect_true(penalties$shootout_home_goals != penalties$shootout_away_goals)

  awarded <- valid[valid$expected_completion_method == "awarded", , drop = FALSE]
  expect_true(awarded$counts_for_standings)
  expect_false(awarded$counts_for_form)
  expect_true(is.na(awarded$regulation_home_goals))
  expect_false(is.na(awarded$final_home_goals))

  inactive <- valid$expected_match_status %in% c(
    "scheduled", "in_progress", "postponed", "abandoned"
  )
  expect_true(all(!valid$counts_for_standings[inactive]))
  expect_true(all(!valid$counts_for_form[inactive]))

  invalid <- cases[!cases$expected_valid, , drop = FALSE]
  expect_setequal(
    invalid$expected_reason,
    c(
      "unmapped_source_status", "unpaired_final_score",
      "penalty_requires_tied_final_score",
      "shootout_requires_penalty_completion"
    )
  )
})

test_that("score and status corrections cannot remint canonical identity", {
  cases <- phase14_match_state_cases()
  corrections <- cases[cases$identity_case_id == "correction-1", , drop = FALSE]

  expect_equal(nrow(corrections), 2L)
  expect_equal(length(unique(corrections$source_fixture_id)), 1L)
  expect_equal(length(unique(corrections$expected_match_id)), 1L)
  expect_setequal(corrections$expected_match_status, c("scheduled", "completed"))
  expect_false(identical(
    corrections$final_home_goals[[1L]],
    corrections$final_home_goals[[2L]]
  ))
})

test_that("canonical match API enforces the frozen lifecycle and score contract", {
  cases <- phase14_match_state_cases()
  valid <- cases[cases$expected_valid, , drop = FALSE]
  canonical <- phase14_build_canonical_matches(
    phase14_match_state_builder_input(valid)
  )

  expected_valid <- valid[!duplicated(valid$expected_match_id, fromLast = TRUE), , drop = FALSE]
  expect_equal(nrow(canonical), nrow(expected_valid))
  expect_true(all(c(
    "match_id", "source_status", "match_status", "completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "winner_team_id", "counts_for_standings", "counts_for_form"
  ) %in% names(canonical)))
  expected_order <- order(expected_valid$expected_match_id, method = "radix")
  expect_identical(as.character(canonical$match_id), expected_valid$expected_match_id[expected_order])
  expect_identical(as.character(canonical$source_status), expected_valid$source_status[expected_order])
  expect_identical(as.character(canonical$match_status), expected_valid$expected_match_status[expected_order])
  expect_identical(
    as.character(canonical$completion_method),
    expected_valid$expected_completion_method[expected_order]
  )

  invalid <- cases[!cases$expected_valid, , drop = FALSE]
  for (index in seq_len(nrow(invalid))) {
    expect_error(
      phase14_build_canonical_matches(
        phase14_match_state_builder_input(invalid[index, , drop = FALSE])
      ),
      "source|status|score|penalt|shootout|pair|unknown|unmapped",
      info = invalid$case_id[[index]]
    )
  }
})

test_that("canonical match validator enforces independent lifecycle and completion axes", {
  cases <- phase14_match_state_cases()
  base <- phase14_match_state_builder_input(cases[cases$case_id == "completed-regulation", , drop = FALSE])

  invalid_axes <- list(
    lifecycle_completion_mismatch = transform(base, match_status = "scheduled"),
    completed_without_method = transform(base, completion_method = "not_applicable"),
    scheduled_with_score = transform(
      phase14_match_state_builder_input(cases[cases$case_id == "scheduled", , drop = FALSE]),
      final_home_goals = 1L,
      final_away_goals = 0L
    ),
    unknown_source_status = transform(base, source_status = "mystery_closed", match_status = NA_character_)
  )

  for (name in names(invalid_axes)) {
    expect_error(
      phase14_build_canonical_matches(invalid_axes[[name]]),
      "status|completion|score|unknown|unmapped",
      info = name
    )
  }
})

test_that("completed source labels do not collapse the independent completion axis", {
  cases <- phase14_match_state_cases()
  extra_time <- phase14_match_state_builder_input(
    cases[cases$case_id == "completed-extra-time", , drop = FALSE]
  )
  extra_time$source_status <- "completed"
  canonical <- phase14_build_canonical_matches(extra_time)
  expect_identical(canonical$match_status, "completed")
  expect_identical(canonical$completion_method, "extra_time")
  expect_identical(canonical$regulation_home_goals, 1L)
  expect_identical(canonical$final_home_goals, 2L)
})

test_that("canonical score semantics reject foreign links and preserve correction hashes", {
  cases <- phase14_match_state_cases()
  valid <- phase14_match_state_builder_input(cases[cases$case_id == "completed-penalties", , drop = FALSE])
  valid$home_team_id <- "team_home"
  valid$away_team_id <- "team_away"
  valid$edition_id <- "edition-test"
  valid$scheduled_at_utc <- "2026-01-01T12:00:00Z"
  valid$evidence_completed_at_utc <- "2026-01-01T13:00:00Z"

  canonical <- phase14_build_canonical_matches(valid, require_evidence = TRUE)
  expect_identical(canonical$winner_team_id, "team_home")
  expect_identical(canonical$final_home_goals, 1L)
  expect_identical(canonical$shootout_home_goals, 5L)
  expect_silent(phase14_validate_canonical_matches(canonical, require_evidence = TRUE))

  corrected <- valid
  corrected$final_home_goals <- 2L
  corrected$final_away_goals <- 2L
  corrected$shootout_home_goals <- 6L
  corrected$shootout_away_goals <- 5L
  corrected$winner_team_id <- "team_home"
  corrected$evidence_completed_at_utc <- "2026-01-01T14:00:00Z"
  corrected_canonical <- phase14_build_canonical_matches(corrected, require_evidence = TRUE)
  expect_identical(corrected_canonical$match_id, canonical$match_id)
  expect_false(identical(corrected_canonical$row_sha256, canonical$row_sha256))

  foreign <- list(
    fixtures = data.frame(
      edition_id = "edition-test",
      fixture_id = "fixture-1",
      uefa_source_fixture_id = "fixture-1",
      home_team_id = "team_home",
      away_team_id = "team_away",
      scheduled_at_utc = "2026-01-01T12:00:00Z",
      source_status = "scheduled",
      stringsAsFactors = FALSE
    ),
    results = transform(
      valid,
      source_fixture_id = "foreign-fixture",
      source_status = "finished"
    )
  )
  expect_error(
    phase14_build_canonical_matches(foreign),
    "foreign|fixture|link|source",
    info = "foreign accepted result link"
  )
})

test_that("canonical production batch covers accepted and historical inputs", {
  historical <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/processed/martj42_historical_normalized.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  fixtures <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  results <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/results.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  crosswalk <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/competition/registries/match_identity.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )

  canonical <- phase14_build_canonical_matches(
    list(competition = list(fixtures = fixtures, results = results), historical = historical),
    crosswalk = crosswalk
  )

  expect_equal(nrow(fixtures), 156L)
  expect_equal(nrow(results), 156L)
  expect_equal(nrow(canonical), nrow(historical) + nrow(fixtures))
  expect_equal(length(unique(canonical$match_id)), nrow(historical) + nrow(fixtures))
  expect_true(all(c(
    "edition_id", "source_lineage_id", "source_status", "match_status",
    "completion_method", "evidence_completed_at_utc", "row_sha256", "table_sha256"
  ) %in% names(canonical)))
  expect_silent(phase14_validate_canonical_matches(canonical, crosswalk = crosswalk))
})

phase14_match_state_test_identity_map <- function() {
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

test_that("accepted match contracts expose explicit versioned v2 schemas", {
  fixture_schema <- phase14_normalized_fixture_schema()
  result_schema <- phase14_normalized_result_schema()

  expect_identical(
    phase14_source_compact_resource_schema()$fixtures,
    c(
      phase13_source_compact_resource_schema()$fixtures,
      "source_group_id", "group_id", "source_status", "kickoff_confirmed",
      "confirmed_kickoff_at_utc"
    )
  )
  expect_true(all(c(
    "source_group_id", "group_id", "source_status", "kickoff_confirmed",
    "confirmed_kickoff_at_utc"
  ) %in% fixture_schema))
  expect_true(all(c(
    "source_status", "match_status", "completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "winner_team_id", "evidence_completed_at_utc", "counts_for_standings",
    "counts_for_form"
  ) %in% result_schema))
  expect_identical(
    phase14_normalized_fixture_schema()[[1L]],
    "schema_version"
  )
  expect_identical(
    phase14_normalized_result_schema()[[1L]],
    "schema_version"
  )
})

test_that("fixture v2 preserves source wording and fails closed on optional evidence", {
  identity_map <- phase14_match_state_test_identity_map()
  source_fixture <- data.frame(
    source_fixture_id = "fixture-v2",
    source_group_id = "group-a",
    group_id = "group-a",
    home_uefa_source_team_id = "source-a",
    away_uefa_source_team_id = "source-b",
    home_display_name = "Team A",
    away_display_name = "Team B",
    scheduled_at_utc = "2026-06-10T18:00:00Z",
    status = "scheduled",
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = "2026-06-10T18:00:00Z",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  normalized <- phase13_normalize_fixture_rows(
    source_fixture,
    identity_map = identity_map,
    edition_id = "edition-v2",
    source_artifact_id = "artifact-fixtures-v2",
    schema_version = "phase14-normalized-fixture-v2"
  )

  expect_named(normalized, phase14_normalized_fixture_schema())
  expect_identical(normalized$schema_version, "phase14-normalized-fixture-v2")
  expect_identical(normalized$fixture_id, "edition-v2-fixture-v2")
  expect_identical(normalized$source_status, "scheduled")
  expect_identical(normalized$group_id, "group-a")
  expect_identical(normalized$source_group_id, "group-a")
  expect_true(normalized$kickoff_confirmed)
  expect_identical(normalized$confirmed_kickoff_at_utc, "2026-06-10T18:00:00Z")
  expect_identical(normalized$source_artifact_id, "artifact-fixtures-v2")
  expect_true(grepl("^[0-9a-f]{64}$", normalized$row_sha256))

  absent <- source_fixture[, c(
    "source_fixture_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status"
  ), drop = FALSE]
  absent <- phase13_normalize_fixture_rows(
    absent,
    identity_map = identity_map,
    edition_id = "edition-v2",
    source_artifact_id = "artifact-fixtures-v2",
    schema_version = "phase14-normalized-fixture-v2"
  )
  expect_false(absent$kickoff_confirmed)
  expect_true(is.na(absent$source_group_id))
  expect_true(is.na(absent$group_id))
  expect_true(is.na(absent$confirmed_kickoff_at_utc))
})

test_that("result v2 keeps lifecycle/completion and score axes independent", {
  identity_map <- phase14_match_state_test_identity_map()
  source_fixture <- data.frame(
    source_fixture_id = "fixture-v2",
    source_group_id = "group-a",
    group_id = "group-a",
    home_uefa_source_team_id = "source-a",
    away_uefa_source_team_id = "source-b",
    home_display_name = "Team A",
    away_display_name = "Team B",
    scheduled_at_utc = "2026-06-10T18:00:00Z",
    status = "after_penalties",
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = "2026-06-10T18:00:00Z",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  normalized_fixtures <- phase13_normalize_fixture_rows(
    source_fixture,
    identity_map = identity_map,
    edition_id = "edition-v2",
    source_artifact_id = "artifact-fixtures-v2",
    schema_version = "phase14-normalized-fixture-v2"
  )
  source_result <- data.frame(
    source_fixture_id = "fixture-v2",
    status = "after_penalties",
    home_goals = 1L,
    away_goals = 1L,
    match_status = "completed",
    completion_method = "penalties",
    regulation_home_goals = 1L,
    regulation_away_goals = 1L,
    final_home_goals = 1L,
    final_away_goals = 1L,
    shootout_home_goals = 4L,
    shootout_away_goals = 3L,
    winner_team_id = "team-a",
    evidence_completed_at_utc = "2026-06-10T20:10:00Z",
    counts_for_standings = TRUE,
    counts_for_form = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  normalized <- phase13_normalize_accepted_result_rows(
    source_result,
    normalized_fixtures = normalized_fixtures,
    edition_id = "edition-v2",
    source_artifact_id = "artifact-results-v2",
    schema_version = "phase14-normalized-result-v2"
  )

  expect_named(normalized, phase14_normalized_result_schema())
  expect_identical(normalized$schema_version, "phase14-normalized-result-v2")
  expect_identical(normalized$source_status, "after_penalties")
  expect_identical(normalized$match_status, "completed")
  expect_identical(normalized$completion_method, "penalties")
  expect_identical(normalized$home_goals, 1L)
  expect_identical(normalized$final_home_goals, 1L)
  expect_identical(normalized$shootout_home_goals, 4L)
  expect_identical(normalized$winner_team_id, "team-a")
  expect_identical(normalized$evidence_completed_at_utc, "2026-06-10T20:10:00Z")
  expect_true(normalized$counts_for_standings)
  expect_true(normalized$counts_for_form)
  expect_identical(normalized$fixture_source_artifact_id, "artifact-fixtures-v2")
  expect_true(grepl("^[0-9a-f]{64}$", normalized$row_sha256))

  unresolved <- data.frame(
    source_fixture_id = "fixture-v2",
    status = "mystery_closed",
    home_goals = 2L,
    away_goals = 0L,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  unresolved <- phase13_normalize_accepted_result_rows(
    unresolved,
    normalized_fixtures = normalized_fixtures,
    edition_id = "edition-v2",
    source_artifact_id = "artifact-results-v2",
    schema_version = "phase14-normalized-result-v2"
  )
  expect_true(is.na(unresolved$match_status))
  expect_identical(unresolved$completion_method, "not_applicable")
  expect_true(is.na(unresolved$final_home_goals))
  expect_false(unresolved$counts_for_standings)
  expect_false(unresolved$counts_for_form)
  expect_true(is.na(unresolved$evidence_completed_at_utc))
})

phase14_match_state_test_api <- function(acquire, name) {
  get(name, envir = acquire, inherits = TRUE)
}

phase14_match_state_test_copy_tree <- function(source, target) {
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  for (path in list.files(source, full.names = TRUE, all.files = FALSE)) {
    destination <- file.path(target, basename(path))
    if (dir.exists(path)) {
      phase14_match_state_test_copy_tree(path, destination)
    } else {
      stopifnot(file.copy(path, destination, overwrite = TRUE))
    }
  }
  invisible(target)
}

phase14_match_state_test_snapshot_tree <- function(root, include_bytes = TRUE) {
  if (!dir.exists(root)) return(setNames(list(), character()))
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[!file.info(files)$isdir]
  if (!length(files)) return(setNames(list(), character()))
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  setNames(lapply(files, function(path) {
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    list(
      bytes = if (isTRUE(include_bytes)) bytes else raw(0),
      byte_count = length(bytes),
      sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE)
    )
  }), substring(files, nchar(root) + 2L))
}

phase14_match_state_test_load_acquire <- function() {
  acquire <- new.env(parent = globalenv())
  previous_directory <- getwd()
  setwd(phase14_match_state_test_project_root)
  on.exit(setwd(previous_directory), add = TRUE)
  sys.source(
    file.path(phase14_match_state_test_project_root, "scripts/acquire_uefa_snapshot.R"),
    envir = acquire
  )
  acquire
}

phase14_match_state_test_copy_sandbox <- function() {
  root <- tempfile("phase14-schema-v2-", tmpdir = phase14_match_state_test_project_root)
  accepted_root <- file.path(root, "data/competition/accepted")
  registry_root <- file.path(root, "data/competition/registries")
  raw_root <- file.path(root, "data/competition/local_raw")
  phase14_match_state_test_copy_tree(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted"),
    accepted_root
  )
  phase14_match_state_test_copy_tree(
    file.path(phase14_match_state_test_project_root, "data/competition/local_raw"),
    raw_root
  )
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  registry_files <- file.path(
    phase14_match_state_test_project_root,
    "data/competition/registries",
    c("competition_editions.csv", "source_artifacts.csv", "source_bundles.csv", "team_identity.csv")
  )
  stopifnot(all(file.copy(registry_files, registry_root, overwrite = TRUE)))
  refresh_marker <- file.path(
    registry_root,
    "refresh_batches",
    "keep",
    "blocked_refresh.json"
  )
  dir.create(dirname(refresh_marker), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw("pre-existing refresh history"), refresh_marker)
  unrelated <- file.path(root, "data/competition/unrelated-sibling.txt")
  writeBin(charToRaw("pre-existing unrelated sibling"), unrelated)
  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    raw_root = raw_root,
    refresh_marker = refresh_marker,
    unrelated = unrelated
  )
}

phase14_match_state_test_build_source_handoff <- function(acquire, sandbox) {
  editions <- phase14_match_state_test_api(acquire, "phase13_publication_editions")()
  resource_types <- phase14_match_state_test_api(acquire, "phase13_source_required_resource_types")()
  handoffs <- lapply(editions, function(edition_id) {
    acquire$phase13_acquire_source_handoff_from_raw_store(
      edition_id = edition_id,
      registry_root = sandbox$registry_root,
      raw_root = sandbox$raw_root,
      project_root = phase14_match_state_test_project_root
    )
  })
  names(handoffs) <- editions
  handoff_root <- tempfile("phase14-source-handoff-", tmpdir = sandbox$root)
  handoff_accepted <- file.path(handoff_root, "data/competition/accepted")
  handoff_registries <- file.path(handoff_root, "data/competition/registries")
  dir.create(handoff_accepted, recursive = TRUE, showWarnings = FALSE)
  dir.create(handoff_registries, recursive = TRUE, showWarnings = FALSE)
  write_csv <- phase14_match_state_test_api(acquire, "phase13_publication_write_csv")
  bundles <- do.call(rbind, lapply(handoffs, function(handoff) handoff$bundle))
  artifacts <- do.call(rbind, lapply(handoffs, function(handoff) handoff$artifacts))
  row.names(bundles) <- NULL
  row.names(artifacts) <- NULL
  write_csv(bundles, file.path(handoff_registries, "source_bundles.csv"))
  write_csv(artifacts, file.path(handoff_registries, "source_artifacts.csv"))
  for (edition_id in editions) {
    handoff <- handoffs[[edition_id]]
    edition_root <- file.path(handoff_accepted, edition_id)
    write_csv(handoff$manifest, file.path(edition_root, "source_bundle_manifest.csv"))
    for (artifact_type in resource_types) {
      write_csv(
        handoff$tables[[artifact_type]],
        file.path(edition_root, paste0(artifact_type, ".csv"))
      )
    }
  }
  handoff_root
}

phase14_match_state_test_build_v2_publication <- function() {
  acquire <- phase14_match_state_test_load_acquire()
  sandbox <- phase14_match_state_test_copy_sandbox()
  keep_sandbox <- FALSE
  on.exit(
    if (!keep_sandbox) unlink(sandbox$root, recursive = TRUE, force = TRUE),
    add = TRUE
  )
  durable_targets <- acquire$phase13_normalized_publication_targets(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted"),
    file.path(phase14_match_state_test_project_root, "data/competition/registries")
  )
  snapshot_targets <- phase14_match_state_test_api(acquire, "phase13_snapshot_publication_targets")
  durable_before <- snapshot_targets(durable_targets)
  raw_before <- phase14_match_state_test_snapshot_tree(sandbox$raw_root)
  source_artifacts_before <- utils::read.csv(
    file.path(sandbox$registry_root, "source_artifacts.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  source_bundles_before <- utils::read.csv(
    file.path(sandbox$registry_root, "source_bundles.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  handoff_root <- phase14_match_state_test_build_source_handoff(acquire, sandbox)
  publication <- acquire$phase13_publish_normalized_editions(
    output_root = sandbox$accepted_root,
    registry_root = sandbox$registry_root,
    registry_context_root = sandbox$registry_root,
    handoff_root = handoff_root
  )
  loader <- phase14_match_state_test_api(acquire, "load_competition_edition_registries")
  loaded <- loader(
    registry_dir = sandbox$registry_root,
    project_root = phase14_match_state_test_project_root,
    accepted_root = sandbox$accepted_root,
    raw_root = sandbox$raw_root
  )
  durable_after <- snapshot_targets(durable_targets)
  publication$sandbox <- sandbox
  publication$acquire <- acquire
  publication$loaded <- loaded
  publication$temporary_snapshot <- snapshot_targets(publication$targets)
  publication$durable_targets <- durable_targets
  publication$durable_before <- durable_before
  publication$durable_after <- durable_after
  publication$raw_before <- raw_before
  publication$raw_after <- phase14_match_state_test_snapshot_tree(sandbox$raw_root)
  publication$source_artifacts_before <- source_artifacts_before
  publication$source_bundles_before <- source_bundles_before
  publication$source_artifacts_after <- utils::read.csv(
    file.path(sandbox$registry_root, "source_artifacts.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  publication$source_bundles_after <- utils::read.csv(
    file.path(sandbox$registry_root, "source_bundles.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  keep_sandbox <- TRUE
  publication
}

phase14_match_state_test_expect_snapshot_equal <- function(actual, expected) {
  expect_identical(actual$path, expected$path)
  expect_identical(actual$exists, expected$exists)
  expect_identical(actual$byte_count, expected$byte_count)
  expect_identical(actual$sha256, expected$sha256)
  expect_identical(actual$bytes, expected$bytes)
}

test_that("temporary schema-v2 publication graph is complete and loader-valid", {
  publication <- phase14_match_state_test_build_v2_publication()
  on.exit(unlink(publication$sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  acquire <- publication$acquire
  editions <- phase14_match_state_test_api(acquire, "phase13_publication_editions")()
  resource_types <- phase14_match_state_test_api(acquire, "phase13_publication_resource_types")()
  expected_relative <- c(
    file.path("registries", c("source_artifacts.csv", "source_bundles.csv")),
    unlist(lapply(editions, function(edition_id) file.path(
      "accepted", edition_id,
      c("source_bundle_manifest.csv", paste0(resource_types, ".csv"))
    )), use.names = FALSE)
  )
  expect_identical(
    unname(publication$targets),
    file.path(normalizePath(file.path(publication$sandbox$root, "data/competition"), winslash = "/", mustWork = TRUE), expected_relative)
  )
  expect_true(all(file.exists(unname(publication$targets))))
  expect_true(all(grepl("^[0-9a-f]{64}$", publication$temporary_snapshot$sha256)))
  expect_identical(unname(publication$temporary_snapshot$exists), rep(TRUE, 14L))
  phase14_match_state_test_expect_snapshot_equal(
    publication$durable_after,
    publication$durable_before
  )
  expect_identical(publication$raw_after, publication$raw_before)

  artifact_derived <- c("row_sha256", "canonical_content_sha256")
  artifacts_before <- publication$source_artifacts_before[order(publication$source_artifacts_before$artifact_id), setdiff(names(publication$source_artifacts_before), artifact_derived), drop = FALSE]
  artifacts_after <- publication$source_artifacts_after[order(publication$source_artifacts_after$artifact_id), setdiff(names(publication$source_artifacts_after), artifact_derived), drop = FALSE]
  row.names(artifacts_before) <- NULL
  row.names(artifacts_after) <- NULL
  expect_identical(artifacts_after, artifacts_before)
  bundle_derived <- c(
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "row_sha256"
  )
  bundles_before <- publication$source_bundles_before[order(publication$source_bundles_before$bundle_id), setdiff(names(publication$source_bundles_before), bundle_derived), drop = FALSE]
  bundles_after <- publication$source_bundles_after[order(publication$source_bundles_after$bundle_id), setdiff(names(publication$source_bundles_after), bundle_derived), drop = FALSE]
  row.names(bundles_before) <- NULL
  row.names(bundles_after) <- NULL
  expect_identical(bundles_after, bundles_before)

  artifacts <- publication$source_artifacts_after
  expect_equal(nrow(artifacts), 10L)
  expect_true(all(grepl("^[0-9a-f]{64}$", artifacts$row_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", artifacts$canonical_content_sha256)))
  bundles <- publication$source_bundles_after
  expect_equal(nrow(bundles), 2L)
  expect_true(all(vapply(bundles[c(
    "source_bundle_sha256", "artifact_manifest_sha256", "canonical_content_sha256",
    "manifest_self_sha256", "row_sha256"
  )], function(column) all(grepl("^[0-9a-f]{64}$", column)), logical(1))))

  manifest_schema <- phase14_match_state_test_api(acquire, "phase13_publication_manifest_schema")()
  v2_schema <- phase14_match_state_test_api(acquire, "phase14_publication_table_schema")
  v1_schema <- phase14_match_state_test_api(acquire, "phase13_publication_table_schema")
  for (edition_id in editions) {
    manifest <- utils::read.csv(
      file.path(publication$sandbox$accepted_root, edition_id, "source_bundle_manifest.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    )
    expect_identical(names(manifest), manifest_schema)
    expect_equal(nrow(manifest), 5L)
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$row_sha256)))
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$manifest_self_sha256)))
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$canonical_content_sha256)))
    for (artifact_type in resource_types) {
      path <- file.path(publication$sandbox$accepted_root, edition_id, paste0(artifact_type, ".csv"))
      table <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
      expected_schema <- if (artifact_type %in% c("fixtures", "results", "standings")) {
        v2_schema(artifact_type, phase14_publication_schema_versions()[[artifact_type]])
      } else {
        v1_schema(artifact_type)
      }
      expect_identical(names(table), expected_schema, info = paste(edition_id, artifact_type))
      if (nrow(table)) {
        expect_true(all(as.character(table$edition_id) == edition_id))
        expect_true(all(nzchar(as.character(table$source_artifact_id))))
        expect_true(all(grepl("^[0-9a-f]{64}$", table$row_sha256)))
      }
      artifact <- artifacts[
        as.character(artifacts$edition_id) == edition_id &
          as.character(artifacts$artifact_type) == artifact_type,
        , drop = FALSE
      ]
      expect_equal(nrow(artifact), 1L)
      expect_identical(
        tolower(as.character(artifact$canonical_content_sha256[[1L]])),
        tolower(phase14_match_state_test_api(acquire, "phase13_publication_file_sha256")(path))
      )
    }
  }

  snapshots <- attr(publication$loaded, "accepted_snapshots")
  expect_named(snapshots, editions)
  euro <- snapshots[["uefa_euro_2028_qualifying"]]
  for (artifact_type in c("fixtures", "groups", "standings", "results")) {
    expect_equal(nrow(euro[[artifact_type]]), 0L)
    expect_identical(
      names(euro[[artifact_type]]),
      if (artifact_type %in% c("fixtures", "results", "standings")) {
        v2_schema(artifact_type, phase14_publication_schema_versions()[[artifact_type]])
      } else {
        v1_schema(artifact_type)
      }
    )
  }
  expect_true(isTRUE(attr(publication$loaded, "phase13_complete_registry")))
})

phase14_match_state_test_snapshot_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    return(list(exists = FALSE, bytes = raw(0), byte_count = 0L, sha256 = ""))
  }
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  list(
    exists = TRUE,
    bytes = bytes,
    byte_count = length(bytes),
    sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE)
  )
}

phase14_match_state_test_run_v2_rollback_matrix <- function() {
  acquire <- phase14_match_state_test_load_acquire()
  sandbox <- phase14_match_state_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  targets <- acquire$phase13_normalized_publication_targets(
    sandbox$accepted_root,
    sandbox$registry_root
  )
  snapshot_targets <- phase14_match_state_test_api(acquire, "phase13_snapshot_publication_targets")
  durable_targets <- acquire$phase13_normalized_publication_targets(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted"),
    file.path(phase14_match_state_test_project_root, "data/competition/registries")
  )
  durable_before <- snapshot_targets(durable_targets)
  handoff_root <- phase14_match_state_test_build_source_handoff(acquire, sandbox)
  acquire$phase13_publish_normalized_editions(
    output_root = sandbox$accepted_root,
    registry_root = sandbox$registry_root,
    registry_context_root = sandbox$registry_root,
    handoff_root = handoff_root
  )
  baseline <- snapshot_targets(targets)
  expect_identical(unname(baseline$exists), rep(TRUE, 14L))
  competition_editions_before <- phase14_match_state_test_snapshot_file(
    file.path(sandbox$registry_root, "competition_editions.csv")
  )
  refresh_before <- phase14_match_state_test_snapshot_tree(
    file.path(sandbox$registry_root, "refresh_batches")
  )
  unrelated_before <- phase14_match_state_test_snapshot_file(sandbox$unrelated)
  release_before <- phase14_match_state_test_snapshot_tree(
    file.path(phase14_match_state_test_project_root, "outputs/releases"),
    include_bytes = FALSE
  )
  publication_root <- dirname(sandbox$accepted_root)
  for (failure_index in seq_along(targets)) {
    expect_error(
      acquire$phase13_publish_normalized_editions(
        output_root = sandbox$accepted_root,
        registry_root = sandbox$registry_root,
        registry_context_root = sandbox$registry_root,
        handoff_root = handoff_root,
        failure_injector = function(index, target, transaction) index == failure_index
      ),
      "Injected|promotion|failure"
    )
    phase14_match_state_test_expect_snapshot_equal(snapshot_targets(targets), baseline)
    expect_identical(
      phase14_match_state_test_snapshot_file(file.path(sandbox$registry_root, "competition_editions.csv")),
      competition_editions_before
    )
    expect_identical(
      phase14_match_state_test_snapshot_tree(file.path(sandbox$registry_root, "refresh_batches")),
      refresh_before
    )
    expect_identical(phase14_match_state_test_snapshot_file(sandbox$unrelated), unrelated_before)
    expect_false(file.exists(file.path(publication_root, ".phase13-publication.lock")))
    expect_false(any(grepl("^\\.phase13-publication-(stage|backup)-", list.files(publication_root))))
  }
  durable_after <- snapshot_targets(durable_targets)
  expect_identical(durable_after$sha256, durable_before$sha256)
  expect_identical(durable_after$bytes, durable_before$bytes)
  expect_identical(
    phase14_match_state_test_snapshot_tree(
      file.path(phase14_match_state_test_project_root, "outputs/releases"),
      include_bytes = FALSE
    ),
    release_before
  )
  list(passed = TRUE, failure_count = length(targets), target_count = length(targets))
}

test_that("every promotion index restores the complete graph and unrelated paths", {
  rollback <- phase14_match_state_test_run_v2_rollback_matrix()

  expect_true(is.list(rollback))
  expect_true(isTRUE(rollback$passed))
})

phase14_match_state_test_crosswalk_sources <- function() {
  list(
    competition = list(
      fixtures = data.frame(
        source_fixture_id = "nl-2026-0001",
        edition_id = "uefa_nations_league_2026_27",
        home_team_id = "team_aut",
        away_team_id = "team_deu",
        scheduled_at_utc = "2026-09-05T18:45:00Z",
        neutral = FALSE,
        venue = "Vienna",
        source_artifact_id = "nl-fixtures-v1",
        source_status = "scheduled",
        final_home_goals = NA_integer_,
        final_away_goals = NA_integer_,
        row_sha256 = "score-bearing-or-mutable",
        stringsAsFactors = FALSE,
        check.names = FALSE
      ),
      results = data.frame(
        source_fixture_id = "nl-2026-0001",
        edition_id = "uefa_nations_league_2026_27",
        home_team_id = "team_aut",
        away_team_id = "team_deu",
        scheduled_at_utc = "2026-09-05T18:45:00Z",
        neutral = FALSE,
        venue = "Vienna",
        source_artifact_id = "nl-results-v1",
        source_status = "scheduled",
        final_home_goals = NA_integer_,
        final_away_goals = NA_integer_,
        row_sha256 = "score-bearing-or-mutable",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    ),
    historical = data.frame(
      source_match_id = "martj42-ns-example",
      source_result_id = "martj42-ns-example",
      match_id = "martj42-ns-example",
      edition_id = "martj42_historical_v1",
      home_team_id = "team_aut",
      away_team_id = "team_deu",
      date = "2026-07-19",
      neutral = FALSE,
      city = "Vienna",
      country = "Austria",
      source_artifact_id = "martj42-results",
      source_match_id_method = "non_score_hash",
      source_status = "finished",
      home_score = 2L,
      away_score = 1L,
      row_sha256 = "score-bearing-or-mutable",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
}

test_that("accepted competition fields win while historical lineage remains attached", {
  sources <- phase14_match_state_test_crosswalk_sources()
  sources$historical$date <- "2026-09-05"
  sources$historical$scheduled_at_utc <- "2026-09-05T18:45:00Z"
  sources$historical$city <- "Vienna"
  sources$historical$country <- NA_character_
  crosswalk <- phase14_build_match_identity_crosswalk(sources)
  canonical <- phase14_build_canonical_matches(sources, crosswalk = crosswalk)

  expect_equal(nrow(canonical), 1L)
  expect_identical(canonical$source_namespace, "competition_result")
  expect_identical(canonical$source_status, "scheduled")
  expect_true(nzchar(canonical$competition_lineage_id))
  expect_true(nzchar(canonical$history_lineage_id))
  expect_identical(canonical$home_team_id, "team_aut")
  expect_silent(phase14_validate_canonical_matches(canonical, crosswalk = crosswalk))
})

test_that("durable crosswalk uses one-to-one source IDs and a score/status-free minting projection", {
  sources <- phase14_match_state_test_crosswalk_sources()
  crosswalk <- phase14_build_match_identity_crosswalk(sources)

  expect_true(all(c(
    "schema_version", "match_id", "source_namespace", "source_match_id",
    "edition_id", "home_team_id", "away_team_id", "scheduled_at_utc",
    "minting_projection", "minting_projection_sha256", "competition_lineage_id",
    "history_lineage_id", "collision_status", "review_state", "row_sha256",
    "table_sha256"
  ) %in% names(crosswalk)))
  expect_true(all(grepl("^match-", crosswalk$match_id)))
  expect_equal(
    nrow(unique(crosswalk[, c("source_namespace", "source_match_id")])),
    nrow(crosswalk)
  )
  expect_false(any(grepl(
    "score|status|row_sha256|home_goals|away_goals",
    tolower(crosswalk$minting_projection)
  )))
  expect_silent(phase14_validate_match_identity_crosswalk(crosswalk))
})

test_that("crosswalk minting is correction-stable and reorder-stable", {
  original <- phase14_match_state_test_crosswalk_sources()
  corrected <- original
  corrected$competition$fixtures$source_status <- "finished"
  corrected$competition$fixtures$final_home_goals <- 3L
  corrected$competition$fixtures$final_away_goals <- 2L
  corrected$competition$fixtures$row_sha256 <- "changed-semantic-row-hash"
  corrected$competition$results$source_status <- "finished"
  corrected$competition$results$final_home_goals <- 3L
  corrected$competition$results$final_away_goals <- 2L
  corrected$competition$results$row_sha256 <- "changed-semantic-row-hash"
  corrected$historical$home_score <- 4L
  corrected$historical$away_score <- 0L
  corrected$historical$row_sha256 <- "changed-semantic-row-hash"

  before <- phase14_build_match_identity_crosswalk(original)
  after <- phase14_build_match_identity_crosswalk(corrected)
  before <- before[order(before$source_namespace, before$source_match_id), , drop = FALSE]
  after <- after[order(after$source_namespace, after$source_match_id), , drop = FALSE]

  expect_identical(before$match_id, after$match_id)
  expect_identical(before$minting_projection, after$minting_projection)
  expect_identical(before$minting_projection_sha256, after$minting_projection_sha256)
  expect_identical(before$table_sha256, after$table_sha256)

  reversed <- original
  reversed$competition$fixtures <- reversed$competition$fixtures[1, , drop = FALSE]
  reversed$competition$results <- reversed$competition$results[1, , drop = FALSE]
  reversed$historical <- reversed$historical[1, , drop = FALSE]
  reordered <- phase14_build_match_identity_crosswalk(reversed)
  expect_identical(
    before[, setdiff(names(before), "table_sha256"), drop = FALSE],
    reordered[order(reordered$source_namespace, reordered$source_match_id), setdiff(names(reordered), "table_sha256"), drop = FALSE]
  )
})

test_that("reviewed corrections retain prior source lineages under a stable match ID", {
  original <- phase14_match_state_test_crosswalk_sources()
  before <- phase14_build_match_identity_crosswalk(original)
  corrected <- original
  corrected$competition$fixtures$source_lineage_id <- "fixtures-correction-lineage"
  corrected$competition$results$source_lineage_id <- "results-correction-lineage"
  corrected$competition$fixtures$final_home_goals <- 3L
  corrected$competition$fixtures$final_away_goals <- 2L
  corrected$competition$results$final_home_goals <- 3L
  corrected$competition$results$final_away_goals <- 2L

  after <- phase14_build_match_identity_crosswalk(
    corrected,
    existing_crosswalk = before
  )

  expect_equal(length(unique(after$match_id)), 2L)
  expect_equal(
    unique(after$match_id[after$source_namespace == "competition_fixture"]),
    unique(before$match_id[before$source_namespace == "competition_fixture"])
  )
  expect_true(all(c(
    "nl-fixtures-v1::nl-2026-0001", "fixtures-correction-lineage",
    "nl-results-v1::nl-2026-0001", "results-correction-lineage"
  ) %in% after$source_lineage_id))
  expect_silent(phase14_validate_match_identity_crosswalk(after))
})

test_that("unreviewed source identity collisions fail closed", {
  sources <- phase14_match_state_test_crosswalk_sources()
  collision <- rbind(
    sources$historical,
    transform(sources$historical, home_team_id = "team_deu", away_team_id = "team_aut")
  )
  sources$historical <- collision

  expect_error(
    phase14_build_match_identity_crosswalk(sources),
    "collision|duplicate|one-to-one"
  )
})

test_that("production crosswalk covers every accepted and historical input", {
  historical <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/processed/martj42_historical_normalized.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  fixtures <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  results <- utils::read.csv(
    file.path(phase14_match_state_test_project_root, "data/competition/accepted/uefa_nations_league_2026_27/results.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )

  crosswalk <- phase14_build_match_identity_crosswalk(list(
    competition = list(fixtures = fixtures, results = results),
    historical = historical
  ))

  expect_equal(nrow(fixtures), 156L)
  expect_equal(nrow(results), 156L)
  expect_equal(nrow(crosswalk), nrow(historical) + nrow(fixtures) + nrow(results))
  expect_equal(length(unique(crosswalk$match_id)), nrow(historical) + nrow(fixtures))
  expect_true(all(grepl("^[0-9a-f]{64}$", crosswalk$row_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", crosswalk$table_sha256)))
  expect_silent(phase14_validate_match_identity_crosswalk(crosswalk))
})
